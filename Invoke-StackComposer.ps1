#!/usr/bin/env pwsh
<#
.SYNOPSIS
    This script is used to compose the Stack using a docker-compose.yml file and an environment file.

.DESCRIPTION
    This script reads the specified environment file to set environment variables, processes a docker-compose.yml file
    to extract service information and IP addresses, updates the hosts file with entries for the stack services, and
    can optionally build, pull, bring up, or tear down the stack based on the provided parameters.

.PARAMETER Build
    A switch parameter to indicate whether to rebuild the images for the stack.

.PARAMETER ComposerFile
    A string parameter to specify the path to the docker-compose.yml file that defines the stack.

.PARAMETER Domain
    A string parameter to specify the domain for the stack, which is used in the docker-compose.yml file.

.PARAMETER Down
    A switch parameter to indicate whether to tear down the stack.

.PARAMETER DryRun
    A switch parameter to indicate whether to do a dry run, which can be useful for testing.

.PARAMETER EnvironmentFile
    A string parameter to specify the path to the environment file that contains variables for the stack composer.

.PARAMETER Except
    A string array parameter to specify services that should be
    excluded from stack operations (e.g., build, pull, up, down, etc.).

.PARAMETER HostsFile
    A string parameter to specify the path to the hosts file where the stack services will be added.

.PARAMETER Only
    A string array parameter to specify services that should be exclusively
    targeted for stack operations (e.g., build, pull, up, down, etc.).

.PARAMETER Passthrough
    A switch parameter to indicate whether to pass through the
    stack operations to the underlying docker-compose command.

.PARAMETER PassthroughArguments
    A string array parameter to specify additional arguments to pass through to the stack operations.

.PARAMETER Plain
    A switch parameter to indicate whether to output the stack information in plain text.

.PARAMETER Prune
    A switch parameter to indicate whether to prune the stack after bringing it down or up.

.PARAMETER Pull
    A switch parameter to indicate whether to pull the latest images for the stack.

.PARAMETER Recreate
    A switch parameter to indicate whether to recreate the stack.

.PARAMETER Restart
    A switch parameter to indicate whether to restart the stack.

.PARAMETER SkipWriteHostsFile
    A switch parameter to indicate whether to skip writing to the hosts file.

.PARAMETER Stop
    A switch parameter to indicate whether to stop the stack.

.PARAMETER Up
    A switch parameter to indicate whether to bring up the stack.

.PARAMETER UseCuda
    A switch parameter to indicate whether to use nVidia CUDA for the stack.

.PARAMETER UseIris
    A switch parameter to indicate whether to use Intel Iris for the stack.

.PARAMETER UseRocm
    A switch parameter to indicate whether to use AMD ROCm for the stack.

.PARAMETER VariablePrefix
    A string parameter to specify the variable prefix for the stack composer, which is used to define
    the environment variables for the stack.

.EXAMPLE
    $ ./Invoke-AiStackComposer.ps1 -Build -Up
    This example will build the images for the stack and then bring the stack up.
