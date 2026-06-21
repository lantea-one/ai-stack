#!/usr/bin/env pwsh
<#
.SYNOPSIS
    This script is responsible for bootstrapping the environment by reading variables from
    a specified environment file and setting them in the current process environment.

.DESCRIPTION
    The script reads an environment file containing key-value pairs of environment variables.
    It processes each line, handling comments, empty lines, heredoc blocks, file references,
    command substitutions, and environment variable references. The variables are then set in
    the current process environment, and a summary of the defined variables is displayed.

.PARAMETER EnvironmentFile
    The path to the environment file that contains variables for the stack composer. This parameter is mandatory.
#>
param ([Parameter(Mandatory = $true)] [String] $EnvironmentFile);

## We'll need our substitution helper functions and patterns to handle variable and command substitutions.
. "${PSScriptRoot}/Get-EnvironmentSubstitutions.ps1";

## Define our pattern to match heredoc markers in environment variable values (e.g., <<EOF).
[String] $heredocPattern = '<<(\w+)$';

## Define an array to keep track of the variables we've defined from the environment file to avoid duplicates.
[String[]] $definedVariables = @();

## If the environment file exists, we'll need to read its variables into the current environment.
if (Test-Path -ErrorAction SilentlyContinue -Path "${EnvironmentFile}") {

    ## Localize the lines of the environment file for processing.
    [String[]] $lines = Get-Content -Path "${EnvironmentFile}".Trim();

    ## Localize the total number of lines.
    [Int] $totalLines = $lines.Length;

    ## Localize our heredoc marker to indicate whether we're currently inside a heredoc block or not.
    [String] $heredocMarker = $null;

    ## Iterate through each of the environment file lines.
    for ([Int] $l = 0; $l -lt $totalLines; $l++) {

        ## Localize the current line for processing.
        [String] $line = $lines[$l].Trim();

        ## Write a debug message indicating the current line being processed and its content.
        Write-Debug "Processing line $($l + 1) of ${totalLines}: ${line}";

        ## Check for a comment-line and if we're not inside a heredoc, skip it.
        if ($line[0] -eq '#' -and "${heredocMarker}" -eq '') {

            ## Write a debug message indicating that we're skipping a comment line.
            Write-Debug "Skipping Comment line $($l + 1) of ${totalLines}: ${line}";

            ## Continue to the next iteration of the loop, skipping this comment line.
            continue;
        }

        ## Check for an empty line and if we're not inside a heredoc, skip it.
        if ($line -eq '' -and "${heredocMarker}" -eq '') {

            ## Write a debug message indicating that we're skipping an empty line.
            Write-Debug "Skipping Empty line $($l + 1) of ${totalLines}: ${line}";

            ## Continue to the next iteration of the loop, skipping this empty line.
            continue;
        }

        ## Split the environment variable and key by the first '=' character,
        ## and trim any whitespace from the name and value.
        ([String] $name, [String] $value) = $line -split '=', 2;

        ## Trim any remaining whitespace from the name and value.
        $name = $name.Trim();
        $value = $value.Trim();

        ## Remove any surrounding quotations and escape characters from the value.
        if ($value -match '^"(.*)"$') { $value = $matches[1].Replace('\"', '"'); }
        if ($value -match '^''(.*)''$') { $value = $matches[1].Replace("''", "'"); }

        ## Write a debug message indicating the environment variable name and its initial value.
        Write-Debug "Found environment Variable:  ${name}  with Value:  ${value}";

        ## Check for a bash-style EOF marker (e.g., <<EOF) and if found, read the subsequent
        ## lines until the EOF marker is encountered, concatenating them into the value.
        if ($value -match "${heredocPattern}") {

            ## Localize the EOF marker
            $heredocMarker = $matches[1];

            ## Write a debug message indicating that we're entering a heredoc block and the marker being used.
            Write-Debug "Entering heredoc block for Variable:  ${name}  with Marker:  ${heredocMarker}";

            ## Reset the value to an empty string.
            $value = '';

            ## Increment the line counter to move past the current line with the heredoc marker.
            $l++;

            ## Read the subsequent lines until the EOF marker is encountered.
            while ($true) {

                ## Localize the line from the input.
                [String] $heredocLine = $lines[$l].TrimEnd();

                ## If we have a marker, we're done, break out of the loop.
                if ($heredocLine.Trim() -eq $heredocMarker) { $heredocMarker = $null; break; }

                ## Otherwise, append the line to the value with a newline character.
                $value += ("$(Get-EnvironmentSubstitutions -Value:$($heredocLine.Trim()))" +
                    [System.Environment]::NewLine);

                ## Increment the line counter to keep track of our position in the file.
                $l++;
            }

            ## Finalize the value by removing the trailing newline.
            $value = $value.TrimEnd("`n", "`r", ' ');
        }

        ## Unescape any bash-style escaped characters in the value (e.g., \n, \t, etc.).
        $value = "$(Get-EnvironmentSubstitutions -Value:$value)" -replace '\\([nrt])', {
            switch ($matches[1]) {
                'n' { "`n" }
                'r' { "`r" }
                't' { "`t" }
                default { $matches[0] } ## If it's an unrecognized escape sequence, leave it as-is.
            }
        };

        ## Write a debug message indicating the final value of the environment variable after processing.
        Write-Debug "Final value for Variable:  ${name}  is:  ${value}";

        ## Set the environment variable into the current process environment.
        Set-Item -Force -Path "Env:${name}" -Value "${value}";

        ## Add the variable to the list of defined variables to avoid duplicates.
        $definedVariables += $name;
    }
}

## Check for any defined variables.
if ($definedVariables.Length -gt 0) {

    ## Create a console table to display the variables we've defined from the environment file.
    [String] $definedVariablesTable = $definedVariables | Sort-Object | ForEach-Object {
        [PSCustomObject] @{ 'Variable' = $_; 'Value' = "$(Get-Item -Path "Env:$($_)" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty 'Value')".Trim(); }
    } | Format-Table -AutoSize | Out-String;

    #   ## Write out the variables that have been defined and their values.
    Write-Host "INFO: Defined the following variables from the environment file [${EnvironmentFile}]:" -ForegroundColor DarkGray;
    Write-Host "${definedVariablesTable}" -ForegroundColor DarkGray;
}
