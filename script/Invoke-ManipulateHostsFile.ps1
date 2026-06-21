#!/usr/bin/env pwsh
<#
.SYNOPSIS
    This script manipulates the hosts file on the local machine to add or remove
    entries for the stack services based on the provided service map and parameters.

.DESCRIPTION
    This script takes a hashtable of service names and their corresponding IP addresses, and manipulates the hosts
    file on the local machine to add or remove entries for those services. It supports both IPv4 and IPv6 addresses,
    and allows for specifying a domain name, excluding certain services, and performing a dry run without actually
    writing to the hosts file. The script is designed to work on both Windows and UNIX-like systems, and defaults to
    the appropriate hosts file path based on the operating system.

.PARAMETER Domain
    The domain name to use for the stack services in the hosts file. Defaults to the value of the STACK_DOMAIN
    environment variable if not provided.

.PARAMETER DryRun
    A switch parameter to indicate whether to perform a dry run of the hosts file manipulation without actually
    writing to the hosts file. Defaults to false if not provided.

.PARAMETER Exclude
    A list of service names to exclude from manipulation in the hosts file.
    If not provided, all services in the service map will be manipulated.

.PARAMETER Except
    A list of service names to exclude from manipulation in the hosts file.
    If not provided, all services in the service map will be manipulated.

.PARAMETER HostsFile
    The path to the hosts file that contains entries for the stack services. Defaults to '/etc/hosts' on UNIX-like
    systems and 'C:\Windows\System32\drivers\etc\hosts' on Windows if not provided.

.PARAMETER Only
    A list of service names to manipulate in the hosts file.
    If not provided, all services in the service map will be manipulated.

.PARAMETER ServiceMap
    A hashtable of service names and their corresponding IP addresses for manipulation of the hosts file.

.PARAMETER Remove
    A switch parameter to indicate whether to remove the entries from the hosts file instead of adding them.
    Defaults to false if not provided.
#>
param (

        ## We'll need a parameter to specify the domain name for the stack services in the hosts file,
        ## and if not provided, we'll default to the value of the STACK_DOMAIN environment variable.
        [Parameter(Mandatory = $false)]
        [String] $Domain = "${env:STACK_DOMAIN}",

        ## We'll need a switch parameter to indicate whether we want to perform a dry run of the hosts file
        ## manipulation without actually writing to the hosts file, and if not provided, we'll default to false
        ## to allow writing to the hosts file.
        [Parameter(Mandatory = $false)]
        [Switch] $DryRun = $false,

        ## We'll need a parameter to specify a list of service names to exclude from manipulation in the hosts file,
        ## and if not provided, we'll manipulate all services in the service map.
        [Parameter(Mandatory = $false)]
        [String[]] $Exclude = @(),

        ## We'll need a parameter to specify a list of service names to exclude from manipulation in the hosts file,
        ## and if not provided, we'll manipulate all services in the service map.
        [Parameter(Mandatory = $false)]
        [String[]] $Except = @(),

        ## We'll need a parameter to specify the path to the environment file that contains variables for the
        ## stack composer.  UNIX we'll default to /etc/hosts, and Windows we'll default to
        ## C:\Windows\System32\drivers\etc\hosts.
        [Parameter(Mandatory = $false)]
        [String] $HostsFile =
            "$(if ($IsWindows) { "${env:SystemRoot}\System32\drivers\etc\hosts" } else { '/etc/hosts' })",

        ## We'll also want a parameter to specify a list of service names to manipulate in the hosts file,
        ## and if not provided, we'll manipulate all services in the service map.
        [Parameter(Mandatory = $false)]
        [String[]] $Only = @(),

        ## We'll also need a parameter to specify the service map that contains the service
        ## names and their corresponding IP addresses for manipulation of the hosts file.
        [Parameter(Mandatory = $true)]
        [HashTable] $ServiceMap,

        ## Finally, we'll want a switch parameter to indicate whether we want to remove the entries from
        ## the hosts file instead of adding them, and if not provided, we'll default to adding entries.
        [Parameter(Mandatory = $false)]
        [Switch] $Remove = $false
);