#>
param (

    ## We'll need a switch parameter to indicate whether we should rebuild the images or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Build = $false,

    ## We'll need a parameter to specify the path to the docker-compose.yml file, which will be used to define our
    ## stack.  By default, we'll look for a file called 'docker-compose.yml' in the same directory as this
    [Parameter(Mandatory = $false)]
    [String] $ComposerFile = "$(Join-Path -ChildPath 'docker-compose.yml' -Path "${PSScriptRoot}")",

    ## We'll need a parameter to specify the domain for the stack, which will be
    ## used in the docker-compose.yml file. By default, we'll use 'ai.local'.
    [Parameter(Mandatory = $false)]
    [String] $Domain = $null,

    ## We'll need a switch parameter to indicate whether we should tear the stack down or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Down = $false,

    ## We'll need a switch parameter to indicate whether we should do a dry run or not, which can be useful for testing.
    [Parameter(Mandatory = $false)]
    [Switch] $DryRun = $false,

    ## We'll need an environment file to load the necessary variables for the stack composer to work.
    ## By default, we'll look for a file called 'stack.env' in the same directory as this script.
    [Parameter(Mandatory = $false)]
    [String] $EnvironmentFile = "$(Join-Path -ChildPath 'stack.env' -Path "${PSScriptRoot}")",

    ## We'll need a parameter to specify the services we *do not* want to
    ## target for our stack operations (e.g., build, pull, up, down, etc.).
    [Parameter(Mandatory = $false)]
    [String[]] $Except = @(),

    ## We'll need a parameter to specify the path to the hosts file where we want to add our stack host entries.
    ## By default, we'll use '/etc/hosts'.
    [Parameter(Mandatory = $false)]
    [String] $HostsFile =
    "$(if ($IsWindows) { "${env:SystemRoot}\System32\drivers\etc\hosts" } else { '/etc/hosts' })",

    ## We'll need a parameter to specify the services we want to target for our stack operations (e.g., build, pull, up, down, etc.).
    [Parameter(Mandatory = $false)]
    [String[]] $Only = @(),

    ## We'll need a switch parameter to indicate whether we should pass through the stack operations or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Passthrough = $false,

    ## We'll need a parameter to specify the arguments to pass through to
    ## the stack operations [this contains all extra arguments passed to the script].
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [String[]] $PassthroughArguments = @(),

    ## We'll need a switch parameter to indicate whether we should output the stack information in plain text or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Plain = $false,

    ## We'll need a switch parameter to indicate whether we should prune the stack or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Prune = $false,

    ## We'll need a switch parameter to indicate whether we should pull the latest images or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Pull = $false,

    ## We'll need a switch parameter to indicate whether we should recreate the stack or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Recreate = $false,

    ## We'll need a switch parameter to indicate whether we should restart the stack or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Restart = $false,

    ## We'll need a switch parameter to indicate whether we should skip writing to the hosts file or not,
    ## which can be useful for testing or if the user doesn't have permission to write to the hosts file.
    [Parameter(Mandatory = $false)]
    [Switch] $SkipWriteHostsFile = $false,

    ## We'll need a switch parameter to indicate whether we should stop the stack or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Stop = $false,

    ## We'll need a switch parameter to indicate whether we should bring the stack up or not.
    [Parameter(Mandatory = $false)]
    [Switch] $Up = $false,

    ## We'll need a switch parameter to indicate whether we should use nVidia CUDA or not.
    [Parameter(Mandatory = $false)]
    [Switch] $UseCuda = $false,

    ## We'll need a switch parameter to indicate whether we should use Intel Iris or not.
    [Parameter(Mandatory = $false)]
    [Switch] $UseIris = $false,

    ## We'll need a switch parameter to indicate whether we should use AMD ROCm or not.
    [Parameter(Mandatory = $false)]
    [Switch] $UseRocm = $false,

    ## We'll need a parameter to specify the variable prefix for the stack composer, which will be used to
    ## define the environment variables for the stack. By default, we'll use 'ai'.
    [Parameter(Mandatory = $false)]
    [String] $VariablePrefix = $null
);

## Define a function to resolve command substitutions in a given value string.
function ConvertFrom-TimeString {

    <#
    .SYNOPSIS
        Converts a time string (e.g., '30s', '5m', '2h', '1d', '1w') into seconds.

    .DESCRIPTION
        This function takes a time string that consists of a numeric value followed by a unit (s for seconds, m for
        minutes, h for hours, d for days, w for weeks) and converts it into the equivalent number of seconds. If the
        time string is just a number without a unit, it is assumed to be in seconds.

    .PARAMETER TimeString
        The time string to convert, which should be in the format of a number followed
        by a unit (e.g., '30s', '5m','2h', '1d', '1w') or just a number (e.g., '60').

    .OUTPUTS
        Returns the equivalent number of seconds as an integer. If the input format is invalid, it returns 0.

    #>
    param ([Parameter(Mandatory = $true)] [String] $TimeString);

    ## Ensure we have a valid time string to process, return $null if not.
    if ("${TimeString}".Trim() -eq '') {

        ## Write a debug message indicating that the time string is empty and we're returning $null.
        Write-Debug "`$TimeString is empty, returning $null.";

        ## We're done, return $null to indicate no value was resolved.
        return 0;
    }

    ## Use a regular expression to match the time string and extract the numeric value and unit.
    if ($TimeString -match '^(?<value>\d+)(?<unit>[smhdw])$') {
        [int] $value = [int]$matches['value'];
        [string] $unit = $matches['unit'];

        ## Write a debug message indicating the extracted value and unit from the time string.
        Write-Debug "Extracted value: ${value}, unit: ${unit} from time string: ${TimeString}";

        ## Convert the extracted value and unit to seconds based on the unit.
        switch ($unit) {
            's' { return [TimeSpan]::FromSeconds($value).TotalSeconds }
            'm' { return [TimeSpan]::FromMinutes($value).TotalSeconds }
            'h' { return [TimeSpan]::FromHours($value).TotalSeconds }
            'd' { return [TimeSpan]::FromDays($value).TotalSeconds }
            'w' { return [TimeSpan]::FromDays($value * 7).TotalSeconds }
            default { return 0 }
        }

    }

    ## Check for a time string that is just a number without a unit, and if so, we'll assume it's in seconds.
    elseif ($TimeString -match '^(?<value>\d+)$') {
        [int] $value = [int]$matches['value'];

        ## Write a debug message indicating the extracted value from the time string without a unit.
        Write-Debug "Extracted value: ${value} from time string: ${TimeString} (no unit specified, defaulting to seconds)";

        ## If no unit is specified, assume the value is in seconds and return it.
        return [Int]::Parse($value);
    }
    else {

        ## Write a debug message indicating that the time string format is invalid and we're returning 0.
        Write-Debug "Invalid time string format: ${TimeString}, returning 0.";

        ## If the time string doesn't match the expected format, return 0 to indicate an invalid value.
        return 0;
    }
}

