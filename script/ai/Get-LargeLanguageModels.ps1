#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Provision large language models for Ollama and SD.Next.

.DESCRIPTION
    This script provisions large language models for Ollama and SD.Next by checking the health of the respective
    services and downloading the specified models if they are not already present.

.PARAMETER $Env:OLLAMA_HOST
    The URL of the Ollama host. This environment variable must be set before running the script.

.PARAMETER $Env:OLLAMA_MODEL_LIST
    A comma-separated list of Ollama model names to provision
     This environment variable must be set before running the script.

.PARAMETER $Env:SDNEXT_HOST
    The URL of the SD.Next host. This environment variable must be set before running the script.
#>

## Localize the Ollama host URL and sanitize it.
[String] $ollamaUrl = "${env:OLLAMA_HOST}".TrimEnd('/').Trim();

## Localize the list of Ollama models to provision and sanitize it.
[String[]] $ollamaModels = if ("${env:OLLAMA_MODEL_LIST}".Trim() -like '*,*') {
    "${env:OLLAMA_MODEL_LIST}".Trim() -split ',' } else { @("${env:OLLAMA_MODEL_LIST}".Trim()) };

## Sanitize the list of Ollama models by trimming whitespace and
## removing any empty entries, then sort the list and remove duplicates.
$ollamaModels = $ollamaModels | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique;

## Localize the SD.Next host URL and sanitize it.
[String] $sdnextUrl = "${env:SDNEXT_HOST}".TrimEnd('/').Trim();

## Determine whether we should force download the SD.Next image model.
[bool] $forceSdDownload = if (@('1', 'ok', 'on', 't', 'true', 'yes') -contains "${env:SDNEXT_FORCE_DOWNLOAD}".Trim().ToLower()) { $true } else { $false };

## Ensure we have an Ollama host URL to work with.
if ('' -eq "${ollamaUrl}".Trim()) {

    ## Write a message to the console indicating that the OLLAMA_HOST environment variable is not set.
    Write-Host 'ERROR: The OLLAMA_HOST environment variable is not set. Please set it to the Ollama host URL and try again.' -ForegroundColor DarkRed;

    ## Exit the script with a non-zero exit code to indicate an error.
    exit 1;
}

## Ensure we have an SD.Next host URL to work with.
if ('' -eq "${sdnextUrl}".Trim()) {

    ## Write a message to the console indicating that the SDNEXT_HOST environment variable is not set.
    Write-Host 'ERROR: The SDNEXT_HOST environment variable is not set. Please set it to the SD.Next host URL and try again.' -ForegroundColor DarkRed;

    ## Exit the script with a non-zero exit code to indicate an error.
    exit 1;
}

## Ensure the ollama url is healthy before proceeding with model provisioning.
try {

    ## Execute the request against the Ollama host to check its health status.  If the
    ## request fails, it will throw an exception that will be caught by the catch block.
    $healthResponse = Invoke-RestMethod -Uri "${ollamaUrl}/api/tags" -Method Get -TimeoutSec 10

    ## Ensure we got a 200 OK response from the Ollama host.  If not, throw an exception to be caught by the catch block.
    if (-not $healthResponse) {

        ## Write a message to the console indicating that the Ollama host is not healthy.
        Write-Host "ERROR: Ollama host [${ollamaUrl}] is not healthy. Please ensure the Ollama service is running and reachable." -ForegroundColor DarkRed;

        ## Exit the script with a non-zero exit code to indicate an error.
        exit 1;
    }
} catch {

    ## Write a message to the console indicating that the Ollama host is not reachable.
    Write-Host "ERROR: Failed to reach Ollama host [${ollamaUrl}]. Exception: $_" -ForegroundColor DarkRed;

    ## Exit the script with a non-zero exit code to indicate an error.
    exit 1;
}

## Check for the presence of models to provision.  If none are found, write a message to the console and exit.
if ($ollamaModels.Count -eq 0) {

    ## Write a message to the console indicating that no models were found to provision.
    Write-Host 'WARNING: No Ollama models found to provision. Please set the OLLAMA_MODEL_LIST environment variable with a comma-separated list of model names and try again.' -ForegroundColor DarkYellow;
} else {

    ## Write a message to the console indicating that we are starting the model provisioning process.
    Write-Host "INFO: Starting model provisioning process for ${ollamaModels.Count} Ollama models." -ForegroundColor DarkGray;

    ## Iterate through the list of models and provision each one.
    foreach ($model in $ollamaModels) {

        ## Write a message to the console indicating that we are processing the current model.
        Write-Host "INFO: Processing Ollama model: ${model}" -ForegroundColor DarkGray;

        ## Create the request body for the Ollama API call to provision the model.
        $body = @{ name = $model; stream = $false } | ConvertTo-Json;

        ## Try to provision the model by making a request to the Ollama API.  If the request
        ## fails, it will throw an exception that will be caught by the catch block.
        try {

            ## Execute the request against the Ollama host to provision the model.  If the request
            ## fails, it will throw an exception that will be caught by the catch block.
            $response = Invoke-RestMethod -Body $body -ContentType 'application/json' -Method Post -TimeoutSec 1800 -Uri "${ollamaUrl}/api/pull";

            ## Check the response status to ensure the model was provisioned successfully.  If not, throw an exception to be caught by the catch block.
            if ($response.status -eq 'success') {

                ## Write a message to the console indicating that the model was successfully provisioned.
                Write-Host "DONE: Successfully provisioned ${model} for Ollama. Response status: $($response.status)" -ForegroundColor DarkGreen;
            } else {

                ## Write a message to the console indicating that the model was not successfully provisioned.
                Write-Host "ERROR: Failed to provision ${model} for Ollama. Response status: $($response.status)" -ForegroundColor DarkRed;
            }
        } catch {

            ## Write a message to the console indicating that there was an error provisioning the model.
            Write-Host "ERROR: Failed to provision ${model} for Ollama. Exception: $_" -ForegroundColor DarkRed;
        }
    }
}