## Define a function to convert a hashtable of hosts into an
## array of hosts file entries for manipulation in the hosts file.
function Get-HostsAsEntries {
    <#
    .SYNOPSIS
        Converts a hashtable of hosts into an array of hosts file entries for manipulation in the hosts file.

    .DESCRIPTION
        This function takes a hashtable of hosts where the keys are IP addresses and the values are host names, and
        converts them into an array of hosts file entries that can be added to or removed from the hosts file. It
        formats the entries with proper spacing for readability and supports both IPv4 and IPv6 addresses.

    .PARAMETER HostsMap
        A hashtable where the keys are IP addresses and the values are host names that
        we want to convert into hosts file entries for manipulation in the hosts file.

    .OUTPUTS
        An array of formatted hosts file entries that can be added
        to or removed from the hosts file for the stack services.
    #>
    param ([Parameter(Mandatory = $true)] $HostsMap);

    ## Define our container for the new hosts file entries.
    [String[]] $hostsFileEntries = @();

    ## Iterate through the provided hosts map and create the new hosts file entries for our stack services.
    $HostsMap.Keys | ForEach-Object {
        $hostsFileEntries += '{0,-24} {1,-42} {2}' -f $_.Trim('.', ':', ' '),
                [String]::Format('{0}.{1}', $HostsMap[$_].Trim('.', ':', '-', '_', ' '),
                    $Domain.Trim('.', ':', '-', '_', ' ')), $HostsMap[$_].Trim('.', ':', '-', '_', ' ');
        };

    ## We're done, return the new hosts file entries.
    return $hostsFileEntries;
}

## Define a function to sort a hashtable of hosts by their IP addresses for better readability in the hosts file.
function Get-HostsSortedByIpAddress {

    <#
    .SYNOPSIS
        Sorts a hashtable of hosts by their IP addresses for better readability in the hosts file.

    .DESCRIPTION
        This function takes a hashtable of hosts where the keys are IP addresses and the values are host names, and
        sorts them by the octet of the IP address for better readability when adding them to the hosts file. It
        supports both IPv4 and IPv6 addresses by determining the appropriate delimiter ('.' for IPv4 and '::' for IPv6)
        and extracting the last segment of the IP address for sorting.

    .PARAMETER HostsMap
        A hashtable where the keys are IP addresses and the values are host
        ## names that we want to sort for manipulation in the hosts file.

    .OUTPUTS
        A new ordered hashtable of hosts sorted by their IP addresses for better readability in the hosts
    #>
    param ([Parameter(Mandatory = $true)] [HashTable] $HostsMap);

    ## Create a new ordered hashtable to store the sorted hosts.
    $sortedHostsMap = [Ordered] @{};

    ## Sort the hosts map by the octet of the IP address for better readability.
    $HostsMap.GetEnumerator() | Sort-Object -Property {

        ## Check for an IPv4 address and extract the last octet for sorting.
        [String] $delimiter = if ($_.Key -like '*.*') { '.' } elseif ($_.Key -like '*::*') { '::' } else { return 0; }

        ## Extract the last segment of the IP address after the delimiter and convert it to an integer for sorting.
        [Int] $octet = [Int] ($_.Key.Split($delimiter)[-1]);

        ## We're done, return the octet for sorting.
        return $octet;
    } | ForEach-Object { $sortedHostsMap[$_.Key] = $_.Value; };

    ## Return the sorted hosts map.
    return $sortedHostsMap;
}

## Check to see if the provided hosts file exists and is writable, and if not, write a
## message to the console and exit without an error code since there's nothing to manipulate.
if (-not (Test-Path -ErrorAction SilentlyContinue -Path "${HostsFile}")) {

    ## If the hosts file doesn't exist, write a message to the console and exit with an error code.
    Write-Host "ERROR: Hosts file not found at [${HostsFile}]. Cannot manipulate hosts file entries." -ForegroundColor DarkYellow;

    ## We're done, silently exit without an error code since the
    ## hosts file is not present and there's nothing to manipulate.
    exit 0;
}

## Ensure we have a domain name to use for the stack services in the hosts file, and if
## not provided, we'll default to the value of the STACK_DOMAIN environment variable.
if ("${Domain}".Trim() -eq '') { $Domain = 'stack.local'; }

## Sanitize the domain name to ensure it doesn't have any leading or trailing
## whitespace or special characters that could cause issues in the hosts file.
$Domain = "${Domain}".Trim('.', ':', '-', '_', ' ');

## Localize the list of services we should exclude from manipulation.
[HashTable] $excludedServiceMap = @{};

## Iterate through the provided list of services to exclude and create a new hashtable of excluded services for later use in manipulating the hosts file.
$Exclude |
    Where-Object { "${_}".Trim() -ne '' } |
        ForEach-Object { "${_}".Trim() } |
            Sort-Object -Unique |
                Where-Object { $ServiceMap.ContainsKey("${_}") } |
                    ForEach-Object { $excludedServiceMap["${_}"] = $ServiceMap["${_}"]; };

