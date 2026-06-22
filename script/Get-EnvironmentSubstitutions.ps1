## Define our pattern to match command substitutions in environment variable values (e.g., $(command)).
[String] $CommandSubstitutionPattern = '\$\((.+)\)';

## Define our pattern to match substitutions in environment variable
## values (e.g., ${ENV_VAR}, ${ENV_VAR:-default}, ${ENV_VAR:?error}).
[String] $VariableSubstitutionPattern = '\$\{(.+)\}';

## Define a function to resolve command substitutions in a given value string.
function Get-EnvironmentCommandSubstitution {
    <#
    .SYNOPSIS
        Resolves command substitutions in a given value string.

    .DESCRIPTION
        This function takes a value string that may contain command substitutions (e.g., $(command))
        and resolves them to their actual output. It executes the command and captures its output.

    .PARAMETER Value
        The value string that may contain command substitutions.

    .OUTPUTS
        Returns the resolved value string with command substitutions replaced by their actual output.
    #>
    param ([Parameter(Mandatory = $true)] [String] $Value);

    ## Ensure we have a valid value string to process, return $null if not.
    if ("${Value}".Trim() -eq '') {

        ## Write a debug message indicating that the value is empty and we're returning $null.
        Write-Debug "`$Value is empty, returning $null.";

        ## We're done, return $null to indicate no value was resolved.
        return $null;
    }

    ## Execute the command and capture its output.
    [String] $commandOutput = Invoke-Expression -Command:$Value.Trim();

    ## Return the command output as the resolved value.
    return "${commandOutput}".Trim();
}

## Define a function to resolve environment variable substitutions in a given value string.
function Get-EnvironmentVariableSubstitution {
    <#
    .SYNOPSIS
        Resolves environment variable substitutions in a given value string.

    .DESCRIPTION
        This function takes a value string that may contain environment variable substitutions
        (e.g., ${ENV_VAR}, ${ENV_VAR:-default}, ${ENV_VAR:?error}) and resolves them to their
        actual values. It handles default values and error messages for unset variables.

    .PARAMETER Value
        The value string that may contain environment variable substitutions.

    .OUTPUTS
        Returns the resolved value string with environment variable substitutions replaced by their actual values.
    #>
    param ([Parameter(Mandatory = $true)] [String] $Value);

    ## Ensure we have a valid value string to process, return $null if not.
    if ("${Value}".Trim() -eq '') {

        ## Write a debug message indicating that the value is empty and we're returning $null.
        Write-Debug "`$Value is empty, returning $null.";

        ## We're done, return $null to indicate no value was resolved.
        return $null;
    }

    ## Check for variable reference with an error message if the variable isn't set.
    if ($Value -like '*:\?*') {

        ## Split the variable name and error message.
        [String] $variableName, [String] $errorMessage = $matches[1].Split(':?', 2);

        ## Get the environment variable value.
        [String] $variableValue = "$(Get-Item -Path "Env:$($variableName.Trim())" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty 'Value')".Trim();

        ## Write a debug message indicating the variable name, its value, and the error message.
        Write-Debug "Variable: ${variableName}  Value: ${variableValue}  Error Message: ${errorMessage}";

        ## If the variable is not set, throw an error with the specified message.
        if ("${variableValue}".Trim() -eq '') { throw "ERROR: ${errorMessage}"; }

        ## Return the variable value if it is set.
        return "${variableValue}".Trim();
    }

    ## Check for variable reference with a default value if the variable isn't set.
    if ($Value -like '*:-*' -or $Value -like '*:+*') {

        ## Split the variable name and default value.
        [String] $variableName, [String] $defaultValue = if ($Value -like '*:-*') {
            $Value.Split(':-', 2); } else { $Value.Split(':+', 2); };

        ## Write a debug message indicating the variable name and its default value.
        Write-Debug "Variable: ${variableName}  Default Value: ${defaultValue}";

        ## Get the environment variable value.
        [String] $variableValue = "$(Get-Item -Path "Env:$($variableName.Trim())" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty 'Value')".Trim();

        ## Determine the final value based on whether the variable is
        ## set and the type of substitution (default or alternative).
        $variableValue = if ("${variableValue}".Trim() -ne '') {
            "${variableValue}".Trim() } else { "$(Get-EnvironmentSubstitutions -Value:$defaultValue)" };

        ## Write a debug message indicating the final resolved value for the variable.
        Write-Debug "Final resolved value for Variable: ${variableName}  Value: ${variableValue}";

        ## Return the variable value if it is set, otherwise return the default value.
        return "${variableValue}";
    }

    ## Localize the variable value from the environment.
    [String] $variableValue = "$(Get-Item -Path "Env:$($Value.Trim())" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty 'Value')".Trim();

    ## Write a debug message indicating that we're resolving a simple variable substitution.
    Write-Debug "Resolving simple variable substitution for Variable: $($Value) to Value: ${variableValue}";

    ## If we make it here, simply return the value.
    return "${variableValue}";
}

## Define a function to resolve both command and environment variable substitutions in a given value string.
function Get-EnvironmentSubstitutions {
    <#
    .SYNOPSIS
        Resolves both command and environment variable substitutions in a given value string.

    .DESCRIPTION
        This function takes a value string that may contain both command substitutions (e.g., $(command))
        and environment variable substitutions (e.g., ${ENV_VAR}, ${ENV_VAR:-default}, ${ENV_VAR:?error})
        and resolves them to their actual values. It handles nested substitutions and ensures that all
        references are properly resolved.

    .PARAMETER Value
        The value string that may contain both command and environment variable substitutions.

    .OUTPUTS
        Returns the resolved value string with all substitutions replaced by their actual values.
    #>
    param ([Parameter(Mandatory = $true)] [String] $Value);

    ## If the value is empty, return $null.
    if ("${Value}".Trim() -eq '') { return $null; }

    ## Localize the value to return it as-is if no substitutions are found.
    [String] $resolvedValue = "${Value}".Trim();

    ## Check for a command substitution in the value (e.g., $(command)).
    $resolvedValue = [Regex]::Replace($resolvedValue, $CommandSubstitutionPattern, {
        param ($matches);
        return "$(Get-EnvironmentCommandSubstitution -Value:$matches.Groups[1].Value)";
    });

    ## Check for an environment variable substitution in the value (e.g., ${ENV_VAR}, ${ENV_VAR:-default}, ${ENV_VAR:?error}).
    $resolvedValue = [Regex]::Replace($resolvedValue, $VariableSubstitutionPattern, {
        param ($matches);
        return "$(Get-EnvironmentVariableSubstitution -Value:$matches.Groups[1].Value)";
    });

    ## Return the fully resolved value after all substitutions have been processed.
    return "${resolvedValue}".Trim();
}