## Define a function to return the index of the desired GPU.
function Get-GPUIndex {
    <#
    .SYNOPSIS
        Returns the index of the desired GPU based on the specified GPU type (nVidia CUDA, Intel Iris, or AMD ROCm).

    .DESCRIPTION
        This function queries the system for available GPU devices and returns the index of the first device that matches
        the specified GPU type. It supports nVidia CUDA, Intel Iris, and AMD ROCm GPUs. If no matching device is found,
        it defaults to returning index 0.

    .PARAMETER UseCuda
        A switch parameter to indicate whether to use nVidia CUDA for the stack.

    .PARAMETER UseIris
        A switch parameter to indicate whether to use Intel Iris for the stack.

    .PARAMETER UseRocm
        A switch parameter to indicate whether to use AMD ROCm for the stack.

    .OUTPUTS
        Returns the index of the desired GPU as an integer. If no matching GPU is found, it returns 0.
    #>
    param ([Parameter(Mandatory = $false)] [Switch] $UseCuda = $false,
        [Parameter(Mandatory = $false)] [Switch] $UseIris = $false,
        [Parameter(Mandatory = $false)] [Switch] $UseRocm = $false);

    ## Localize the query string based on the GPU type we're using (nVidia CUDA, Intel Iris, or AMD ROCm).
    [String] $query = if ($UseCuda.ToBool()) { 'NVIDIA' }
    elseif ($UseIris.ToBool()) { 'Intel.*Iris' }
    elseif ($UseRocm.ToBool()) { 'AMD' }
    else { 'Intel.*Arc' };

    ## Check for a Windows operating system then query for devices.
    if ($IsWindows) {

        ## Localize the video controller instances from the Win32_VideoController class, which will be used to determine the GPU index.
        $devices = (Get-CimInstance Win32_VideoController);

        ## Find the first index matching the query string.
        $index = $devices | Where-Object { $_.Name -match "${query}" } | Select-Object -First 1;

        ## If we have an index, return it.
        if ($index) { return [array]::IndexOf($devices, $index); }
    }

    ## Check for a macOS operating system then query for devices.
    elseif ($IsMacOS) {

        ## Localize the display devices from the system_profiler command, which will be used to determine the GPU index.
        [String[]] $devices = (system_profiler SPDisplaysDataType | Select-String 'Chipset Model');

        ## Find the first index matching the query string.
        $index = $devices | Where-Object { $_ -match "${query}" } | Select-Object -First 1;

        ## If we have an index, return it.
        if ($index) { return [array]::IndexOf($devices, $index); }
    }

    ## Otherwise, we default to Linux.
    else {

        ## Localize the display devices from the lspci command, which will be used to determine the GPU index.
        [String[]] $devices = (lspci | Select-String 'VGA|3D|Display');

        # Find the first index matching the query string.
        $index = $devices | Where-Object { $_ -match "${query}" } | Select-Object -First 1;

        ## If we have an index, return it.
        if ($index) { return [array]::IndexOf($devices, $index); }
    }

    ## If we get here, return 0 for the default GPU.
    return 0;
}

