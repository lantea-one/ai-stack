#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Provision large language models for SD.Next.

.DESCRIPTION
    This script provisions large language models for SD.Next by checking the health of the respective
    services and downloading the specified models if they are not already present.

.PARAMETER $env:SDNEXT_FORCE_DOWNLOAD
    If set to 'true', the script will force the download of SD.Next models even if they already exist.
    This environment variable is optional and defaults to 'false' if not set.

.PARAMETER $env:SDNEXT_HOST
    The URL of the SD.Next host.
    This environment variable must be set before running the script.

.PARAMETER $env:SDNEXT_MODEL_LIST
    A comma-separated list of SD.Next model URLs to provision.
    This environment variable must be set before running the script.

.PARAMETER $env:SDNEXT_MODEL_PATH
    The file system path where SD.Next models should be stored.
    This environment variable must be set before running the script.
#>

## Localize the SD.Next force download flag.
[Boolean]$forceDownload =
## If the SDNEXT_FORCE_DOWNLOAD environment variable is set to a truthy value, set the force download flag to true.
if (@('1', 'ok', 'on', 't', 'true', 'y', 'yes') -contains "${env:SDNEXT_FORCE_DOWNLOAD}".Trim().ToLower())
{
    $true;
}

## Otherwise, set the force download flag to false.
else
{
    $false;
};

## Localize the SD.Next host URL and sanitize it.
[String]$sdnextUrl = "${env:SDNEXT_HOST}".TrimEnd('/').Trim();

## Localize the SD.Next model path and sanitize it.
[String]$sdnextModelPath = "${env:SDNEXT_MODEL_PATH}".Trim();

## Localize the list of SD.Next models to provision and sanitize it.
[String[]]$sdnextModels = if ("${env:SDNEXT_MODEL_LIST}".Trim().Contains(','))
{
    "${env:SDNEXT_MODEL_LIST}".Trim() -split ','
}
else
{
    @("${env:SDNEXT_MODEL_LIST}".Trim())
};

## Ensure we have an SD.Next host URL to work with.
if ('' -eq "${sdnextUrl}".Trim())
{

    ## Write a message to the console indicating that the SDNEXT_HOST environment variable is not set.
    Write-Host 'ERROR: The SDNEXT_HOST environment variable is not set. Please set it to the SD.Next host URL and try again.' `
        -ForegroundColor DarkRed;

    ## Exit the script with a non-zero exit code to indicate an error.
    exit 1;
}

## Ensure we have an SD.Next model path to work with.
if ('' -eq "${sdnextModelPath}".Trim())
{
    $sdnextModelPath = '/mnt/models/Stable-diffusion';
}

## Ensure the SD.Next model path exists on the filesystem.  Create it if it does not exist.
if (-not (Test-Path -Path "${sdnextModelPath}" -PathType Container))
{

    ## Try to create the SD.Next model path directory.  If the creation fails,
    ## it will throw an exception that will be caught by the catch block.
    try
    {

        ## Create the SD.Next model path directory.
        New-Item -Path "${sdnextModelPath}" -ItemType Directory -Force | Out-Null;

        ## Write a message to the console indicating that the SD.Next model path was created successfully.
        Write-Host "INFO: SD.Next model path [${sdnextModelPath}] did not exist, but was created successfully." `
            -ForegroundColor DarkGreen;
    }
    catch
    {

        ## Write a message to the console indicating that there was an error creating the SD.Next model path directory.
        Write-Host "ERROR: Failed to create SD.Next model path directory at [${sdnextModelPath}]. Exception: $_" `
            -ForegroundColor DarkRed;

        ## Exit the script with a non-zero exit code to indicate an error.
        exit 1;
    }
}

## If we have no SD.Next models to provision, write a warning message to the console.
if ($sdnextModels.Count -eq 0)
{

    ## Write a message to the console indicating that no SD.Next models were found to provision.
    Write-Host 'WARNING: No SD.Next models found to provision. Please set the SDNEXT_MODEL_LIST environment variable with a comma-separated list of model names and try again.' `
        -ForegroundColor DarkYellow;
}