## Localize the keys of our included services map for later use in manipulating the hosts file, which is either all
## services in the service map or a specified list of services via the -Only parameter, excluding any services specified
## in the -Exclude parameter.
[String[]] $includedServiceMapKeys = if ($Only.Length -gt 0) { $Only } else { $ServiceMap.Keys }

## Localize the list of services we should manipulate in the hosts file, which is either all services in the service map
## or a specified list of services via the -Only parameter, excluding any services specified in the -Exclude parameter.
[HashTable] $includedServiceMap = @{};

## Iterate through the provided list of services to include and create a new
## hashtable of included services for later use in manipulating the hosts file.
$includedServiceMapKeys |
    Where-Object { "${_}".Trim() -ne '' } |
        ForEach-Object { "${_}".Trim() } |
            Sort-Object -Unique |
                Where-Object { -not $excludedServiceMap.ContainsKey("${_}") } |
                    Where-Object { $ServiceMap.ContainsKey("${_}") } |
                        ForEach-Object { $includedServiceMap["${_}"] = $ServiceMap["${_}"]; };

## Define our map of all IP addresses to their container host names for the stack for all services, which
## we will use to manipulate entries in the hosts file based on the included and excluded hosts maps.
[HashTable] $allHostsMapUnordered = @{};

## Iterate through the provided service map and create a new
## hashtable of all hosts for later use in manipulating the hosts file.
$ServiceMap.GetEnumerator() | Where-Object { $_.Value.IPv4 -ne 'dhcp' -and $_.Value.IPv6 -ne 'dhcp' } |
    ForEach-Object {
        $allHostsMapUnordered[$_.Value.IPv4] = $_.Key.Trim().ToLower();
        $allHostsMapUnordered[$_.Value.IPv6] = $_.Key.Trim().ToLower();
    };

## Define our map of excluded IP addresses to their container host names for the stack for the excluded services, which
## we will use to remove entries from the hosts file if the -Remove switch is specified.
[HashTable] $excludedHostsMapUnordered = @{};

## Iterate through the provided excluded service map and create a new
## hashtable of excluded hosts for later use in manipulating the hosts file.
$excludedServiceMap.GetEnumerator() | Where-Object { $_.Value.IPv4 -ne 'dhcp' -and $_.Value.IPv6 -ne 'dhcp' } |
    ForEach-Object {
        $excludedHostsMapUnordered[$_.Value.IPv4] = $_.Key.Trim().ToLower();
        $excludedHostsMapUnordered[$_.Value.IPv6] = $_.Key.Trim().ToLower();
    };

## Define our map of included IP addresses to their container host names for the stack for the included services, which
## we will use to add entries to the hosts file if the -Remove switch is not specified.
[HashTable] $includedHostsMapUnordered = @{};

## Iterate through the provided included service map and create a new
## hashtable of included hosts for later use in manipulating the hosts file.
$includedServiceMap.GetEnumerator() | Where-Object { $_.Value.IPv4 -ne 'dhcp' -and $_.Value.IPv6 -ne 'dhcp' } |
    ForEach-Object {
        $includedHostsMapUnordered[$_.Value.IPv4] = $_.Key.Trim().ToLower();
        $includedHostsMapUnordered[$_.Value.IPv6] = $_.Key.Trim().ToLower();
    };

## Define our map of IP addresses to their container host names for the stack for all services, which
## we will use to manipulate entries in the hosts file based on the included and excluded hosts maps.
$allHostsMap = Get-HostsSortedByIpAddress -HostsMap:$allHostsMapUnordered;

## Define our map of IP addresses to their container host names for the stack for the excluded services,
## which we will use to remove entries from the hosts file if the -Remove switch is specified.
$excludedHostsMap = Get-HostsSortedByIpAddress -HostsMap:$excludedHostsMapUnordered;

## Define our map of IP addresses to their container host names for the stack for the included services,
## which we will use to add entries to the hosts file if the -Remove switch is not specified.
$includedHostsMap = Get-HostsSortedByIpAddress -HostsMap:$includedHostsMapUnordered;

## Create the container for our new hosts file entries which will later be written back to the hosts file, which we
## will populate with the existing hosts file entries that are not being manipulated and the new entries for our stack
## services based on the included and excluded hosts maps.
[String[]] $newHostsFileEntries = @();