## Define a function to determine the GPU-specific environment variables.
function Set-GPUEnvironmentVariables {
    <##
    .SYNOPSIS
        Sets GPU-specific environment variables based on the selected GPU type (nVidia CUDA, Intel Iris, or AMD ROCm).

    .DESCRIPTION
        This function sets environment variables that are specific to the selected GPU type. It checks for the
        presence of the GPU type switches (UseCuda, UseIris, UseRocm) and sets the corresponding environment
        variables accordingly. If no GPU type is specified, it defaults to Intel ARC.

    .PARAMETER UseCuda
        A switch parameter to indicate whether to use nVidia CUDA for the stack.

    .PARAMETER UseIris
        A switch parameter to indicate whether to use Intel Iris for the stack.

    .PARAMETER UseRocm
        A switch parameter to indicate whether to use AMD ROCm for the stack.
    #>
    param ([Parameter(Mandatory = $false)] [Switch] $UseCuda = $false,
        [Parameter(Mandatory = $false)] [Switch] $UseIris = $false,
        [Parameter(Mandatory = $false)] [Switch] $UseRocm = $false);


    ## Localize the environment variable for the SD.Next argument list.
    [String[]] $sdnextArgumentList = if ("${env:STACK_SDNEXT_ARGUMENT_LIST}".Trim() -eq '') { @('--api', '--listen'); }

    ## If we have a space in the argument list, we'll split it into an array of arguments.
    elseif ("${env:STACK_SDNEXT_ARGUMENT_LIST}".Contains(' ')) {
        "${env:STACK_SDNEXT_ARGUMENT_LIST}".Trim().Split(' ') |
            Where-Object { "${_}".Trim() -ne '' } |
                ForEach-Object { "${_}".Trim() } |
                    Sort-Object -Unique;
    }

    ## Otherwise, we'll assume it's a singular argument and create an array from it.
    else { @("${env:STACK_SDNEXT_ARGUMENT_LIST}".Trim()); };

    ## Define the list of environment variables we'll need to
    ## translate for the GPU type we're using (nVidia CUDA, Intel Iris, or AMD ROCm).
    [String[]] $environmentVariables = @(
        'GPU_AUTOMATIC1111_CFG_SCALE',
        'GPU_BACKEND_IMAGE',
        'GPU_DEVICE',
        'GPU_CUDA_FORCE_ATTENTION_SLICE',
        'GPU_CUDA_VISIBLE_DEVICES',
        'GPU_FRONTEND_IMAGE_MODEL',
        'GPU_FRONTEND_IMAGE_SIZE',
        'GPU_FRONTEND_IMAGE_STEPS',
        'GPU_IMAGE_IMAGE',
        'GPU_OLLAMA_FLASH_ATTENTION',
        'GPU_OLLAMA_MAX_LOADED_MODELS',
        'GPU_OLLAMA_NUM_CTX',
        'GPU_OLLAMA_NUM_PARALLEL',
        'GPU_OLLAMA_ONEAPI_DEVICE_SELECTOR',
        'GPU_OLLAMA_ZES_ENABLE_SYSMAN',
        'GPU_SDNEXT_ARGUMENT_LIST',
        'GPU_SDNEXT_MODEL_LIST'
    );

    ## Localize the environment variable key based on the GPU type we're using (nVidia CUDA, Intel Iris, or AMD ROCm).
    [String] $environmentKey = if ($UseCuda.ToBool()) {
        'GPU_NVIDIA';
    }
    elseif ($UseIris.ToBool()) {
        'GPU_INTEL_IRIS';
    }
    elseif ($UseRocm.ToBool()) {
        'GPU_AMD';
    }
    else {
        'GPU_INTEL_ARC';
    };

    ## Iterate through the list of environment variables and set them for nVidia
    ## CUDA, using the values from the environment or the defaults if not set.
    $environmentVariables | Where-Object { "${_}".Trim() -ne '' } | Sort-Object -Unique | ForEach-Object {

        ## Localize the current environment variable name for processing.
        [String] $variableName = ($environmentKey.ToUpper().Trim('_', ' ') + '_' + $_.Substring(4, $_.Length - 4).ToUpper().Trim('_', ' '));

        ## Localize the variable value from the generated variable name.
        [String] $variableValue = (Get-Item -ErrorAction Stop -Path "Env:${variableName}" |
                Select-Object -ExpandProperty 'Value').Trim();

            ## Set the base GPU variable to the value of the targeted GPU
            ## type variable, which will be used by the stack composer.
            Set-Item -Force -Path "Env:${_}" -Value "${variableValue}";
        }

        ## Check for additional SD.Next arguments.
        if ("${env:GPU_SDNEXT_ARGUMENT_LIST}".Trim() -ne '') {

            ## Append the additional SD.Next arguments to the existing argument list.
            $sdnextArgumentList += if ("${env:GPU_SDNEXT_ARGUMENT_LIST}".Contains(' ')) {
                "${env:GPU_SDNEXT_ARGUMENT_LIST}".Trim().Split(' ') |
                    Where-Object { "${_}".Trim() -ne '' } |
                        ForEach-Object { "${_}".Trim() }
        }
        else { @("${env:GPU_SDNEXT_ARGUMENT_LIST}".Trim()); };

        ## Ensure the SD.Next argument list is unique and sorted.
        $sdnextArgumentList = $sdnextArgumentList | Sort-Object -Unique;
    }

    ## Localize the SD.Next model list from the environment variable, which will be used by the stack composer.
    [String[]] $sdnextModelList = if ("${env:STACK_SDNEXT_MODEL_LIST}".Trim() -eq '') {
        @();
    }
    elseif ("${env:STACK_SDNEXT_MODEL_LIST}".Contains(',')) {
        "${env:STACK_SDNEXT_MODEL_LIST}".Trim().Split(',') | Where-Object { "${_}".Trim() -ne '' } |
            ForEach-Object { "${_}".Trim() }
    }
    else {
        @("${env:STACK_SDNEXT_MODEL_LIST}".Trim());
    };

    ## Check for an iGPU and remove any default SD.Next models.
    if ($UseIris.ToBool()) { $sdnextModelList = @(); }

    ## Check for GPU-specific SD.Next models and append them to the existing model list.
    if ("${env:GPU_SDNEXT_MODEL_LIST}".Trim() -ne '') {

        ## Append the GPU-specific SD.Next models to the existing model list.
        $sdnextModelList += if ("${env:GPU_SDNEXT_MODEL_LIST}".Contains(',')) {
            "${env:GPU_SDNEXT_MODEL_LIST}".Trim().Split(',') | Where-Object { "${_}".Trim() -ne '' } | ForEach-Object { "${_}".Trim() }
        }
        else {
            @("${env:GPU_SDNEXT_MODEL_LIST}".Trim());
        };

        ## Ensure the SD.Next model list is unique and sorted.
        $sdnextModelList = $sdnextModelList | Sort-Object -Unique;
    }

    ## Iterate the the model list [which are URLs].
    $sdnextModelList | Where-Object { "${_}".Trim() -ne '' } | Sort-Object -Unique |
        ForEach-Object { [uri]$_.Trim(); } | ForEach-Object {

            ## Localize the filename of the model from the URL, which will
            ## be used to update the SDNEXT_ARGUMENT_LIST environment variable.
            [String] $modelFilename = [System.IO.Path]::GetFileName($_.AbsolutePath);

            ## Update the SD.Next argument list with a checkpoint for the model, which will be used by the stack composer.
            $sdnextArgumentList += "--ckpt=$(Join-Path -ChildPath "${modelFilename}" -Path "${env:STACK_SDNEXT_MODEL_PATH}")";
        };

    ## Set the updated SD.Next model list into the environment.
    Set-Item -Force -Path 'Env:STACK_SDNEXT_MODEL_LIST' -Value "$($sdnextModelList -join ',')";

    ## Set the updated SD.Next argument list into the environment.
    Set-Item -Force -Path 'Env:STACK_SDNEXT_ARGUMENT_LIST' -Value "$($sdnextArgumentList -join ' ')";

    ## Set the GPU index into the environment, which will be used by the stack composer.
    Set-Item -Force -Path 'Env:GPU_INDEX' -Value "$(Get-GPUIndex -UseCuda:$UseCuda -UseIris:$UseIris -UseRocm:$UseRocm)";

    ## Check for nVidia CUDA and set the GPU_CUDA_VISIBLE_DEVICES environment variable if applicable.
    if ($UseCuda.ToBool()) { Set-Item -Force -Path 'Env:GPU_CUDA_VISIBLE_DEVICES' -Value "${env:GPU_INDEX}"; }

    ## Check for Intel Arc or Intel Iris and set the GPU_ONEAPI_DEVICE_SELECTOR environment variable if applicable.
    if ($UseIris.ToBool() -or (-not $UseCuda.ToBool() -and -not $UseRocm.ToBool())) {
        Set-Item -Force -Path 'Env:GPU_ONEAPI_DEVICE_SELECTOR' -Value "level_zero:${env:GPU_INDEX}";
    }

    ## Create a console table to display the variables we've defined from the environment file.
    [String] $definedVariablesTable = ($environmentVariables + @(
            'GPU_INDEX', 'STACK_SDNEXT_ARGUMENT_LIST', 'STACK_SDNEXT_MODEL_LIST'
        )) | Where-Object { $_.ToLower() -ne 'gpu_sdnext_argument_list' -and $_.ToLower() -ne 'gpu_sdnext_model_list' } |
        Sort-Object | ForEach-Object {
            [PSCustomObject] @{ 'Variable' = $_; 'Value' = "$(Get-Item -Path "Env:$($_)" -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty 'Value')".Trim();
            }
        } | Format-Table -AutoSize | Out-String;

    #   ## Write out the variables that have been defined and their values.
    Write-Host 'INFO: Defined the following GPU variables from the environment:' -ForegroundColor DarkGray;
    Write-Host "${definedVariablesTable}" -ForegroundColor DarkGray;
}

