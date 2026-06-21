## We'll need our utilities to get environment variable substitutions.
. "${PSScriptRoot}/Get-EnvironmentSubstitutions.ps1";

## Ensure the powershell-yaml module is available for parsing YAML
## files, and if not, install it from the PowerShell Gallery.
if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
    Install-Module -Force -Name 'powershell-yaml' -Scope CurrentUser; }

## Define our converter function.
function ConvertFrom-DockerCompose {
    <#
    .SYNOPSIS
        Converts a Docker Compose YAML file into a hashtable containing the stack name and service map.

    .DESCRIPTION
        This function reads a Docker Compose YAML file and converts it into a hashtable containing the stack name and
        a map of services with their corresponding IPv4 and IPv6 addresses. It also supports variable substitution for
        stack names and service addresses based on environment variables.

    .PARAMETER ComposerFile
        The path to the Docker Compose YAML file that you want to convert.

    .PARAMETER VariablePrefix
        The variable prefix for the stack composer, which will be used to define the environment variables for the stack. By default, it uses 'stack' or the value of the 'STACK_KEY' environment variable if it is set.

    .EXAMPLE
        ConvertFrom-DockerCompose -ComposerFile 'docker-compose.yml' -VariablePrefix 'mystack'
        This command converts the specified Docker Compose YAML file into a hashtable with the stack name
        and service map, using 'mystack' as the variable prefix for environment variable substitution.
    #>
    param(

        ## We'll need a parameter to specify the path to the docker-compose.yml file that we want to convert.
        [Parameter(Mandatory = $true)]
        [String] $ComposerFile,

        ## We'll need a parameter to specify the variable prefix for the stack composer, which will be used to
        ## define the environment variables for the stack. By default, we'll use 'stack'.
        [Parameter(Mandatory = $false)]
        [String] $VariablePrefix =
            "$(if ("${env:STACK_KEY}".Trim() -ne '') { "${env:STACK_KEY}"; } else { 'stack'; })"
    );

    ## Read our Docker Compose YAML file into memory.
    $composer = Get-Content -Path "${ComposerFile}" -Raw | ConvertFrom-Yaml;

    ## If an override composer file exists, we'll need to read it into memory and merge it with the base composer.
    if (Test-Path -ErrorAction SilentlyContinue `
        -Path "$(Join-Path -ChildPath "$((Get-Item -Path "${ComposerFile}").BaseName + 'override.yml')" `
            -Path ((Get-Item -Path "${ComposerFile}").DirectoryName))") {

                ## Read our Docker Compose override YAML file into memory.
                $overrideComposer = Get-Content -Path "$(Join-Path -ChildPath "$((Get-Item -Path "${ComposerFile}").BaseName
                    + 'override.yml')" -Path ((Get-Item -Path "${ComposerFile}").DirectoryName))" -Raw | ConvertFrom-Yaml;

                ## Merge the override composer with the base composer.
                $composer = $composer | Merge-Object -Force -Property '*' -RightObject:$overrideComposer;
            }

    ## Check for any includes in the composer file and if found, we'll need to process them.
    if ($composer.ContainsKey('include')) {

        ## Iterate through each of the includes in the composer file.
        foreach ($include in $composer.include) {

            ## Read our Docker Compose include YAML file into memory.
            $includeComposer = Get-Content -Path "$(Join-Path -ChildPath "${include}" `
                -Path ((Get-Item -Path "${ComposerFile}").DirectoryName))" -Raw | ConvertFrom-Yaml;

            ## Merge the include composer with the base composer.
            $composer = $composer | Merge-Object -Force -Property '*' -RightObject:$includeComposer;
        }
    }

    ## Sanitize the variable prefix to ensure it is a valid environment variable name.
    [String] $prefix = $VariablePrefix.Trim().ToUpper().TrimEnd('-', '_').Trim();

    ## Define the map of services to their IPv4 and IPv6 addresses for the stack.
    [HashTable] $serviceMap = @{};

    ## Define our stack name.
    [String] $stackName = "$(Get-EnvironmentSubstitutions -Value:$composer.name.Trim())";

    ## Iterate through the services in the composer file.
    foreach ($service in $composer.services.GetEnumerator()) {

        ## Localize the service name for processing.
        [String] $serviceName = $stackName + '-' + $service.Key.Trim();

        ## Check for a networks array rather than a networks object
        ## and if found, we'll need to bootstrap the table entry.
        if (-not ($service.Value.networks -is [HashTable])) {
            $serviceMap[$serviceName] = @{ 'IPv4' = 'dhcp'; 'IPv6' = 'dhcp'; }; continue; }

        ## Add the service to the service map with its IPv4 and IPv6 addresses for later reference.
        $serviceMap[$serviceName] = @{
            'IPv4' = (Get-EnvironmentSubstitutions -Value:$service.Value.networks.vlan.ipv4_address.Trim());
            'IPv6' = (Get-EnvironmentSubstitutions -Value:$service.Value.networks.vlan.ipv6_address.Trim());
        };
    }

    ## Localize our sorted services.
    $sortedHashtable = [ordered]@{ };

    ## Sort the service map by service name and add it to the sorted hashtable.
    $serviceMap.GetEnumerator() | Sort-Object -Property Key | ForEach-Object { $sortedHashtable[$_.Key] = $_.Value; }

    ## We're done, return our hashtable.
    return @{

        ## Set the stack name and the services map for the stack.
        stackName = $stackName;

        ## Set the services map for the stack, sorted by service name.
        services = $sortedHashtable;
    }
}