## Localize the existing hosts file entries for later use in manipulating the hosts file, which we will populate with
## the existing hosts file entries that are not being manipulated and the new entries for our stack services based on
## the included and excluded hosts maps.
[String[]] $existingHostsFileEntries = if (Test-Path -ErrorAction SilentlyContinue -Path "${HostsFile}") {
    (Get-Content -Path "${HostsFile}" | ForEach-Object { $_.Trim() }); } else { @(); }

## Iterate through the hosts file entries to remove any entries that are related to our stack services.
foreach ($entry in $existingHostsFileEntries) {

    ## If this is a comment or an empty line, we'll preserve it in the new hosts file entries and continue to the next entry.
    if ($entry -match '^\s*#' -or $entry -match '^\s*$') { $newHostsFileEntries += $entry; continue; }

    ## Check the keys of the all-hosts map to see if the current entry's IP address is in the map, and if so, we'll
    ## need to exclude it from the new hosts file entries as we'll process the services in the included hosts map later.
    if (($allHostsMap.Keys | Where-Object { $entry -like "${_}*" }).Count -eq 0) {
        $newHostsFileEntries += $entry; continue; }
}

## Check the remove flag and the except list to determine if we should add some buffer space to the end of the hosts
## file entries for our new stack service entries, and if so, we'll add two empty lines to ensure there's space for our
## new entries, or if we should remove any extra empty lines beyond the last two to avoid unnecessary whitespace in the
## hosts file.
if (-not $Remove -or ($Remove -and $Except.Length -gt 0)) {

    ## Check the last two entries in the hosts file entries for buffer space and add
    ## two empty lines if necessary to ensure there's space for our new entries.
    if ($newHostsFileEntries[-1].Trim() -ne '' -and $newHostsFileEntries[-2].Trim() -ne '') {
        $newHostsFileEntries += ''; $newHostsFileEntries += ''; }

    ## Check the last entry in the hosts file entries for buffer space and add
    ## an empty line if necessary to ensure there's space for our new entries.
    elseif ($newHostsFileEntries[-1].Trim() -ne '') {
        $newHostsFileEntries += ''; }

    ## Otherwise, ensure there are only two empty lines at the end of the hosts file entries for proper formatting,
    ## we'll remove any extra empty lines beyond the last two to avoid unnecessary whitespace in the hosts file.
    else { while ($newHostsFileEntries[-1].Trim() -eq '' -and $newHostsFileEntries[-2].Trim() -eq '') {
            $newHostsFileEntries = $newHostsFileEntries[0..($newHostsFileEntries.Length - 2)]; } }
}

## Check the remove flag to determine which hosts we're adding to and which ones we're removing from the hosts file.
if ($Remove) { $newHostsFileEntries += Get-HostsAsEntries -HostsMap:$excludedHostsMap; }
else { $newHostsFileEntries += Get-HostsAsEntries -HostsMap:$includedHostsMap; }

## Write a message indicating that we're updating the hosts file with our stack service entries.
Write-Host "INFO: Updating the hosts file [${HostsFile}] with entries for the stack services:" -ForegroundColor DarkGray;
Write-Host ($newHostsFileEntries -join [System.Environment]::NewLine) -ForegroundColor DarkGray;
Write-Host '';

## Now we'll write the new hosts file entries back to the hosts file, ensuring that we have the proper permissions to do so.
try {

    ## Define the content of our new hosts file by joining the new hosts file entries with the appropriate newline character for the operating system.
    $newHostsFileContent = $newHostsFileEntries -join "$(if ($IsWindows) { "`r`n" } else { "`n" })";

    ## Write the new hosts file entries back to the hosts file, ensuring that we have the proper permissions to do so.
    if (-not $DryRun.ToBool()) {
        Set-Content -Encoding utf8 -ErrorAction Stop -Force -Path "${HostsFile}" -Value $newHostsFileContent; }

    ## Write a message to the console indicating that we've successfully
    ## manipulated the hosts file with new entries for our stack services.
    Write-Host "DONE: Successfully wrote hosts file [${HostsFile}] with new entries for stack services." -ForegroundColor DarkGreen;
} catch {

    ## Write a message to the console indicating that we've failed
    ## to manipulate the hosts file and exit with an error code.
    Write-Host "ERROR: Failed to write hosts file [${HostsFile}] with Exception: $($_.Exception.Message)" -ForegroundColor DarkRed;

    ## We're done, exit with an error code since we failed to manipulate the hosts file.
    exit 1;
}