## We'll need our function for parsing the docker-compose.yml file and returning the stack name and service map.
. "${PSScriptRoot}/script/ConvertFrom-DockerCompose.ps1";

## Bootstrap the environment file into the current build time environment.
& "${PSScriptRoot}/script/Invoke-BootstrapEnvironment.ps1" -EnvironmentFile:$EnvironmentFile;

## Set the GPU-specific environment variables based on the selected GPU type (nVidia CUDA, Intel Iris, or AMD ROCm).
Set-GPUEnvironmentVariables -UseCuda:$UseCuda -UseIris:$UseIris -UseRocm:$UseRocm;

## If our variable prefix is null or empty, pull it from the environment or use the default value of 'stack'.
if ("${VariablePrefix}".Trim('_', ' ') -eq '') {
    $VariablePrefix = if ("$([System.Environment]::GetEnvironmentVariable('STACK_KEY'))".Trim() -ne '') {
        [System.Environment]::GetEnvironmentVariable('STACK_KEY');
    }
    else { 'stack'; };
}

## Sanitize the variable prefix to ensure it is a valid environment variable name.
[String] $VariablePrefix = $VariablePrefix.Trim().ToUpper().TrimEnd('-', '_').Trim();

## If our domain is null or empty, pull it from the environment or use the default value of '${VariablePrefix}.local'.
if ("${Domain}".Trim('.', ' ') -eq '') {
    $Domain = if ("$([System.Environment]::GetEnvironmentVariable("${VariablePrefix}_DOMAIN"))".Trim() -ne '') {
        [System.Environment]::GetEnvironmentVariable("${VariablePrefix}_DOMAIN");
    }
    elseif ("$([System.Environment]::GetEnvironmentVariable("${VariablePrefix}_STACK_DOMAIN"))".Trim() -ne '') {
        [System.Environment]::GetEnvironmentVariable("${VariablePrefix}_STACK_DOMAIN");
    }
    else { "$($VariablePrefix.ToLower()).local"; };
}

