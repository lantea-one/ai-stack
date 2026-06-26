#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Provision large language models for Ollama.

.DESCRIPTION
    This script provisions large language models for Ollama by checking the health of the Ollama service
    and downloading the specified models if they are not already present.

.PARAMETER $Env:OLLAMA_HOST
    The URL of the Ollama host.
    This environment variable must be set before running the script.

.PARAMETER $Env:OLLAMA_MODEL_LIST
    A comma-separated list of Ollama model names to provision.
    This environment variable must be set before running the script.
#>

## Localize the Ollama host URL and sanitize it.
[String]$ollamaUrl = "${env:OLLAMA_HOST}".TrimEnd('/').Trim();

## Localize the list of Ollama models to provision and sanitize it.
[String[]]$ollamaModels = if ( "${env:OLLAMA_MODEL_LIST}".Trim().Contains(','))
{
    ## Set the model list to an array of model names by splitting the comma-separated list.
    "${env:OLLAMA_MODEL_LIST}".Trim() -split ',';
}

## Otherwise, if the OLLAMA_MODEL_LIST environment variable
## does not contain a comma, treat it as a single model name.
else
{
    ## Set the model list to an array containing a single model name.
    @("${env:OLLAMA_MODEL_LIST}".Trim())
};

## Sanitize the list of Ollama models by trimming whitespace and
## removing any empty entries, then sort the list and remove duplicates.
$ollamaModels = $ollamaModels | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique;

## Ensure we have an Ollama host URL to work with.
if ('' -eq "${ollamaUrl}".Trim())
{
    ## Write a message to the console indicating that the OLLAMA_HOST environment variable is not set.
    Write-Host 'ERROR: The OLLAMA_HOST environment variable is not set. Please set it to the Ollama host URL and try again.' `
        -ForegroundColor DarkRed;

    ## Exit the script with a non-zero exit code to indicate an error.
    exit 1;
}

## Try to ensure the ollama url is healthy before proceeding with model provisioning.
try
{
    ## Execute the request against the Ollama host to check its health status.  If the
    ## request fails, it will throw an exception that will be caught by the catch block.
    $healthResponse = Invoke-RestMethod -Uri "${ollamaUrl}/api/tags" -Method Get -TimeoutSec 10

    ## Ensure we got a 200 OK response from the Ollama host.  If not, throw an exception to be caught by the catch block.
    if (-not $healthResponse)
    {

        ## Write a message to the console indicating that the Ollama host is not healthy.
        Write-Host "ERROR: Ollama host [${ollamaUrl}] is not healthy. Please ensure the Ollama service is running and reachable." `
            -ForegroundColor DarkRed;

        ## Exit the script with a non-zero exit code to indicate an error.
        exit 1;
    }
}

## Catch any exceptions that occur during the health check of the Ollama host.
catch
{
    ## Write a message to the console indicating that the Ollama host is not reachable.
    Write-Host "ERROR: Failed to reach Ollama host [${ollamaUrl}]. Exception: $_" `
        -ForegroundColor DarkRed;

    ## Exit the script with a non-zero exit code to indicate an error.
    exit 1;
}

## Check for the presence of models to provision.  If none are found, write a message to the console and exit.
if ($ollamaModels.Count -eq 0)
{
    ## Write a message to the console indicating that no models were found to provision.
    Write-Host 'WARNING: No Ollama models found to provision. Please set the OLLAMA_MODEL_LIST environment variable with a comma-separated list of model names and try again.' `
        -ForegroundColor DarkYellow;
}

## Otherwise, if we have models to provision, proceed with the provisioning process.
else
{
    ## Write a message to the console indicating that we are starting the model provisioning process.
    Write-Host "INFO: Starting model provisioning process for $( $ollamaModels.Count ) Ollama models." `
        -ForegroundColor DarkGray;

    ## Iterate through the list of models and provision each one.
    foreach ($model in $ollamaModels)
    {
        ## Write a message to the console indicating that we are processing the current model.
        Write-Host "INFO: Processing Ollama model: ${model}" -ForegroundColor DarkGray;

        ## Create the request body for the Ollama API call to provision the model.
        $body = @{ name = $model; stream = $false } | ConvertTo-Json;

        ## Try to provision the model by making a request to the Ollama API.  If the request
        ## fails, it will throw an exception that will be caught by the catch block.
        try
        {
            ## Execute the request against the Ollama host to provision the model.  If the request
            ## fails, it will throw an exception that will be caught by the catch block.
            $response = Invoke-RestMethod -Body $body -ContentType 'application/json' -Method Post `
                -TimeoutSec 1800 -Uri "${ollamaUrl}/api/pull";

            ## Check the response status to ensure the model was provisioned
            ## successfully and write a message to the console indicating the result.
            if ($response.status -eq 'success')
            {
                ## Write a message to the console indicating that the model was successfully provisioned.
                Write-Host "DONE: Successfully provisioned ${model} for Ollama. Response status: $( $response.status )" `
                    -ForegroundColor DarkGreen;
            }

            ## Otherwise, write a message to the console indicating
            ## that the model was not successfully provisioned.
            else
            {
                ## Write a message to the console indicating that the model was not successfully provisioned.
                Write-Host "ERROR: Failed to provision ${model} for Ollama. Response status: $( $response.status )" `
                    -ForegroundColor DarkRed;
            }
        }

        ## Catch any exceptions that occur during the model provisioning process.
        catch
        {
            ## Write a message to the console indicating that there was an error provisioning the model.
            Write-Host "ERROR: Failed to provision ${model} for Ollama. Exception: $_" `
                -ForegroundColor DarkRed;
        }
    }
}

## Write a message to the console indicating that the model provisioning process is complete.
Write-Host 'INFO: Ollama model provisioning process complete.' `
    -ForegroundColor DarkGray;
