using namespace System;
using namespace System.Collections;
using namespace System.Collections.Generic;

## Define a function that will execute a deep merge on two objects.
function Merge-Object {

    <#
    .SYNOPSIS
        Merges two objects recursively, combining their properties and values.

    .DESCRIPTION
        This function takes two objects as input and merges them recursively. If both objects are HashTables, it
        merges their keys and values. If both objects are Lists, it merges them while filtering duplicates. If
        the objects are of mismatched types or scalar values, it overrides the base object with the override object.

    .PARAMETER Base
        The base object to merge onto.

    .PARAMETER Override
        The object to merge onto the base object.

    .OUTPUTS
        Returns the merged object.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)] $Base,
        [Parameter(Mandatory = $true, Position = 1)] $Override);

    ## If both the base and override are HashTables [IDictionary], we'll need to merge them recursively.
    if ($Base -is [IDictionary] -and $Override -is [IDictionary]) {

        ## We'll need to clone the base HashTable to avoid modifying it directly.
        $result = [hashtable]::new($Base);

        ## Iterate through each key in the override HashTable and merge it with the base HashTable.
        foreach ($key in $Override.Keys) {

            ## If the key exists in the base HashTable, we'll need to merge the values recursively.
            ## Otherwise, we'll just add the key-value pair from the override HashTable to the result HashTable.
            if ($result.Contains($key)) { $result[$key] = Merge-Object -Base:$result[$key] -Override:$Override[$key]; }

            ## Otherwise the key only exists in the override HashTable,
            ## so we'll add it directly to the result HashTable.
            else { $result[$key] = $Override[$key]; }
        }

        ## We're done, return the resulting HashTable that contains
        ## the merged values from both the base and override HashTables.
        return $result
    }

    ## If both the base and override are Lists [IList], we'll need to merge them while filtering duplicates.
    if ($Base -is [IList] -and $Override -is [IList]) {

        # Use a StringComparer HashSet to filter duplicates case-insensitively
        [HashSet[string]] $set = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        ## Iterate through the base and override lists and add each item
        ## to the HashSet, which will automatically filter duplicates.
        foreach ($item in $Base) { [void]$set.Add($item.ToString()); }
        foreach ($item in $Override) { [void]$set.Add($item.ToString()); }

        ## We're done, return the resulting List that contains the merged values
        ## from both the base and override Lists, with duplicates filtered out.
        return [string[]]$set.ToArray();
    }

    ## If the base and override are of mismatched types or scalar values, we'll override the base completely.
    return $Override
}