## Localize the command to run for the stack operations, which will be 'docker compose' with an optional '--dry-run'
## flag if the DryRun switch is set. This will allow us to easily use this command variable throughout the script for
## any stack operations we need to perform.
[String[]] $command = @('docker', 'compose');

## If the DryRun switch is set, we'll add the '--dry-run' flag to the command variable.
if ($DryRun.ToBool()) {

    ## Add the dry-run flag to the command variable, which will be used for all stack operations.
    $command += '--dry-run';

    ## Write a message to the console indicating that we're in dry-run mode and no changes will be made.
    Write-Host 'NOTICE: Dry-run mode is enabled. No changes will be made to the stack or the hosts file.' -ForegroundColor DarkYellow;
    Write-Host '';
}

## Add our composer file to the command variable, which will be used for all stack operations.
$command += @('--file', "${ComposerFile}");

## Localize our supplemental override file path.
[String] $overridePath = "$(Join-Path -ChildPath 'composer.d' -Path "${PSScriptRoot}" -Resolve)";

## If we're using nVidia CUDA then we'll need to include the supplemental override file.
if ($UseCuda.ToBool()) { $override = "$(Join-Path -ChildPath 'cuda.yml' -Path "${overridePath}" -Resolve)"; }

## If we're using AMD ROCm then we'll need to include the supplemental override file.
elseif ($UseRocm.ToBool()) { $override = "$(Join-Path -ChildPath 'rocm.yml' -Path "${overridePath}" -Resolve)"; }

## Otherwise we'll default to using the Intel supplemental override file.
else { $override = "$(Join-Path -ChildPath 'intel.yml' -Path "${overridePath}" -Resolve)"; }

## Add the override file to the command variable, which will be used for all stack operations.
$command += @('--file', "${override}");

## Define the map of services to their IPv4 and IPv6 addresses for the stack.
[HashTable] $composer = $ComposerFile |
    ConvertFrom-DockerCompose -OverrideFile:$override -VariablePrefix:$VariablePrefix;

## Check the service map for any services.
if ($composer.services.Keys.Count -gt 0) {

    ## Create a console table to display the services and their IP addresses.
    [String] $servicesTable = $composer.services.GetEnumerator() | ForEach-Object {
        [PSCustomObject] @{
            'Service'  = $_.Key.Replace("$($composer.stackName)-", '');
            'Hostname' = $_.Key + '.' + $Domain.Trim('.', ' ');
            'IPv4'     = $_.Value.IPv4;
            'IPv6'     = $_.Value.IPv6;
        }
    } | Format-Table -AutoSize | Out-String;

    ## Write out the services and their IP addresses.
    Write-Host "INFO: Defined the following services and their IP addresses for the stack [$($composer.stackName)]:" -ForegroundColor DarkGray;
    Write-Host "${servicesTable}" -ForegroundColor DarkGray;
}