## Otherwise, iterate through the list of SD.Next models and trigger their download via the API.
else
{

    ## Write a message to the console indicating that we are starting the model provisioning process for SD.Next.
    Write-Host "INFO: Starting model provisioning process for $( $sdnextModels.Count ) SD.Next models." `
        -ForegroundColor DarkGray;

    ## Iterate through the list of SD.Next models and trigger their download via the API.
    foreach ($model in $sdnextModels)
    {

        ## Write a message to the console indicating that we are processing the current SD.Next model.
        Write-Host "INFO: Processing SD.Next model: ${model}" -ForegroundColor DarkGray;

        ## The models are URLs and we need to grab the filename from the URL to use as the model name. We'll parse the
        ## URI and extract the last segment of the path to get the filename, which will be used as the model name.
        [String]$modelName = [System.IO.Path]::GetFileName([System.Uri]::new($model).AbsolutePath);

        ## Localize the absolute path where the SD.Next model should be
        ## stored by combining the SD.Next model path with the model name.
        [String]$modelPath = Join-Path -ChildPath "${modelName}" -Path "${sdnextModelPath}";

        ## Check for an already downloaded model at the specified path.
        if (Test-Path -Path "${modelPath}" -PathType Leaf)
        {

            ## Check the force-download flag to determine if we should skip the download or not.
            if (-not $forceDownload)
            {

                ## Write a message to the console indicating that the SD.Next
                ## model already exists and we are skipping the download.
                Write-Host "INFO: SD.Next model [${modelName}] already exists at [${modelPath}]. Skipping download." `
                    -ForegroundColor DarkGray;

                ## Skip to the next model in the list.
                continue;
            }
            else
            {

                ## Write a message to the console indicating that we are forcing
                ## the download of the SD.Next model even though it already exists.
                Write-Host "INFO: SD.Next model [${modelName}] already exists at [${modelPath}], but force-download is enabled. Removing existing model." `
                    -ForegroundColor DarkGray;

                ## Try to remove the existing SD.Next model file.  If the removal fails,
                ## it will throw an exception that will be caught by the catch block.
                try
                {

                    ## Remove the existing SD.Next model file.
                    Remove-Item -Path "${modelPath}" -Force;

                    ## Write a message to the console indicating that the existing SD.Next model file was removed successfully.
                    Write-Host "INFO: Successfully removed existing SD.Next model file at [${modelPath}]." `
                        -ForegroundColor DarkGreen;
                }
                catch
                {

                    ## We'll have to skip the download of this model since we can't remove the
                    ## existing file, so we'll write a message to the console indicating that we
                    ## are skipping the download and then continue to the next model in the list.
                    Write-Host "WARNING: Skipping download of SD.Next model [${modelName}] since we were unable to remove the existing file at [${modelPath}]." `
                        -ForegroundColor DarkYellow;

                    ## Skip to the next model in the list.
                    continue;
                }
            }
        }

        ## Try to trigger the download of the SD.Next model via the API.  If the download
        ## fails, it will throw an exception that will be caught by the catch block.
        try
        {

            ## Write a message to the console indicating that we are starting
            ## the download of the SD.Next model from the provided URL via the API.
            Write-Host "INFO: Starting download of SD.Next model [${modelName}] from ${model}." `
                -ForegroundColor DarkGray;

            ## Use Start-BitsTransfer to download the SD.Next model from the provided URL to the specified model path.
            Invoke-WebRequest -OutFile "${modelPath}" -Uri "${model}";

            ## Write a message to the console indicating that the SD.Next model was downloaded successfully.
            Write-Host "DONE: Successfully downloaded SD.Next model [${modelName}] to [${modelPath}]." `
                -ForegroundColor DarkGreen;
        }
        catch
        {

            ## Write a message to the console indicating that there was an error updating the SD.Next image model via the API.
            Write-Host "ERROR: Failed to trigger download for ${model} via SD.Next API with: ${_}" `
                -ForegroundColor DarkRed;
        }
    }
}