## Write a message to the console indicating that the model provisioning process is complete.
Write-Host 'INFO: Ollama model provisioning process complete.' -ForegroundColor DarkGray;

## Try to check the health of the SD.Next host to ensure it is reachable.  If the request
## fails, it will throw an exception that will be caught by the catch block.
try {

    ## Execute the request against the SD.Next host to check its health status.  If the
    ## request fails, it will throw an exception that will be caught by the catch block.
    $sdnextHealthResponse =
        Invoke-RestMethod  -ContentType 'application/json' -Method Get -TimeoutSec 10 -Uri "${sdnextUrl}/sdapi/v1/status";

    ## Ensure we got a response from the SD.Next host.  If not, throw an exception to be caught by the catch block.
    if (-not $sdnextHealthResponse) {

        ## Write a message to the console indicating that the SD.Next host is not healthy.
        Write-Host "ERROR: SD.Next host [${sdnextUrl}] is not healthy. Please ensure the SD.Next service is running and reachable." -ForegroundColor DarkRed;

        ## Exit the script with a non-zero exit code to indicate an error.
        exit 1;
    }

    ## Localize the status of the SD.Next host from the deserialized response.
    [String] $sdnextStatus = $sdnextHealthResponse.status.ToLower().Trim();

    ## Ensure the status of the SD.Next host is 'running' or 'idle'.  If not, throw an exception to be caught by the catch block.
    if ($sdnextStatus -ne 'running' -and $sdnextStatus -ne 'idle') {

        ## Write a message to the console indicating that the SD.Next host is not healthy.
        Write-Host "ERROR: SD.Next host [${sdnextUrl}] is not healthy. Current status: ${sdnextStatus}. Please ensure the SD.Next service is running and reachable." -ForegroundColor DarkRed;

        ## Exit the script with a non-zero exit code to indicate an error.
        exit 1;
    }

} catch {

    ## Write a message to the console indicating that the SD.Next host is not reachable.
    Write-Host "ERROR: Failed to reach SD.Next host [${sdnextUrl}]. Exception: $_" -ForegroundColor DarkRed;

    ## Exit the script with a non-zero exit code to indicate an error.
    exit 1;
}
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER TimeString
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
## Localize the target file path for the SD.Next image model that we want to ensure is present.
[String] $targetFile = '/mnt/models/Stable-diffusion/dreamshaper_8.safetensors';

## If we're forcing a download of the SD.Next image model then we need to ensure the model doesn't exist locally.
if ($forceSdDownload) { Remove-Item -ErrorAction SilentlyContinue -Force -Path "${targetFile}"; }

## Write a message to the console indicating that we are checking the status of the SD.Next image model.
Write-Host "INFO: Checking SD.Next Image Model [${targetFile}] status..." -ForegroundColor DarkGray;

## If the model doesn't exist locally, we'll need to download it.
if (-not (Test-Path $targetFile)) {

    ## Write a message to the console indicating that the model was not found
    ## locally and we are triggering a remote download via the SD.Next API.
    Write-Host "INFO: DreamShaper 8 not found locally at [${targetFile}]. Triggering remote SD.Next download API..." -ForegroundColor DarkYellow;

    ## Create the request body for the SD.Next API call to download the image model.
    $body = @{
        subpath = 'Stable-diffusion';
        url = 'https://huggingface.co/autismanon/modeldump/blob/main/dreamshaper_8.safetensors';
    } | ConvertTo-Json;

    ## Try to trigger the download of the image model by making a request to the SD.Next API.
    ## If the request fails, it will throw an exception that will be caught by the catch block.
    try {

        ## Execute the request against the SD.Next host to trigger the download of the image model.
        ## If the request fails, it will throw an exception that will be caught by the catch block.
        Invoke-RestMethod -Body "${body}" -ContentType 'application/json' -Method Post -TimeoutSec 2700 -Uri "${sdnextUrl}/sdapi/v1/download";

        ## Write a message to the console indicating that the SD.Next image model download completed successfully.
        Write-Host 'DONE: SD.Next image model download completed successfully!' -ForegroundColor DarkGreen;
    } catch {

        ## Write a message to the console indicating that there was an error pulling the SD.Next image model via the API.
        Write-Host "ERROR: Failed to pull SD.Next image model via API. Exception: $_" -ForegroundColor DarkRed;

        ## Exit the script with a non-zero exit code to indicate an error.
        exit 1;
    }
} else {

    ## Write a message to the console indicating that the SD.Next image model is already present locally and we are skipping the download.
    Write-Host "INFO: DreamShaper_8_pruned.safetensors is already present locally at [${targetFile}]. Skipping image model pull." -ForegroundColor DarkGray;
}