## Manipulate the hosts file with the stack service entries based on the service map and the included/excluded services.
if (-not $SkipWriteHostsFile.ToBool() -and ($Down.ToBool() -or $Recreate.ToBool() -or $Up.ToBool())) {
    & "${PSScriptRoot}/script/Invoke-ManipulateHostsFile.ps1" -Domain:$Domain -DryRun:$DryRun -Except:$Except `
        -HostsFile:$HostsFile -Only:$Only -Remove:$Down -ServiceMap:$composer.services;
}

## Check for plain output.
if ($Plain.ToBool()) {

    ## Set the appropriate environment variable to indicate that we're in plain output mode.
    [System.Environment]::SetEnvironmentVariable('BUILDKIT_PROGRESS', 'plain');
    [System.Environment]::SetEnvironmentVariable('COMPOSE_PROGRESS', 'plain');
}

## If we need to bring our stack down, we'll do that first.
if ($Down.ToBool() -and -not $Passthrough.ToBool()) {

    ## Define our arguments for the docker command.
    [String[]] $arguments = @('down', '--remove-orphans', '--volumes');

    ## Check if we have any services specified in the -Only parameter, and if so, we'll only bring down those services.
    if ($Only.Length -gt 0) { $arguments += $Only; }

    ## If we have excluded services specified in the -Except parameter,
    ## we'll bring down all services except those specified.
    elseif ($Except.Length -gt 0) { $arguments += ($composer.services.Keys | Where-Object { $_ -notin $Except }); }

    ## Execute our command plus our arguments to bring up the stack.
    Invoke-Expression -Command "$($command -join ' ') $($arguments -join ' ')";

    ## Check the prune switch and if it's set, we'll go ahead and prune the stack to remove any unused resources.
    if ($Prune.ToBool() -and -not $DryRun.ToBool()) { docker system prune --all --force --volumes; }
}

## If we need to pull or build the latest images, we'll go ahead and build our images now.
if ($Build.ToBool()) {

    ## Define our arguments for the docker command.
    [String[]] $arguments = @('build', '--no-cache', '--pull');

    ## Write a message to the console indicating that we're building the images for the stack.
    Write-Host "INFO: Building the images for the stack [$($composer.stackName)] using the composer file [${ComposerFile}]..." -ForegroundColor DarkGray;

    ## Check if we have any services specified in the -Only parameter, and if so, we'll only build those services.
    if ($Only.Length -gt 0) { $arguments += $Only; }

    ## If we have excluded services specified in the -Except parameter,
    ## we'll build all services except those specified.
    elseif ($Except.Length -gt 0) { $arguments += ($composer.services.Keys | Where-Object { $_ -notin $Except }); }

    ## Execute our command plus our arguments to bring up the stack.
    Invoke-Expression -Command "$($command -join ' ') $($arguments -join ' ')";
}

## If we need to pull the latest images, we'll go ahead and pull our images now.
if ($Pull.ToBool()) {

    ## Define our arguments for the docker command.
    [String[]] $arguments = @('pull');

    ## Write a message to the console indicating that we're pulling the latest images for the stack.
    Write-Host "INFO: Pulling the latest images for the stack [$($composer.stackName)] using the composer file [${ComposerFile}]..." -ForegroundColor DarkGray;

    ## Check if we have any services specified in the -Only parameter, and if so, we'll only pull those services.
    if ($Only.Length -gt 0) { $arguments += $Only; }

    ## If we have excluded services specified in the -Except parameter,
    ## we'll pull all services except those specified.
    elseif ($Except.Length -gt 0) { $arguments += ($composer.services.Keys | Where-Object { $_ -notin $Except }); }

    ## Execute our command plus our arguments to bring up the stack.
    Invoke-Expression -Command "$($command -join ' ') $($arguments -join ' ')";
}

## If we need to recreate the stack, we'll do that now.
if ($Recreate.ToBool() -and -not $Passthrough.ToBool()) {

    ## Define our arguments for the docker command.
    [String[]] $arguments = @('up', '--detach', '--remove-orphans', '--force-recreate');

    ## Write a message to the console indicating that we're recreating the stack.
    Write-Host "INFO: Recreating the stack [$($composer.stackName)] using the composer file [${ComposerFile}]..." -ForegroundColor DarkGray;

    ## Check if we have any services specified in the -Only parameter, and if so, we'll only recreate those services.
    if ($Only.Length -gt 0) { $arguments += $Only; }

    ## If we have excluded services specified in the -Except parameter,
    ## we'll recreate all services except those specified.
    elseif ($Except.Length -gt 0) { $arguments += ($composer.services.Keys | Where-Object { $_ -notin $Except }); }

    ## Execute our command plus our arguments to bring up the stack.
    Invoke-Expression -Command "$($command -join ' ') $($arguments -join ' ')";
}

## If we need to restart the stack, we'll do that now.
if ($Restart.ToBool() -and -not $Passthrough.ToBool()) {

    ## Define our arguments for the docker command.
    [String[]] $arguments = @('restart');

    ## Write a message to the console indicating that we're restarting the stack.
    Write-Host "INFO: Restarting the stack [$($composer.stackName)] using the composer file [${ComposerFile}]..." -ForegroundColor DarkGray;

    ## Check if we have any services specified in the -Only parameter, and if so, we'll only restart those services.
    if ($Only.Length -gt 0) { $arguments += $Only; }

    ## If we have excluded services specified in the -Except parameter,
    ## we'll restart all services except those specified.
    elseif ($Except.Length -gt 0) { $arguments += ($composer.services.Keys | Where-Object { $_ -notin $Except }); }

    ## Execute our command plus our arguments to bring up the stack.
    Invoke-Expression -Command "$($command -join ' ') $($arguments -join ' ')";
}

## If we need to stop the stack, we'll do that now.
if ($Stop.ToBool() -and -not $Passthrough.ToBool()) {

    ## Define our arguments for the docker command.
    [String[]] $arguments = @('stop');

    ## Write a message to the console indicating that we're stopping the stack.
    Write-Host "INFO: Stopping the stack [$($composer.stackName)] using the composer file [${ComposerFile}]..." -ForegroundColor DarkGray;

    ## Check if we have any services specified in the -Only parameter, and if so, we'll only stop those services.
    if ($Only.Length -gt 0) { $arguments += $Only; }

    ## If we have excluded services specified in the -Except parameter,
    ## we'll stop all services except those specified.
    elseif ($Except.Length -gt 0) { $arguments += ($composer.services.Keys | Where-Object { $_ -notin $Except }); }

    ## Execute our command plus our arguments to bring up the stack.
    Invoke-Expression -Command "$($command -join ' ') $($arguments -join ' ')";
}

## If we need to bring our stack up, we'll do that now.
if ($Up.ToBool() -and -not $Passthrough.ToBool()) {

    ## Define our arguments for the docker command.
    [String[]] $arguments = @('up', '--detach', '--remove-orphans',
        '--wait-timeout', "$(ConvertFrom-TimeString -TimeString "${env:STACK_IMAGE_STARTUP_TIMEOUT}")");

    ## Write a message to the console indicating that we're bringing the stack up.
    Write-Host "INFO: Bringing the stack [$($composer.stackName)] up using the composer file [${ComposerFile}]..." -ForegroundColor DarkGray;

    ## Check if we have any services specified in the -Only parameter, and if so, we'll only bring up those services.
    if ($Only.Length -gt 0) { $arguments += $Only; }

    ## If we have excluded services specified in the -Except parameter,
    ## we'll bring up all services except those specified.
    elseif ($Except.Length -gt 0) { $arguments += ($composer.services.Keys | Where-Object { $_ -notin $Except }); }

    ## Execute our command plus our arguments to bring up the stack.
    Invoke-Expression -Command "$($command -join ' ') $($arguments -join ' ')";
}

## Check for a passthrough operation and if it's set, we'll pass through
## this stack operations to the underlying docker-compose command.
if ($Passthrough.ToBool()) {

    ## Write a message to the console indicating that we're passing through the stack operations to the underlying docker-compose command.
    Write-Host "INFO: Passing through the stack operations to the underlying docker-compose command for the stack [$($composer.stackName)]..." -ForegroundColor DarkGray;

    ## Execute our command plus our passthrough arguments to pass through the stack operations to the underlying docker-compose command.
    Invoke-Expression -Command "$($command -join ' ') $($PassthroughArguments -join ' ')";
}

## Check the prune switch and if it's set, we'll prune any dangling resources to clean up after ourselves.
if ($Prune.ToBool()) {

    ## Write a message to the console indicating that we're pruning any dangling resources.
    Write-Host "INFO: Pruning any dangling resources for the stack [$($composer.stackName)]..." -ForegroundColor DarkGray;

    ## Prune any dangling resources to clean up after ourselves.
    if (-not $DryRun.ToBool()) { docker system prune --all --force --volumes; }
}
