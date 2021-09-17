try
{
    if ($Global:191cf922f94e46709f6b1818ae32f66b_ForceLoadPowerShellCmdlets -eq $true) { throw "Skipping DataSharp Compilation" }
    $date = [System.IO.File]::GetLastWriteTime("$PSScriptRoot\DataSharp\Helpers.cs").ToString("yyyyMMdd_HHmmss")
    $Script:OutputPath = "$Env:LOCALAPPDATA\Rhodium\Module\DataSharp_$date\DataSharp.dll"
    if (![System.IO.File]::Exists($outputPath))
    {
        [void][System.IO.Directory]::CreateDirectory("$Env:LOCALAPPDATA\Rhodium")
        [void][System.IO.Directory]::CreateDirectory("$Env:LOCALAPPDATA\Rhodium\Module")
        [void][System.IO.Directory]::CreateDirectory("$Env:LOCALAPPDATA\Rhodium\Module\DataSharp_$date")
        $fileList = [System.IO.Directory]::GetFiles("$PSScriptRoot\DataSharp", "*.cs")
        Add-Type -Path $fileList -OutputAssembly $Script:OutputPath -OutputType Library -ErrorAction Stop
    }

    Import-Module -Name $Script:OutputPath -Force -ErrorAction Stop

    $Script:LoadedDataSharp = $true
}
catch
{
    Write-Warning "Unable to compile C# cmdlets; falling back to regular cmdlets."
    $Script:LoadedDataSharp = $false
}


Add-Type @"
using System;
using System.Management.Automation;

namespace Rhodium.Data
{
    public static class DataHelpers
    {
        public static PSObject CloneObject(PSObject BaseObject, string[] AddProperties)
        {
            PSObject newObject = new PSObject();
            foreach (var property in BaseObject.Properties)
            {
                if (property is PSNoteProperty)
                    newObject.Properties.Add(property);
                else
                    newObject.Properties.Add(new PSNoteProperty(property.Name, property.Value));
            }
            if (AddProperties == null)
                return newObject;
            foreach (string propertyName in AddProperties)
            {
                if (newObject.Properties[propertyName] == null)
                    newObject.Properties.Add(new PSNoteProperty(propertyName, null));
            }
            return newObject;
        }

        public static PSObject EnsureHasProperties(PSObject BaseObject, string[] AddProperties)
        {
            foreach (string propertyName in AddProperties)
            {
                if (BaseObject.Properties[propertyName] == null)
                    BaseObject.Properties.Add(new PSNoteProperty(propertyName, null));
            }
            return BaseObject;
        }
    }
}
"@

Function Group-Denormalized
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0, Mandatory=$true)] [string[]] $GroupProperty,
        [Parameter()] [switch] $NoCount,
        [Parameter()] [string[]] $KeepFirst,
        [Parameter()] [string[]] $KeepLast,
        [Parameter()] [string[]] $KeepAll,
        [Parameter()] [string[]] $KeepUnique,
        [Parameter()] [string[]] $Sum,
        [Parameter()] [string[]] $Min,
        [Parameter()] [string[]] $Max,
        [Parameter()] [string[]] $Avg,
        [Parameter()] [string[]] $CountAll,
        [Parameter()] [string[]] $CountUnique,
        [Parameter()] [switch] $AllowEmpty,
        [Parameter()] [string] $JoinWith,
        [Parameter()] [string] $ToGroupProperty
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
    }
    End
    {
        Function SelectLikeAny([string[]]$PropertyList, [string[]]$LikeList, $Dictionary)
        {
            foreach ($property in $PropertyList)
            {
                foreach ($like in $LikeList)
                {
                    if ($property -like $like) { $Dictionary[$property] = $property; continue }
                }
            }
        }

        $keepFirstDict = @{}
        $keepLastDict = @{}
        $keepAllDict = @{}
        $keepUniqueDict = @{}
        $countAllDict = @{}
        $countUniqueDict = @{}
        $sumDict = @{}
        $minDict = @{}
        $maxDict = @{}
        $avgDict = @{}

        $propertyList = $inputObjectList[0].PSObject.Properties.Name
        SelectLikeAny $propertyList $KeepFirst $keepFirstDict
        SelectLikeAny $propertyList $KeepLast $keepLastDict
        SelectLikeAny $propertyList $KeepAll $keepAllDict
        SelectLikeAny $propertyList $KeepUnique $keepUniqueDict
        SelectLikeAny $propertyList $Sum $sumDict
        SelectLikeAny $propertyList $Min $minDict
        SelectLikeAny $propertyList $Max $maxDict
        SelectLikeAny $propertyList $Avg $avgDict
        SelectLikeAny $propertyList $CountAll $countAllDict
        SelectLikeAny $propertyList $CountUnique $countUniqueDict

        $propertyLastUsedDict = @{}
        $propertyNeedsRenameDict = @{}
        $dictPrefixDict = @{}
        $dictPrefixDict[$keepFirstDict] = 'First'
        $dictPrefixDict[$keepLastDict] = 'Last'
        $dictPrefixDict[$keepAllDict] = 'All'
        $dictPrefixDict[$keepUniqueDict] = 'Unique'
        $dictPrefixDict[$sumDict] = 'Sum'
        $dictPrefixDict[$minDict] = 'Min'
        $dictPrefixDict[$maxDict] = 'Max'
        $dictPrefixDict[$avgDict] = 'Avg'

        foreach ($key in @($countAllDict.Keys)) { $countAllDict[$key] = $key + "CountAll" }
        foreach ($key in @($countUniqueDict.Keys)) { $countUniqueDict[$key] = $key + "CountUnique" }

        foreach ($dict in $dictPrefixDict.Keys)
        {
            foreach ($property in @($dict.Keys))
            {
                $propertyNeedsRename = $propertyNeedsRenameDict[$property]
                if ($propertyNeedsRename -eq $true)
                {
                    $lastDict = $propertyLastUsedDict[$property]
                    $lastDict[$property] = $dictPrefixDict[$lastDict] + $lastDict[$property]
                    $dict[$property] = $dictPrefixDict[$dict] + $dict[$property]
                    $propertyNeedsRenameDict[$property] = $false
                }
                elseif ($propertyNeedsRename -eq $false)
                {
                    $dict[$property] = $dictPrefixDict[$dict] + $dict[$property]
                }
                else
                {
                    $propertyNeedsRenameDict[$property] = $true
                    $propertyLastUsedDict[$property] = $dict
                }
            }
        }

        $groupDict = $inputObjectList | ConvertTo-Dictionary -Ordered -Keys $GroupProperty
        
        foreach ($group in $groupDict.Values)
        {
            $result = [ordered]@{}
            $firstObject = [Linq.Enumerable]::First($group)
            $lastObject = [Linq.Enumerable]::Last($group)
            foreach ($property in $GroupProperty)
            {
                $result[$property] = $firstObject.$property
            }
            if (!$NoCount) { $result['Count'] = $group.Count }
            foreach ($property in $propertyList)
            {
                if ($keepFirstDict.Contains($property))
                {
                    $result[$keepFirstDict[$property]] = $firstObject.$property
                }
                if ($keepLastDict.Contains($property))
                {
                    $result[$keepLastDict[$property]] = $lastObject.$property
                }
                $allList = $uniqueList = $null
                if ($keepAllDict.Contains($property) -or $countAllDict.Contains($property) -or 
                    $keepUniqueDict.Contains($property) -or $countUniqueDict.Contains($property)
                )
                {
                    $allList = foreach ($value in $group.GetEnumerator().$property)
                    {
                        if ($AllowEmpty -or ![String]::IsNullOrWhiteSpace($value)) { $value }
                    }
                }
                if ($keepUniqueDict.Contains($property) -or $countUniqueDict.Contains($property))
                {
                    $uniqueList = $allList | Select-Object -Unique
                }
                if ($keepAllDict.Contains($property))
                {
                    $value = $allList
                    if ($JoinWith) { $value = $value -join $JoinWith }
                    $result[$keepAllDict[$property]] = $value
                }
                if ($keepUniqueDict.Contains($property))
                {
                    $value = $uniqueList
                    if ($JoinWith) { $value = $value -join $JoinWith }
                    $result[$keepUniqueDict[$property]] = $value
                }
                if ($countAllDict.Contains($property))
                {
                    $result[$countAllDict[$property]] = @($allList).Count
                }
                if ($countUniqueDict.Contains($property))
                {
                    $result[$countUniqueDict[$property]] = @($uniqueList).Count
                }
                $measureArgs = @{}
                if ($sumDict.Contains($property)) { $measureArgs.Sum = $true }
                if ($minDict.Contains($property)) { $measureArgs.Minimum = $true }
                if ($maxDict.Contains($property)) { $measureArgs.Maximum = $true }
                if ($avgDict.Contains($property)) { $measureArgs.Average = $true }
                if ($measureArgs.Keys.Count)
                {
                    $measureResult = $group | Where-Object $property -ne $null | Measure-Object -Property $property @measureArgs
                    if ($sumDict.Contains($property))
                    {
                        $result[$sumDict[$property]] = $measureResult.Sum
                    }
                    if ($minDict.Contains($property))
                    {
                        $result[$minDict[$property]] = $measureResult.Minimum
                    }
                    if ($maxDict.Contains($property))
                    {
                        $result[$maxDict[$property]] = $measureResult.Maximum
                    }
                    if ($avgDict.Contains($property))
                    {
                        $result[$avgDict[$property]] = $measureResult.Average
                    }
                }
            }
            if ($ToGroupProperty)
            {
                $result[$ToGroupProperty] = $group
            }

            [pscustomobject]$result
        }
    }
}

Function Group-Pivot
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0, Mandatory=$true)] [string[]] $GroupProperty,
        [Parameter(Position=1, Mandatory=$true)] [string] $ColumnProperty,
        [Parameter(Position=2, Mandatory=$true)] [string] $ValueProperty,
        [Parameter()] [string[]] $KeepFirst,
        [Parameter()] [switch] $NoCount
    )
    Begin
    {
        $inputObjectList = [System.Collections.Generic.List[object]]::new()
        $columnDict = [ordered]@{}
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
        $columnDict[[string]$InputObject.$ColumnProperty] = $true
    }
    End
    {
        $groupDict = $inputObjectList | ConvertTo-Dictionary -Ordered -Keys $GroupProperty
        $valueDict = @{}

        foreach ($value in $columnDict.Keys)
        {
            $valueDict[$value] = $inputObjectList |
                Where-Object $ColumnProperty -eq $value |
                ConvertTo-Dictionary $GroupProperty -KeyJoin '|'
        }

        foreach ($group in $groupDict.Values)
        {
            $result = [ordered]@{}
            foreach ($property in $GroupProperty)
            {
                $result[$property] = $group[0].$property
            }
            $key = $result.Values -join '|' # Keep here since it's building off the group property values

            if (!$NoCount.IsPresent) { $result['Count'] = $group.Count }

            foreach ($property in $KeepFirst)
            {
                $result[$property] = $group[0].$property
            }

            foreach ($value in $columnDict.Keys)
            {
                $valueGroup = $valueDict[$value][$key]
                $result[$value] = if ($valueGroup) { $valueGroup[0].$ValueProperty }
            }

            [pscustomobject]$result
        }
    }
}

Function Join-GroupCount
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0, Mandatory=$true)] [string[]] $GroupProperty,
        [Parameter(Position=1)] [string] $CountProperty = 'GroupCount'
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
    }
    End
    {
        $groupDict = $inputObjectList | ConvertTo-Dictionary -Ordered -Keys $GroupProperty
        foreach ($pair in $groupDict.GetEnumerator())
        {
            $pair.Value | Set-PropertyValue $CountProperty $pair.Value.Count
        }
    }
}

Function Join-GroupHeaderRow
{
    <#
    .SYNOPSIS
    Groups and inserts header (or footer) objects into a pipeline with options to subtotal, label or extract values from the group.

    .PARAMETER InputObject
    The objects to add header rows to.

    .PARAMETER Property
    The properties to group objects by.

    .PARAMETER ObjectScript
    Execute this script for each group ($input variable) and add the results to the header object. Results can be an object or a hashtable.

    .PARAMETER AsFooter
    Insert the new object after the group instead of before the group.

    .PARAMETER SkipSingles
    Don't insert a header if the group has a single item.

    .PARAMETER Set
    Manually set these properties to these values.

    .PARAMETER KeepFirst
    Automatically add the first value of these properties to the header of each group.

    .PARAMETER Subtotal
    Sum up the values of these properties and include them on the new row.

    .PARAMETER KeyJoin
    Objects are grouped as though their values were strings; join them with this value when making the key for each group.

    .EXAMPLE
    Get-Process |
        Select-Object Name, WorkingSet |
        Join-GroupHeaderRow Name { @{Name="$($input[0].Name)-Total"} } -Subtotal WorkingSet -AsFooter -SkipSingles

    .EXAMPLE
    Get-ChildItem C:\Windows -File |
        Select-Object Name, Extension, Length, Count |
        Join-GroupHeaderRow Extension {
            [pscustomobject]@{
                Name = "[ Average ]"
                Length = ($input.Length | Measure-Object -Average).Average
                Count = $input.Count
            }
        }
    #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0, Mandatory=$true)] [string[]] $Property,
        [Parameter(Position=1)] [scriptblock] $ObjectScript,
        [Parameter()] [switch] $AsFooter,
        [Parameter()] [switch] $SkipSingles,
        [Parameter()] [hashtable] $Set,
        [Parameter()] [string[]] $KeepFirst,
        [Parameter()] [string[]] $Subtotal,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $inputObjectList = [System.Collections.Generic.List[object]]::new()
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
    }
    End
    {
        $firstPropertyDict = @{}
        $sumPropertyDict = @{}
        foreach ($p in $Property) { $firstPropertyDict[$p] = $true }
        foreach ($p in $KeepFirst) { $firstPropertyDict[$p] = $true }
        foreach ($p in $Subtotal) { $sumPropertyDict[$p] = $true }
        $groupDict = $inputObjectList | ConvertTo-Dictionary -Ordered -Keys $Property -KeyJoin $KeyJoin
        foreach ($pair in $groupDict.GetEnumerator())
        {
            if ($SkipSingles -and $pair.Value.Count -eq 1)
            {
                $pair.Value
                continue
            }

            $firstObject = $pair.Value[0]
            $propertyList = $firstObject.PSObject.Properties.Name
            $newObject = [ordered]@{}
            foreach ($p in $propertyList)
            {
                $newObject[$p] = if ($firstPropertyDict[$p]) { $firstObject.$p }
                elseif ($sumPropertyDict[$p]) { ($pair.Value | Measure-Object $p -Sum).Sum }
            }

            if ($Set)
            {
                foreach ($setPair in $Set.GetEnumerator())
                {
                    $newObject[$setPair.Key] = $setPair.Value
                }
            }

            if ($AsFooter) { $pair.Value }

            if ($ObjectScript)
            {
                $variableList = [System.Collections.Generic.List[PSVariable]]::new()
                $variableList.Add([PSVariable]::new('input', $pair.Value))
                $result = [pscustomobject]$ObjectScript.InvokeWithContext($null, $variableList, $null)[0]

                foreach ($psProperty in $result.PSObject.Properties)
                {
                    $newObject[$psProperty.Name] = $psProperty.Value
                }
            }

            [pscustomobject]$newObject

            if (!$AsFooter) { $pair.Value }
        }
    }
}

Function Join-List
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string[]] $InputKeys,
        [Parameter(Position=1)] [object[]] $JoinData,
        [Parameter(Position=2)] [string[]] $JoinKeys,
        [Parameter()] [switch] $MatchesOnly,
        [Parameter()] [switch] $FirstRightOnly,
        [Parameter()] [switch] $IncludeUnmatchedRight,
        [Parameter()] [object[]] $KeepProperty,
        [Parameter()] [ValidateSet('Never', 'Always', 'IfNullOrEmpty', 'IfNewValueNotNullOrEmpty')] [string] $Overwrite = 'Never',
        [Parameter()] [switch] $OverwriteAll,
        [Parameter()] [switch] $OverwriteNull,
        [Parameter()] [string] $KeyJoin = '|',
        [Parameter()] [System.Collections.IDictionary] $SetOnMatched,
        [Parameter()] [System.Collections.IDictionary] $SetOnUnmatched
    )
    Begin
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }
        $usedKeys = @{}
        $overwriteMode = if ($OverwriteAll) { 'Always' } elseif ($OverwriteNull) { 'IfNullOrEmpty' } else { $Overwrite }
        
        $hasKeepProperty = $false
        if ($PSBoundParameters.ContainsKey('KeepProperty'))
        {
            $hasKeepProperty = $true
            $keepPropertyDict = [ordered]@{}
            foreach ($prop in $KeepProperty)
            {
                if ($prop -is [string]) { $keepPropertyDict[$prop] = $prop }
                elseif ($prop -is [hashtable])
                {
                    foreach ($pair in $prop.GetEnumerator())
                    {
                        $keepPropertyDict[$pair.Key] = $pair.Value
                    }
                }
                else
                {
                    throw "KeepProperty must contain strings or hashtables."
                }
            }
        }

        $hasSetProperty = $false
        if ($SetOnMatched -or $SetOnUnmatched)
        {
            $hasSetProperty = $true
            $setPropertyHash = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::CurrentCultureIgnoreCase)

            # What properties need to always be set (whether they're in one or both)
            if ($SetOnMatched) { foreach ($pair in $SetOnMatched.GetEnumerator()) { [void]$setPropertyHash.Add($pair.Key) } }
            if ($SetOnUnmatched) { foreach ($pair in $SetOnUnmatched.GetEnumerator()) { [void]$setPropertyHash.Add($pair.Key) } }

            # Need these to be non-null in case only Matched/Unmatched is set
            $setOnMatchedValues = if ($SetOnMatched) { $SetOnMatched } else { @{} }
            $setOnUnmatchedValues = if ($SetOnUnmatched) { $SetOnUnmatched } else { @{} }
        }

        if (!$JoinKeys) { $JoinKeys = $InputKeys }
        $joinDict = [ordered]@{}
        foreach ($joinObject in $JoinData)
        {
            $keyValue = $(foreach ($joinKey in $JoinKeys) { $joinObject.$joinKey }) -join $KeyJoin
            if (!$joinDict.Contains($keyValue))
            {
                $joinDict[$keyValue] = [System.Collections.Generic.List[object]]::new()
            }
            $joinDict[$keyValue].Add($joinObject)
        }

        $joinObjectPropertyList = $joinObject.PSObject.Properties |
            Where-Object Name -NotIn $JoinKeys |
            Select-Object -ExpandProperty Name
    }
    Process
    {
        if (!$InputObject) { return }

        $keyValue = $(foreach ($inputKey in $InputKeys) { $InputObject.$inputKey }) -join $KeyJoin
        $joinObject = $joinDict[$keyValue]

        if (!$joinObject)
        {
            if ($MatchesOnly) { return }
            $newObject = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties)
            {
                $newObject[$property.Name] = $property.Value
            }
            foreach ($propertyName in $joinObjectPropertyList)
            {
                if ($propertyName -in $JoinKeys) { continue }
                if ($hasKeepProperty)
                {
                    if (!$keepPropertyDict.Contains($propertyName)) { continue }
                    $propertyName = $keepPropertyDict[$propertyName]
                }
                $newObject[$propertyName] = $null
            }

            if ($hasSetProperty)
            {
                foreach ($propertyName in $setPropertyHash.GetEnumerator())
                {
                    $newObject[$propertyName] = $setOnUnmatchedValues[$propertyName]
                }
            }

            [pscustomobject]$newObject
            return
        }

        $usedKeys[$keyValue] = $true
        foreach ($joinObjectCopy in $joinObject)
        {
            $newObject = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties)
            {
                $newObject[$property.Name] = $property.Value
            }
            foreach ($property in $joinObjectCopy.PSObject.Properties)
            {
                if ($property.Name -in $JoinKeys) { continue }
                
                $newName = $property.Name
                if ($hasKeepProperty)
                {
                    if (!$keepPropertyDict.Contains($property.Name)) { continue }
                    $newName = $keepPropertyDict[$property.Name]
                }

                if ($overwriteMode -ne 'Always' -and $newObject.Contains($newName))
                {
                    if ($overwriteMode -eq 'Never') { continue }
                    if ($overwriteMode -eq 'IfNullOrEmpty' -and ![String]::IsNullOrEmpty($newObject[$newName])) { continue }
                    if ($overwriteMode -eq 'IfNewValueNotNullOrEmpty' -and [String]::IsNullOrEmpty($property.Value)) { continue }
                }

                $newObject[$newName] = $property.Value
            }

            if ($hasSetProperty)
            {
                foreach ($propertyName in $setPropertyHash.GetEnumerator())
                {
                    $newObject[$propertyName] = $setOnMatchedValues[$propertyName]
                }
            }

            [pscustomobject]$newObject
            if ($FirstRightOnly) { break }
        }
    }
    End
    {
        if (!$IncludeUnmatchedRight) { return }
        $inputPropertyList = $InputObject.PSObject.Properties.Name
        foreach ($joinKeyValue in $joinDict.GetEnumerator())
        {
            if ($usedKeys[$joinKeyValue.Key]) { continue }
            foreach ($joinObjectCopy in $joinKeyValue.Value)
            {
                $newObject = [ordered]@{}
                foreach ($inputProperty in $inputPropertyList)
                {
                    $newObject[$inputProperty] = $null
                }
                for ($i = 0; $i -lt $JoinKeys.Count; $i++)
                {
                    $newObject[$InputKeys[$i]] = $joinObjectCopy.($JoinKeys[$i])
                }
                foreach ($joinProperty in $joinObjectCopy.PSObject.Properties)
                {
                    $propertyName = $joinProperty.Name
                    if ($propertyName -in $JoinKeys) { continue }

                    if ($hasKeepProperty)
                    {
                        if (!$keepPropertyDict.Contains($propertyName)) { continue }
                        $propertyName = $keepPropertyDict[$propertyName]
                    }

                    if ($overwriteMode -eq 'Never' -and $newObject.Contains($propertyName)) { continue }

                    $newObject[$propertyName] = $joinProperty.Value
                }

                if ($hasSetProperty)
                {
                    foreach ($propertyName in $setPropertyHash.GetEnumerator())
                    {
                        $newObject[$propertyName] = $setOnUnmatchedValues[$propertyName]
                    }
                }

                [pscustomobject]$newObject
                if ($FirstRightOnly) { break }
            }
        }
    }
}

Function Join-Index
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string] $IndexProperty = 'Index',
        [Parameter()] [int] $Start = 0
    )
    Begin
    {
        $index = $Start
    }
    Process
    {
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, @($IndexProperty))
        $newInputObject.$IndexProperty = $index
        $newInputObject
        $index += 1
    }
}

Function Join-MissingSetCounts
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0,Mandatory=$true)] [string] $Set1Property,
        [Parameter(Position=1,Mandatory=$true)] [string[]] $Set1Values,
        [Parameter()] [ValidateSet('SortAndInsert', 'SortAndFilter')] [string] $Mode = 'SortAndInsert',
        [Parameter()] [string] $Set2Property,
        [Parameter()] [string[]] $Set2Values,
        [Parameter()] [string] $CountProperty = 'Count',
        [Parameter()] [object] $CountValue = 0,
        [Parameter()] [string] $PercentageProperty,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
    }
    End
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }
        if ($Set2Property -or $Set2Values -and (-not $Set2Property -or -not $Set2Values))
        {
            throw "Set2Property and Set2Values must be specified together."
        }

        $dictionary = if ($Set2Property) { $inputObjectList | ConvertTo-Dictionary $Set1Property, $Set2Property -KeyJoin $KeyJoin }
        else { $inputObjectList | ConvertTo-Dictionary $Set1Property }

        $propertyList = if ($inputObjectList.Count) { $inputObjectList[0].PSObject.Properties.Name }
        if (!$propertyList) { $propertyList = @($Set1Property; $Set2Property; $CountProperty; $PercentageProperty) | Where-Object Length }

        $template = [ordered]@{}
        foreach ($property in $propertyList) { $template.$property = $null }

        if ($Mode -eq 'SortAndInsert') { $Set1Values = @($Set1Values; $inputObjectList | Select-Object -ExpandProperty $Set1Property) | Select-Object -Unique }
        if ($Mode -eq 'SortAndInsert' -and $Set2Values) { $Set2Values = @($Set2Values; $inputObjectList | Select-Object -ExpandProperty $Set2Property) | Select-Object -Unique }

        if (!$Set2Property) { $Set2Values = '' }

        $usedKeyDict = @{}
        foreach ($set1Value in $Set1Values)
        {
            foreach ($set2Value in $Set2Values)
            {
                if (!$Set2Property) { $set2Value = @() }
                $key = @($set1Value; $set2Value) -join $KeyJoin
                $usedKeyDict[$key] = $true
                $existingObject = $dictionary[$key]
                if ($existingObject) { $existingObject; continue }

                $result = [pscustomobject]$template
                $result.$Set1Property = $set1Value
                if ($Set2Property) { $result.$Set2Property = $set2Value }
                $result.$CountProperty = $CountValue
                try { $result.$PercentageProperty = "0%" } catch { }
                $result
            }
        }
    }
}

Function Join-Percentage
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string] $CountProperty = 'Count',
        [Parameter()] [string] $PercentageProperty = 'Percentage',
        [Parameter()] [int] $DecimalPlaces = 0
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
    }
    End
    {
        $total = $inputObjectList | Measure-Object -Sum $CountProperty | ForEach-Object Sum
        foreach ($inputObject in $inputObjectList)
        {
            $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, @($PercentageProperty))
            $percentage = [Math]::Round($newInputObject.$CountProperty * 100 / $total, $DecimalPlaces)
            $newInputObject.$PercentageProperty = "$percentage%"
            $newInputObject
        }
    }
}

Function Join-PropertyMultiValue
{
    <#
    .SYNOPSIS
    Adds one or more properties from a hashtable, ordered dictionary, scriptblock or child object of the input object.

    .PARAMETER InputObject
    The objects to add properties to.

    .PARAMETER Values
    A hashtable/ordered dictionary of properties to add, or a foreach scriptblock producing objects/hashtables with properties to add, or the name of a child object with properties to add.
    Arrays return multiple new objects.

    .PARAMETER KeepProperty
    A specific list of properties set/produced from the Values parameter to add; and ensure these properties are always on the resulting objects.

    .PARAMETER KeepInputProperty
    Keep only these properties on the input objects.

    .PARAMETER ExcludeProperty
    Exclude these properties from the resulting objects (whether they came from the source or were just added).

    .PARAMETER NoEmptyResults
    Don't return any input objects if the scriptblock results are empty.

    .EXAMPLE
    Get-Process |
        Select-Object Name |
        Join-PropertyMultiValue @{Type='Process'; State='Running'}

    .EXAMPLE
    Get-Service |
        Join-PropertyMultiValue -KeepInputProperty Name -KeepProperty DependentName {
            foreach ($d in $_.DependentServices)
            {
                [pscustomobject]@{
                    DependentName = $d.Name
                }
            }
        }

    .EXAMPLE
    Get-ChildItem C:\Windows -File |
        Select-Object Name, VersionInfo |
        Join-PropertyMultiValue VersionInfo -KeepProperty FileVersion, ProductVersion -ExcludeProperty VersionInfo
    #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [object] $Values,
        [Parameter()] [string[]] $KeepProperty,
        [Parameter()] [string[]] $KeepInputProperty,
        [Parameter()] [string[]] $ExcludeProperty,
        [Parameter()] [switch] $NoEmptyResults
    )
    Begin
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }
        
        $isScript = $isDict = $isString = $false
        
        if ($Values -is [scriptblock]) { $isScript = $true }
        elseif ($Values -is [System.Collections.IDictionary]) { $isDict = $true }
        elseif ($Values -is [string]) { $isString = $true }
        else { throw "Values must be a scriptblock, child property name or hashtable/ordered dictionary." }
        
        $keepPropertyDict = @{}
        $hasKeepProperty = !!$KeepProperty
        if ($KeepProperty) { foreach ($p in $KeepProperty) { $keepPropertyDict[$p] = $true } }

        $hasKeepInputProperty = !!$KeepInputProperty

        $excludePropertyDict = @{}
        $hasExcludeProperty = !!$ExcludeProperty
        if ($ExcludeProperty) { foreach ($p in $ExcludeProperty) { $excludePropertyDict[$p] = $true } }

        if ($isDict -and $NoEmptyResults) { throw "NoEmptyResults can't be provided when Values is a dictionary." }
    }
    Process
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }

        $baseInputObject = $InputObject
        if ($hasKeepInputProperty)
        {
            $temp = [ordered]@{}
            foreach ($p in $KeepInputProperty)
            {
                $temp[$p] = $InputObject.$p
            }
            $baseInputObject = [pscustomobject]$temp
        }

        $newInputObjectList = if ($isDict)
        {
            $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($baseInputObject, $KeepProperty)
            foreach ($pair in $Values.GetEnumerator())
            {
                if ($hasKeepProperty -and !$keepPropertyDict[$pair.Key]) { continue }
                $newInputObject.PSObject.Properties.Add([psnoteproperty]::new($pair.Key, $pair.Value))
            }
            $newInputObject
        }
        else
        {
            if ($isString)
            {
                $newValueList = foreach ($item in $InputObject."$Values") { if ($item) { [pscustomobject]$item } }
            }
            elseif ($isScript)
            {
                $varList = [System.Collections.Generic.List[PSVariable]]::new()
                $varList.Add([PSVariable]::new("_", $InputObject))
                $newValueList = foreach ($item in $Values.InvokeWithContext($null, $varList, $null)) { [pscustomobject]$item }
            }
            else
            {
                throw "Unhandled type."
            }

            foreach ($newValue in $newValueList)
            {
                $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($baseInputObject, $KeepProperty)
                foreach ($prop in $newValue.PSObject.Properties)
                {
                    if ($hasKeepProperty -and !$keepPropertyDict[$prop.Name]) { continue }
                    $newInputObject.PSObject.Properties.Add([psnoteproperty]::new($prop.Name, $prop.Value))
                }
                $newInputObject
            }

            if (!$NoEmptyResults.IsPresent -and !@($newValueList).Count)
            {
                [Rhodium.Data.DataHelpers]::CloneObject($baseInputObject, $KeepProperty)
            }
        }

        foreach ($newInputObject in $newInputObjectList)
        {
            if ($hasExcludeProperty)
            {
                foreach ($prop in @($newInputObject.PSObject.Properties))
                {
                    if ($excludePropertyDict[$prop.Name]) { $newInputObject.PSObject.Properties.Remove($prop.Name) }
                }
            }
            $newInputObject
        }
    }
}

Function Join-PropertySetComparison
{
    <#
    .SYNOPSIS
    Compares two properties on an input object that contain arrays of values for differences.

    .EXAMPLE
    $sampleData = @(
        [pscustomobject]@{Label='Sample 1'; Before='A', 'B', 'C'; After='A', 'B', 'C'}
        [pscustomobject]@{Label='Sample 2'; Before='A', 'B', 'C'; After='A', 'C'}
        [pscustomobject]@{Label='Sample 3'; Before='A', 'C'; After='A', 'B', 'C'}
        [pscustomobject]@{Label='Sample 4'; Before='A', 'B'; After='B', 'C'}
    )

    $sampleData |
        Join-PropertySetComparison -BaseProperty Before -ComparisonProperty After -ResultProperty Result -SameDifferentMissingExtraValues '==', '!=', '<', '>'

    .EXAMPLE
    1..10 |
        ForEach-Object {
            [pscustomobject]@{Letters = 'A', 'B', 'C', 'D', 'E' | Get-Random -Count 3 }
        } |
        Join-PropertySetComparison Letters -ComparisonValues 'A', 'B', 'C' -MissingProperty LettersNotInABC -ExtraProperty ABCNotInLetters
    #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string] $BaseProperty,
        [Parameter(Mandatory=$true,ParameterSetName='ComparisonProperty')] [string] $ComparisonProperty,
        [Parameter(Mandatory=$true,ParameterSetName='ComparisonValues')] [object[]] $ComparisonValues,
        [Parameter()] [string] $ResultProperty,
        [Parameter()] [string] $MissingProperty,
        [Parameter()] [string] $ExtraProperty,
        [Parameter()] [object[]] $SameDifferentMissingExtraValues
    )
    Begin
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }

        if ($SameDifferentMissingExtraValues.Count -notin 0,4) { throw "SameDifferentMissingExtraValues must have exactly 4 values (Same, Different, Missing Extra)." }
        if ($ResultProperty -xor $SameDifferentMissingExtraValues.Count) { throw "ResultProperty and SameDifferentMissingExtraValues must be specified together." }

        $newProperties = @(
            if ($ResultProperty) { $ResultProperty }
            if ($MissingProperty) { $MissingProperty }
            if ($ExtraProperty) { $ExtraProperty }
        )

        if (!$newProperties) { throw "At least one of ResultProperty, MissingProperty and/or ExtraProperty must be specified." }

        $getMissing = $SameDifferentMissingExtraValues.Count -or $MissingProperty
        $getExtra = $SameDifferentMissingExtraValues.Count -or $ExtraProperty
    }
    Process
    {
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, @($newProperties))

        $compareValueList = if ($PSCmdlet.ParameterSetName -eq 'ComparisonValues') { $ComparisonValues }
            else { $InputObject.$ComparisonProperty }

        $missingList = if ($getMissing)
        {
            $compareDict = @{}
            foreach ($value in $compareValueList)
            {
                if ([String]::IsNullOrEmpty($value)) { continue }
                $compareDict[$value] = $true
            }

            foreach ($value in $InputObject.$BaseProperty)
            {
                if ([String]::IsNullOrEmpty($value)) { continue }
                if (!$compareDict.ContainsKey($value)) { $value }
            }
        }

        $extraList = if ($getExtra)
        {
            $baseDict = @{}
            foreach ($value in $InputObject.$BaseProperty)
            {
                if ([String]::IsNullOrEmpty($value)) { continue }
                $baseDict[$value] = $true
            }

            foreach ($value in $compareValueList)
            {
                if ([String]::IsNullOrEmpty($value)) { continue }
                if (!$baseDict.ContainsKey($value)) { $value }
            }
        }

        if ($ResultProperty)
        {
            $m = @($missingList).Count -ne 0
            $e = @($extraList).Count -ne 0

            $newInputObject.$ResultProperty = if (!$m -and !$e) { $SameDifferentMissingExtraValues[0] }
                elseif ($m -and $e) { $SameDifferentMissingExtraValues[1] }
                elseif ($m) { $SameDifferentMissingExtraValues[2] }
                elseif ($e) { $SameDifferentMissingExtraValues[3] }
        }

        if ($MissingProperty) { $newInputObject.$MissingProperty = $missingList }
        if ($ExtraProperty) { $newInputObject.$ExtraProperty = $extraList }

        $newInputObject
    }
}

Function Join-TotalRow
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string] $CountProperty = 'Count',
        [Parameter()] [string] $PercentageProperty = 'Percentage',
        [Parameter()] [string] $TotalLabel = 'Total'
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
        $InputObject
    }
    End
    {
        $total = $inputObjectList | Measure-Object -Sum $CountProperty | ForEach-Object Sum
        $totalRecord = 1 | Select-Object @($InputObject.PSObject.Properties.Name)
        @($totalRecord.PSObject.Properties)[0].Value = $TotalLabel
        $totalRecord.$CountProperty = $total
        if ($InputObject.PSObject.Properties[$PercentageProperty])
        {
            $totalRecord.$PercentageProperty = "100%"
        }
        $totalRecord
    }
}

Function Join-UniqueIndex
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string[]] $Property,
        [Parameter()] [string] $IndexProperty = 'UniqueIndex',
        [Parameter()] [int] $StartAt = 0,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
    }
    End
    {
        $keyDict = @{}
        foreach ($object in $inputObjectList)
        {
            $key = $(foreach ($p in $Property) { $object.$p }) -join $KeyJoin
            $index = $keyDict[$key]
            if ($index -eq $null)
            {
                $index = $StartAt
                $keyDict[$key] = $StartAt
                $StartAt += 1
            }
            $newObject = [Rhodium.Data.DataHelpers]::CloneObject($object, @($IndexProperty))
            $newObject.$IndexProperty = $index
            $newObject
        }
    }
}

Function Expand-Normalized
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0, Mandatory=$true)] [string] $Property,
        [Parameter()] [string] $SplitOn,
        [Parameter()] [switch] $IsObject
    )
    Process
    {
        $valueList = $InputObject.$Property
        if ($SplitOn) { $valueList = $valueList -split $SplitOn }
        foreach ($value in $valueList)
        {
            if ($IsObject)
            {
                $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property)
                foreach ($psProperty in $value.PSObject.Properties)
                {
                    $newInputObject.PSObject.Properties.Add($psProperty)
                }
                $newInputObject.PSObject.Properties.Remove($Property)
            }
            else
            {
                $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property)
                $newInputObject.$Property = $value
            }
            $newInputObject
            $returned = $true
        }
        if (!$returned)
        {
            [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property)
        }
    }
}

Function Expand-Property
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter()] [string[]] $KeyProperty,
        [Parameter(Position=0)] [string] $NameProperty = 'Name',
        [Parameter(Position=1)] [string] $ValueProperty = 'Value'
    )
    Process
    {
        if (!$InputObject) { return }
        foreach ($property in $InputObject.PSObject.Properties)
        {
            $result = [ordered]@{}
            foreach ($propertyName in $KeyProperty)
            {
                $result[$propertyName] = $InputObject.$propertyName
            }
            if ($property.Name -in $KeyProperty) { continue }
            $result[$NameProperty] = $property.Name
            $result[$ValueProperty] = $property.Value
            [pscustomobject]$result
        }
    }
}

if (!$Script:LoadedDataSharp) {
Function Rename-Property
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Hashtable')] [Hashtable] $Rename,
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='String')] [string] $From,
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='String')] [string] $To,
        [Parameter(ValueFromRemainingArguments = $true, ParameterSetName='String')] [string[]] $OtherFromToPairs
    )
    Begin
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }
        if ($Rename)
        {
            $renameDict = $Rename
            return
        }
        $renameDict = @{$From=$To}
        if ($OtherFromToPairs)
        {
            $actualOtherPairs = $OtherFromToPairs | Where-Object { $_ -ne '+' }
            if (@($actualOtherPairs).Count % 2 -ne 0) { throw "There must be an even number of additional pairs if provided." }
            for ($i = 0; $i -lt $actualOtherPairs.Count; $i += 2)
            {
                $renameDict[$actualOtherPairs[$i]] = $actualOtherPairs[$i+1]
            }
        }

    }
    Process
    {
        if (!$InputObject) { return }
        $newObject = [PSObject]::new()
        foreach ($property in $InputObject.PSObject.Properties)
        {
            if ($renameDict.Contains($property.Name))
            {
                $newObject.PSObject.Properties.Add([PSNoteProperty]::new($renameDict[$property.Name], $property.Value))
            }
            else
            {
                $newObject.PSObject.Properties.Add($property)
            }
        }
        $newObject
    }
}
}

Function ConvertTo-Dictionary
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string[]] $Keys,
        [Parameter()] [string] $Value,
        [Parameter()] [string] $KeyJoin = '|',
        [Parameter()] [switch] $Ordered
    )
    Begin
    {
        if ($Ordered) { $dict = [ordered]@{} }
        else { $dict = @{} }
    }
    Process
    {
        $keyValue = $(foreach ($key in $Keys) { $InputObject.$key }) -join $KeyJoin
        if ($Value)
        {
            if ($dict.Contains($keyValue))
            {
                Write-Warning "Dictionary already contains key '$keyValue'."
                return
            }
            $dict[$keyValue] = $InputObject.$Value
        }
        else
        {
            if (!$dict.Contains($keyValue))
            {
                $dict[$keyValue] = New-Object System.Collections.Generic.List[object]
            }
            $dict[$keyValue].Add($InputObject)
        }
    }
    End
    {
        $dict
    }
}

Function Convert-DateTimeZone
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Position=0, Mandatory=$true, ParameterSetName='Value')] [DateTime] $DateTime,
        [Parameter(ValueFromPipeline=$true, ParameterSetName='Pipeline')] [object] $InputObject,
        [Parameter(Position=0, Mandatory=$true, ParameterSetName='Pipeline')] [string[]] $DateTimeProperty,
        [Parameter(ParameterSetName='Pipeline')] [string] $FromTimeZoneProperty,
        [Parameter()] [string] $FromTimeZone,
        [Parameter()] [switch] $FromLocal,
        [Parameter()] [switch] $FromUtc,
        [Parameter(ParameterSetName='Pipeline')] [string] $ToTimeZoneProperty,
        [Parameter()] [string] $ToTimeZone,
        [Parameter()] [switch] $ToLocal,
        [Parameter()] [switch] $ToUtc,
        [Parameter()] [string] $Format,
        [Parameter()] [ValidateSet('Short', 'Long')] [string] $AppendTimeZone
    )
    Begin
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }

        if ($AppendTimeZone -and -not $Format) { throw "Format must be specified with AppendTimeZone." }

        $fromTimeZoneMode = $null
        $toTimeZoneMode = $null
        $fromTimeZoneValue = $null
        $toTimeZoneValue = $null

        $fromCount = 0
        $toCount = 0

        if ($FromTimeZoneProperty) { $fromCount += 1; $fromTimeZoneMode = 'Property' }
        if ($FromTimeZone)
        {
            $fromCount += 1
            $fromTimeZoneMode = 'Specified'
            $fromTimeZoneValue = [System.TimeZoneInfo]::FindSystemTimeZoneById($FromTimeZone)
        }
        if ($FromLocal) { $fromCount += 1; $fromTimeZoneMode = 'Local' }
        if ($FromUtc) { $fromCount += 1; $fromTimeZoneMode = 'Utc' }

        if ($ToTimeZoneProperty) { $toCount += 1; $toTimeZoneMode = 'Property' }
        if ($ToTimeZone)
        {
            $toCount += 1
            $toTimeZoneMode = 'Specified'
            $toTimeZoneValue = [System.TimeZoneInfo]::FindSystemTimeZoneById($ToTimeZone)
        }
        if ($ToLocal) { $toCount += 1; $toTimeZoneMode = 'Local'; $toTimeZoneValue = [System.TimeZoneInfo]::Local }
        if ($ToUtc) { $toCount += 1; $toTimeZoneMode = 'Utc'; $toTimeZoneValue = [System.TimeZoneInfo]::Utc }

        if ($fromCount -ne 1) { throw "Exactly one From parameter must be specified." }
        if ($toCount -ne 1) { throw "Exactly one To parameter must be specified." }

        $dateTimeList = [System.Collections.Generic.List[Nullable[DateTime]]]::new()
        $newDateTimeList = [System.Collections.Generic.List[Nullable[DateTime]]]::new()

        if ($PSCmdlet.ParameterSetName -eq 'Value') { $dateArrayLength = 1 }
        else { $dateArrayLength = $DateTimeProperty.Count }

        $dateArray = [Array]::CreateInstance([Nullable[DateTime]], $dateArrayLength)
    }
    Process
    {
        if ($PSCmdlet.ParameterSetName -eq 'Value') { $dateArray[0] = $DateTime }
        else
        {
            for ($i = 0; $i -lt $dateArrayLength; $i++)
            {
                $value = $InputObject.($DateTimeProperty[$i])
                try
                {
                    $dateArray[$i] = [datetime]$value
                }
                catch
                {
                    if (![string]::IsNullOrEmpty($value)) { Write-Warning "'$value' could not be converted to a DateTime" }
                    $dateArray[$i] = $null
                }
            }
        }

        if ($fromTimeZoneMode -eq 'Property')
        {
            $fromTimeZoneValue = [System.TimeZoneInfo]::FindSystemTimeZoneById($InputObject.$FromTimeZoneProperty)
        }
        if ($toTimeZoneMode -eq 'Property')
        {
            $toTimeZoneValue = [System.TimeZoneInfo]::FindSystemTimeZoneById($InputObject.$toTimeZoneProperty)
        }

        for ($i = 0; $i -lt $dateArrayLength; $i++)
        {
            $originalDateTime = $dateArray[$i]
            if ($originalDateTime -eq $null) { continue }

            if ($fromTimeZoneMode -eq 'Utc') { $dateTimeUtc = $originalDateTime }
            elseif ($fromTimeZoneMode -eq 'Local') { $dateTimeUtc = $originalDateTime.ToUniversalTime() }
            else { $dateTimeUtc = [TimeZoneInfo]::ConvertTimeToUtc($originalDateTime, $fromTimeZoneValue) }

            if ($toTimeZoneMode -eq 'Utc') { $dateArray[$i] = $dateTimeUtc }
            elseif ($toTimeZoneMode -eq 'Local') { $dateArray[$i] = $dateTimeUtc.ToLocalTime() }
            else { $dateArray[$i] = [TimeZoneInfo]::ConvertTimeFromUtc($dateTimeUtc, $toTimeZoneValue) }
        }

        if ($PSCmdlet.ParameterSetName -eq 'Value') { return $dateArray[0] }

        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $DateTimeProperty)
        for ($i = 0; $i -lt $dateArrayLength; $i++)
        {
            $newValue = $dateArray[$i]
            if ($Format -and ![String]::IsNullOrWhiteSpace($newValue))
            {
                $timeZoneLabel = if ($AppendTimeZone)
                {
                    $st = $toTimeZoneValue.StandardName
                    $dst = $toTimeZoneValue.DaylightName
                    if ($AppendTimeZone -eq 'Short')
                    {
                        $st = $(foreach ($c in $st -split ' ') { $c.Substring(0,1) }) -join ''
                        $dst = $(foreach ($c in $dst -split ' ') { $c.Substring(0,1) }) -join ''
                    }
                    if ($toTimeZoneValue.IsDaylightSavingTime($newValue)) { " $dst" } else { " $st" }
                }

                $newValue = "$($newValue.ToString($Format))$timeZoneLabel"
            }
            $newInputObject.($DateTimeProperty[$i]) = $newValue
        }

        $newInputObject
    }
}

Function Convert-PropertyEmptyValue
{
    <#
    .SYNOPSIS
    Converts empty values ($null, '', DBNull, whitespace) on objects to another value for cleaning up data.

    .PARAMETER InputObject
    The objects to convert empty properties on.

    .PARAMETER Property
    Specific properties to check. All properties are checked if not specified.

    .PARAMETER ToNull
    Convert empty values to $null.

    .PARAMETER ToEmptyString
    Convert empty values to an empty string.

    .PARAMETER ToValue
    Convert empty values to a specific value.

    .EXAMPLE
    Import-Csv ~\Path\To\File.csv | # Empty cells will default to ''
        Convert-PropertyEmptyValue -ToNull

    .EXAMPLE
    Get-ChildItem C:\Windows |
        Select-Object Name, Length |
        Convert-PropertyEmptyValue Length -ToValue 'N/A'

    .EXAMPLE
    Get-Process |
        Select-Object Id, Name, ProductVersion, MainWindowTitle |
        Convert-PropertyEmptyValue -ToValue '-'
    
    #>
    [CmdletBinding(PositionalBinding=$false,DefaultParameterSetName='ToNull')]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string[]] $Property,
        [Parameter(ParameterSetName='ToNull',Mandatory=$true)] [switch] $ToNull,
        [Parameter(ParameterSetName='ToEmptyString',Mandatory=$true)] [switch] $ToEmptyString,
        [Parameter(ParameterSetName='ToValue')] [object] $ToValue
    )
    Begin
    {
        $hasProperty = !!$Property
        $propertyHash = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::CurrentCultureIgnoreCase)
        foreach ($p in $Property) { [void]$propertyHash.Add($p) }
        $newValue = if ($ToEmptyString.IsPresent) { "" }
        elseif ($ToNull.IsPresent) { $null }
        elseif ($PSCmdlet.ParameterSetName -eq 'ToValue') { $ToValue }
    }
    Process
    {
        if (!$InputObject) { return }
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property)
        foreach ($prop in $newInputObject.PSObject.Properties)
        {
            if ($hasProperty -and !$propertyHash.Contains($prop.Name)) { continue }
            if ([String]::IsNullOrWhiteSpace($prop.Value) -or [System.DBNull]::Value.Equals($prop.Value))
            {
                $prop.Value = $newValue
            }
        }
        $newInputObject
    }
}

Function Select-DuplicatePropertyValue
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string[]] $Property,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $existingDict = @{}
    }
    Process
    {
        $keyValue = $(foreach ($key in $Property) { $InputObject.$key }) -join $KeyJoin
        if ($existingDict.Contains($keyValue))
        {
            if ($existingDict[$keyValue] -ne $null)
            {
                $existingDict[$keyValue]
                $existingDict[$keyValue] = $null
            }
            $InputObject
        }
        else
        {
            $existingDict[$keyValue] = $InputObject
        }
    }
}

Function Select-Excluding
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string[]] $InputKeys,
        [Parameter(Position=1)] [object[]] $CompareData,
        [Parameter(Position=2)] [string[]] $CompareKeys,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $noData = !@($CompareData).Count
        $compareDict = @{}
        if (!$CompareKeys) { $CompareKeys = $InputKeys }
        foreach ($compareObject in $CompareData)
        {
            $keyValue = $(foreach ($key in $CompareKeys) { $compareObject.$key }) -join $KeyJoin
            $compareDict[$keyValue] = $true
        }
    }
    Process
    {
        if ($noData) { return $InputObject }
        $keyValue = $(foreach ($key in $InputKeys) { $InputObject.$key }) -join $KeyJoin
        if (!$compareDict[$keyValue]) { $InputObject }
    }
}

Function Select-Including
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string[]] $InputKeys,
        [Parameter(Position=1)] [object[]] $CompareData,
        [Parameter(Position=2)] [string[]] $CompareKeys,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $noData = !@($CompareData).Count
        $compareDict = @{}
        if (!$CompareKeys) { $CompareKeys = $InputKeys }
        foreach ($compareObject in $CompareData)
        {
            $keyValue = $(foreach ($key in $CompareKeys) { $compareObject.$key }) -join $KeyJoin
            $compareDict[$keyValue] = $true
        }
    }
    Process
    {
        if ($noData) { return }
        $keyValue = $(foreach ($key in $InputKeys) { $InputObject.$key }) -join $KeyJoin
        if ($compareDict[$keyValue]) { $InputObject }
    }
}

Function Invoke-PipelineChunks
{
    <#
    .SYNOPSIS
    Breaks pipeline input objects into chunks of a specific size and executes a script block for each chunk.

    .PARAMETER InputObject
    The objects to break into chunks. Can be passed as a named parameter as well as via pipeline input.

    .PARAMETER ChunkSize
    The size of the chunks to break objects into.

    .PARAMETER SingleChunk
    Collect the entire pipeline into a single chunk. Useful for self joins.

    .PARAMETER ScriptBlock
    The scriptblock to execute for each chunk. Use the $input variable to access the objects.

    .EXAMPLE
    Get-Content ServerList.txt | Invoke-PipelineChunks 25 { Invoke-Command $input { $env:ComputerName } }

    .EXAMPLE
    Invoke-PipelineChunks -InputObject (1..10) -ChunkSize 7 -ScriptBlock { $input -join '+' }
    #>
    [CmdletBinding(PositionalBinding=$false,DefaultParameterSetName='ChunkSize')]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object[]] $InputObject,
        [Parameter(Position=0,Mandatory=$true,ParameterSetName='ChunkSize')] [int] $ChunkSize,
        [Parameter(Position=1,Mandatory=$true,ParameterSetName='ChunkSize')]
            [Parameter(Position=0,Mandatory=$true,ParameterSetName='SingleChunk')] [scriptblock] $ScriptBlock,
        [Parameter(ParameterSetName='SingleChunk')] [switch] $SingleChunk
    )
    Begin
    {
        $private:chunkList = [System.Collections.Generic.LinkedList[object]]::new()
        $private:singleMode = $PSCmdlet.ParameterSetName -eq 'SingleChunk'
    }
    Process
    {
        foreach ($inputObjectItem in $InputObject)
        {
            $private:chunkList.Add($inputObjectItem)
            if ($private:singleMode) { continue }
            if ($private:chunkList.Count -ge $ChunkSize)
            {
                $private:varList = [System.Collections.Generic.List[PSVariable]]::new()
                $private:varList.Add([PSVariable]::new('input', $private:chunkList))
                $ScriptBlock.InvokeWithContext($null, $private:varList, $null)
                $private:chunkList = [System.Collections.Generic.LinkedList[object]]::new()
            }
        }
    }
    End
    {
        if ($private:chunkList.Count)
        {
            $private:varList = [System.Collections.Generic.List[PSVariable]]::new()
            $private:varList.Add([PSVariable]::new('input', $private:chunkList))
            $ScriptBlock.InvokeWithContext($null, $private:varList, $null)
        }
    }
}

Function Invoke-PipelineThreading
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object[]] $InputObject,
        [Parameter(Position=0,Mandatory=$true)] [Alias('Process')] [scriptblock] $Script,
        [Parameter()] [int] $Threads = 10,
        [Parameter()] [int] $ChunkSize = 1,
        [Parameter()] [scriptblock] $StartupScript,
        [Parameter()] [string[]] $ImportVariables,
        [Parameter()] [switch] $ShowProgress
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        foreach ($inputObjectItem in $InputObject) { $inputObjectList.Add($inputObjectItem) }
    }
    End
    {
        $hashCode = $PSCmdlet.GetHashCode()
        $inputCount = $inputObjectList.Count
        if (!$inputCount) { return }
        $finalThreadCount = [Math]::Min([Math]::Ceiling($inputCount / $ChunkSize), $Threads)
        $threadList = @(for($i = 1; $i -le $finalThreadCount; $i++)
        {
            $thread = [ordered]@{}
            $thread.PowerShell = [PowerShell]::Create()
            $thread.Invocation = $null
            $thread.ReadyToProcess = $false
            foreach ($varName in $ImportVariables)
            {
                $var = $PSCmdlet.SessionState.PSVariable.Get($varName)
                $thread.PowerShell.Runspace.SessionStateProxy.SetVariable($var.Name, $var.Value)
            }
            if ($StartupScript) { $thread.Invocation = $thread.PowerShell.AddScript($StartupScript).BeginInvoke() }
            [pscustomobject]$thread
        })

        $index = 0
        $completedCount = 0

        while ($completedCount -lt $inputCount)
        {
            do
            {
                $readyThreads = $threadList.Where({-not $_.Invocation -or $_.Invocation.IsCompleted})
            }
            while (!$readyThreads)

            foreach ($thread in $readyThreads)
            {
                if ($thread.Invocation)
                {
                    $result = $thread.PowerShell.EndInvoke($thread.Invocation)
                    $result
                    $thread.Invocation = $null
                    if ($thread.ReadyToProcess) { $completedCount += $ChunkSize }
                }
                if ($index -ge $inputCount) { continue }
                if (!$thread.ReadyToProcess)
                {
                    $thread.PowerShell.Commands.Clear()
                    [void]$thread.PowerShell.AddScript($Script)
                    $thread.ReadyToProcess = $true
                }
                $incrementSize = [Math]::Min($ChunkSize, $inputCount - $index)
                $nextItems = $inputObjectList.GetRange($index, $incrementSize)
                $index += $incrementSize
                if ($nextItems.Count -eq 1)
                {
                    $thread.PowerShell.Runspace.SessionStateProxy.SetVariable('_', $nextItems[0])
                }
                else
                {
                    $thread.PowerShell.Runspace.SessionStateProxy.SetVariable('_', $nextItems)
                }
                $thread.Invocation = $thread.PowerShell.BeginInvoke()
            }

            if ($ShowProgress)
            {
                $progressRecord = New-Object System.Management.Automation.ProgressRecord $hashCode, "Threading", "Processing"
                $progressRecord.PercentComplete = 100 * $completedCount / $inputCount
                $PSCmdlet.WriteProgress($progressRecord)
            }
        }

        if ($ShowProgress)
        {
            $progressRecord = New-Object System.Management.Automation.ProgressRecord $hashCode, "Threading", "Completed"
            $progressRecord.RecordType = 'Completed'
            $PSCmdlet.WriteProgress($progressRecord)
        }
    }
}

Function Write-PipelineProgress
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string] $OperationProperty,
        [Parameter()] [string] $Activity = "Current Progress"
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
        $id = $PSCmdlet.GetHashCode()
        $progressRecord = New-Object System.Management.Automation.ProgressRecord $id, $Activity, "Collecting Input"
        $PSCmdlet.WriteProgress($progressRecord)
        
    }
    Process
    {
        $inputObjectList.Add($InputObject)
    }
    End
    {
        $count = $inputObjectList.Count
        for ($i = 0; $i -lt $count; $i++)
        {
            $object = $inputObjectList[$i]
            $object
            $operation = $null
            if ($OperationProperty) { $operation = $object.$OperationProperty }
            if ([String]::IsNullOrEmpty($operation)) { $operation = "$object" }
            $progressRecord = New-Object System.Management.Automation.ProgressRecord $id, $Activity, $operation
            $progressRecord.PercentComplete = $i * 100 / $count
            $PSCmdlet.WriteProgress($progressRecord)
        }

        $progressRecord = New-Object System.Management.Automation.ProgressRecord $id, $Activity, "Completed"
        $progressRecord.RecordType = 'Completed'
        $PSCmdlet.WriteProgress($progressRecord)
    }
}

Function Set-PropertyOrder
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string[]] $Begin,
        [Parameter()] [string[]] $End
    )
    Begin
    {
        $endDict = @{}
        foreach ($propertyName in $End) { $endDict[$propertyName] = $true }
    }
    Process
    {
        if (!$InputObject) { return }
        $newObject = [psobject]::new()
        $oldPropertyList = $InputObject.PSObject.Properties
        foreach ($propertyName in $Begin)
        {
            if ($oldPropertyList[$propertyName]) { $newObject.PSObject.Properties.Add($oldPropertyList[$propertyName]) }
        }
        foreach ($oldProperty in $oldPropertyList)
        {
            if ($endDict[$oldProperty.Name]) { continue }
            $newObject.PSObject.Properties.Add($oldProperty)
        }
        foreach ($propertyName in $End)
        {
            if ($oldPropertyList[$propertyName]) { $newObject.PSObject.Properties.Add($oldPropertyList[$propertyName]) }
        }
        $newObject
    }
}

Function Set-PropertyDateFloor
{
    <#
    .SYNOPSIS
    Rounds timestamps down to the nearest second, minute, hour, day, month or months to help with grouping for reports.

    .PARAMETER InputObject
    Objets with timestamps to round down.

    .PARAMETER Property
    DateTime properties to round down.

    .PARAMETER ToNewProperty
    Save the new value to a new property instead of overwriting the old property.

    .PARAMETER Format
    Convert the new value to this datetime ToString format after rounding.

    .PARAMETER Second
    Round down to the nearest X seconds.

    .PARAMETER Minute
    Round down to the nearest X minutes.

    .PARAMETER Hour
    Round down to the nearest X hours.

    .PARAMETER Day
    Round down to the timestamp date.

    .PARAMETER Month
    Round down to the timestamp month.

    .PARAMETER Months
    Round down to the nearest X months.

    .EXAMPLE
    Get-ChildItem C:\Windows |
        Select-Object Name, LastWriteTime |
        Set-PropertyDateFloor LastWriteTime -Month -Format 'yyyy-MM'

    .EXAMPLE
    Get-Process |
        Select-Object Name, StartTime |
        Set-PropertyDateFloor StartTime -ToNewProperty StartQuarterHour -Minute 15

    #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string[]] $Property,
        [Parameter()] [string[]] $ToNewProperty,
        [Parameter()] [string] $Format,
        [Parameter(ParameterSetName='Second')] [int] $Second,
        [Parameter(ParameterSetName='Minute')] [int] $Minute,
        [Parameter(ParameterSetName='Hour')] [int] $Hour,
        [Parameter(ParameterSetName='Day')] [switch] $Day,
        [Parameter(ParameterSetName='Month')] [switch] $Month,
        [Parameter(ParameterSetName='Months')] [int] $Months
    )
    Begin
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }
        if ($ToNewProperty -and $ToNewProperty.Count -ne $Property.Count)
        {
            throw "Property and ToNewProperty counts must match."
        }

        $newPropertyList = $Property
        if ($ToNewProperty) { $newPropertyList = $ToNewProperty }
    }
    Process
    {
        if (!$InputObject) { return }
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $newPropertyList)
        $newValue = $null

        for ($i = 0; $i -lt $Property.Count; $i++)
        {
            $propertyName = $Property[$i]
            $newPropertyName = $newPropertyList[$i]
            $value = $InputObject.$propertyName

            if ([string]::IsNullOrEmpty($value)) { continue }
            $value = [datetime]$value

            if ($PSCmdlet.ParameterSetName -eq 'Second')
            {
                $seconds = [Math]::Floor($value.Second / [double]$Second) * $Second
                $newValue = $value.Date.AddHours($value.Hour).AddMinutes($value.Minute).AddSeconds($seconds)
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Minute')
            {
                $minutes = [Math]::Floor($value.Minute / [double]$Minute) * $Minute
                $newValue = $value.Date.AddHours($value.Hour).AddMinutes($minutes)
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Hour')
            {
                $hours = [Math]::Floor($value.Hour / [double]$Hour) * $Hour
                $newValue = $value.Date.AddHours($hours)
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Day')
            {
                $newValue = $value.Date
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Month')
            {
                $newValue = $value.Date.AddDays(-1*$value.Day + 1)
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Months')
            {
                $newValue = [DateTime]::new($value.Year, [Math]::Floor(($value.Month-1)/$Months) * $Months + 1, 1)
            }

            if ($Format)
            {
                $newValue = $newValue.ToString($Format)
            }

            $newInputObject.$newPropertyName = $newValue
        }

        $newInputObject
    }
}

Function Set-PropertyDateTimeBreakpoint
{
    <#
    .SYNOPSIS
    Adds a text label of timespan or datetime (age of a timestamp as a timespan) describing how old/large it is for summarizing a wide range of times.

    .PARAMETER InputObject
    The objects to add the breakpoint label to.

    .PARAMETER Property
    The properties containing timespan or datetime values.

    .PARAMETER ToNewProperty
    Save the breakpoint labels to a new property instead of overwriting the existing property.

    .PARAMETER Minutes
    The minute breakpoints to use.

    .PARAMETER Hours
    The hour breakpoints to use.

    .PARAMETER Days
    The day (24 hours) breakpoints to use.

    .PARAMETER Weeks
    The week (7 days) breakpoints to use.

    .PARAMETER Months
    The month breakpoints to use.

    .PARAMETER Years
    The year breakpoints to use.

    .PARAMETER TeePossibleValues
    Create a variable in the parent scope with this name, containing the values of all the breakpoints that could have been set.

    .EXAMPLE
    Get-ChildItem C:\Windows |
        Select-Object Name, LastWriteTime |
        Sort-Object LastWriteTime |
        Set-PropertyDateTimeBreakpoint LastWriteTime -ToNewProperty LastWriteTimeBreakpoint -Hours 12 -Days 1, 2 -Weeks 1, 2 -Months 1, 2, 6 -Years 1, 2, 3

    .EXAMPLE
    Get-Process |
        Where-Object StartTime |
        Select-Object Name, StartTime |
        Set-PropertyDateTimeBreakpoint StartTime -Minutes 1, 5, 15, 30, 45 -Hours (1..23) -Days 1, 2, 3 -TeePossibleValues StartTimeValues |
        Group-Object StartTime

    $StartTimeValues

    #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0,Mandatory=$true)] [string[]] $Property,
        [Parameter()] [string[]] $ToNewProperty,
        [Parameter()] [uint32[]] $Minutes,
        [Parameter()] [uint32[]] $Hours,
        [Parameter()] [uint32[]] $Days,
        [Parameter()] [uint32[]] $Weeks,
        [Parameter()] [uint32[]] $Months,
        [Parameter()] [uint32[]] $Years,
        [Parameter()] [string] $TeePossibleValues
    )
    Begin
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }

        $breakpointList = [System.Collections.Generic.List[object]]::new()

        Function DefineBreakpoint([uint64]$Number, $Type, [uint64]$Multiplier)
        {
            $breakpoint = [ordered]@{}
            $breakpoint.Number = $Number
            $breakpoint.Type = $Type
            $breakpoint.Multiplier = $Multiplier
            $breakpoint.MaxValue = $Number * $Multiplier
            $breakpoint.Label = $null
            $breakpoint.SubLabel = "$Number $Type"
            if ($Number -eq 1) { $breakpoint.SubLabel = $breakpoint.SubLabel.TrimEnd("s") }
            $breakpointList.Add([pscustomobject]$breakpoint)
        }

        foreach ($v in $Minutes) { DefineBreakpoint $v Minutes 60 }
        foreach ($v in $Hours) { DefineBreakpoint $v Hours 3600 }
        foreach ($v in $Days) { DefineBreakpoint $v Days 86400 }
        foreach ($v in $Weeks) { DefineBreakpoint $v Weeks 604800 }
        foreach ($v in $Months) { DefineBreakpoint $v Months 2678400 }
        foreach ($v in $Years) { DefineBreakpoint $v Years 31536000 }

        $breakpointList = $breakpointList | Sort-Object MaxValue

        for ($i = 0; $i -lt $breakpointList.Count; $i++)
        {
            $breakpoint = $breakpointList[$i]
            if ($i -eq 0)
            {
                $breakpoint.Label = "0 - $($breakpoint.SubLabel)"
            }
            else
            {
                $breakpoint.Label = "$($lastBreakpoint.SubLabel) - $($breakpoint.SubLabel)"
            }
            $lastBreakpoint = $breakpoint
        }

        $now = [DateTime]::Now
        
        $propertyNameList = $Property
        if ($ToNewProperty) { $propertyNameList = $ToNewProperty }

        if ($ToNewProperty -and $ToNewProperty.Count -ne $Property.Count)
        {
            throw "Property and ToNewProperty counts must match."
        }

        if ($TeePossibleValues)
        {
            $valueList = & { $breakpointList.Label; "Over $($breakpoint.SubLabel)" }
            $PSCmdlet.SessionState.PSVariable.Set($TeePossibleValues, $valueList)
        }
    }
    Process
    {
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $propertyNameList)
        for ($i = 0; $i -lt $Property.Count; $i++)
        {
            $newPropertyName = $propertyNameList[$i]
            $value = $newInputObject.($Property[$i])
            if ($value -is [TimeSpan]) { $seconds = $value.TotalSeconds }
            else { $seconds = ($now - [datetime]$value).TotalSeconds }
            $found = $false
            foreach ($breakpoint in $breakpointList)
            {
                if ($seconds -le $breakpoint.MaxValue)
                {
                    $newInputObject.$newPropertyName = $breakpoint.Label
                    $found = $true
                    break
                }
            }
            if (!$found)
            {
                $newInputObject.$newPropertyName = "Over $($breakpoint.SubLabel)"
            }
        }
        $newInputObject
    }
}

Function Set-PropertyDateTimeFormat
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [string[]] $Property,
        [Parameter(Mandatory=$true, Position=1)] [string] $Format,
        [Parameter()] [ValidateSet('Short', 'Long')] [string] $AppendTimeZone
    )
    Begin
    {
        if ($AppendTimeZone)
        {
            $tz = [System.TimeZoneInfo]::Local
            $st = $tz.StandardName
            $dst = $tz.DaylightName
            if ($AppendTimeZone -eq 'Short')
            {
                $st = $(foreach ($c in $st -split ' ') { $c.Substring(0,1) }) -join ''
                $dst = $(foreach ($c in $dst -split ' ') { $c.Substring(0,1) }) -join ''
            }
        }
    }
    Process
    {
        if (!$InputObject) { return }
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property)
        foreach ($propertyName in $Property)
        {
            $oldValue = $null
            $newValue = $null
            if ([String]::IsNullOrEmpty($newInputObject.$propertyName)) { continue }
            $oldValue = [datetime]$newInputObject.$propertyName
            $newValue = $oldValue.ToString($Format)
            if ($AppendTimeZone)
            {
                if ($tz.IsDaylightSavingTime($oldValue))
                {
                    $newValue = "$newValue $dst"
                }
                else
                {
                    $newValue = "$newValue $st"
                }
            }
            $newInputObject.$propertyName = $newValue

        }
        $newInputObject
    }
}

Function Set-PropertyStringFormat
{
    <#
    .SYNOPSIS
    Runs String.Format on one or more properties.

    .PARAMETER InputObject
    Objets with properties to format.

    .PARAMETER Property
    The properties to format.

    .PARAMETER StringFormat
    The string format to use. Only the {0} value is usable.

    .PARAMETER DivideBy
    Attempt to divide the original property value by this amount; useful for byte conversions.

    .EXAMPLE
    Get-ChildItem C:\Windows -File |
        Select-Object Name, Length |
        Set-PropertyStringFormat Length "{0:n2} MB" -DivideBy (1024*1024)
    #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [string[]] $Property,
        [Parameter(Mandatory=$true, Position=1)] [string] $StringFormat,
        [Parameter()] [double] $DivideBy
    )
    Process
    {
        if (!$InputObject) { return }
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property)
        foreach ($propertyName in $Property)
        {
            $oldValue = $newInputObject.$propertyName
            if ([String]::IsNullOrEmpty($oldValue)) { continue }
            if ($DivideBy) { $oldValue = $oldValue / $DivideBy }
            $newValue = [string]::Format($StringFormat, $oldValue)
            $newInputObject.$propertyName = $newValue
        }
        $newInputObject
    }
}

Function Set-PropertyType
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [string[]] $Property,
        [Parameter(Mandatory=$true, Position=1)] [ValidateSet('DateTime', 'String', 'Int', 'Double', 'Bool')] [string] $Type,
        [Parameter()] [string] $ParseExact,
        [Parameter()] [switch] $Parse
    )
    Begin
    {
        $as = switch ($Type)
        {
            'String' { [string] }
            'DateTime' { [DateTime] }
            'Int' { [int] }
            'Double' { [double] }
            'Bool' { [bool] }
        }
    }
    Process
    {
        if (!$InputObject) { return }
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property)
        foreach ($propertyName in $Property)
        {
            $oldValue = $newInputObject.$propertyName
            $newValue = $null
            if (![String]::IsNullOrWhiteSpace($oldValue))
            {
                trap { $PSCmdlet.WriteError($_); continue }
                if ($ParseExact)
                {
                    $newValue = $as::ParseExact($oldValue, $ParseExact, $null)
                }
                elseif ($Parse)
                {
                    $newValue = $as::Parse($oldValue)
                }
                else
                {
                    $newValue = $oldValue -as $as
                }
                if ($newValue -eq $null) { throw "'$oldValue' cant't be converted to $Type." }
            }
            $newInputObject.$propertyName = $newValue
        }
        $newInputObject
    }
}

if (!$Script:LoadedDataSharp) {
Function Set-PropertyValue
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [string[]] $Property,
        [Parameter(Position=1)] [object] $Value,
        [Parameter()] [string] $JoinWith,
        [Parameter()] [object] $Where,
        [Parameter()] [string] $Match,
        [Parameter()] [switch] $IfUnset,
        [Parameter()] [switch] $NoClone
    )
    Begin
    {
        if ($Match)
        {
            $matchRegex = [regex]::new($Match, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $usesMatch = $true
        }
        else { $usesMatch = $false }
    }
    Process
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }

        if ($NoClone) { $newInputObject = [Rhodium.Data.DataHelpers]::EnsureHasProperties($InputObject, $Property) }
        else { $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $Property) }

        $setValue = $true
        $matchVar = [PSVariable]::new('Matches')
        if ($Where -is [scriptblock])
        {
            $varList = [System.Collections.Generic.List[PSVariable]]::new()
            $varList.Add([PSVariable]::new("_", $InputObject))
            $varList.Add($matchVar)
            $whereResult = $Where.InvokeWithContext($null, $varList, $null)
            $setValue = [System.Management.Automation.LanguagePrimitives]::IsTrue($whereResult)
        }
        elseif (![String]::IsNullOrWhiteSpace($Where))
        {
            if ($usesMatch)
            {
                $setValue = $newInputObject."$Where" -match $Match
                $matchVar.Value = $Matches
            }
            else
            {
                $setValue = [System.Management.Automation.LanguagePrimitives]::IsTrue($newInputObject."$Where")
            }
        }

        if (!$setValue) { return $newInputObject }

        $newValue = $Value
        if ($Value -is [ScriptBlock])
        {
            $varList = [System.Collections.Generic.List[PSVariable]]::new()
            $varList.Add([PSVariable]::new("_", $InputObject))
            $varList.Add($matchVar)
            $newValue = foreach ($item in $Value.InvokeWithContext($null, $varList, $null)) { $item }
        }

        foreach ($prop in $Property)
        {
            if (!$IfUnset -or [String]::IsNullOrWhiteSpace($newInputObject.$prop))
            {
                if ($JoinWith) { $newValue = $newValue -join $JoinWith }
                $newInputObject.$prop = $newValue
            }
        }
        $newInputObject
    }
}
}

Function Set-PropertyJoinValue
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [string[]] $Property,
        [Parameter(Mandatory=$true, Position=1)] [string] $JoinWith
    )
    Process
    {
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $null)
        foreach ($prop in $Property)
        {
            $newInputObject.$prop = $newInputObject.$prop -join $JoinWith
        }
        $newInputObject
    }
}

Function Set-PropertySplitValue
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [string[]] $Property,
        [Parameter(Mandatory=$true, Position=1)] [string] $SplitOn
    )
    Process
    {
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $null)
        foreach ($prop in $Property)
        {
            $newInputObject.$prop = $newInputObject.$prop -split $SplitOn
        }
        $newInputObject
    }
}

Function Get-FormattedXml
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true, Position=0)] [string[]] $XmlText
    )

    Begin
    {
        $textList = New-Object System.Collections.ArrayList
    }
    Process
    {
        [void]$textList.Add($XmlText -join "")
    }
    End
    {
        $xmlDoc = New-Object System.Xml.XmlDataDocument
        $xmlDoc.LoadXml($textList -join "")
        $stringWriter = New-Object System.Io.Stringwriter
        $xmlWriter = New-Object System.Xml.XmlTextWriter $stringWriter
        $xmlWriter.Formatting = [System.Xml.Formatting]::Indented
        $xmlDoc.WriteContentTo($xmlWriter)
        $stringWriter.ToString()
    }
}

Function Get-Sentences
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true, Position=0)] [string] $Text
    )
    Process
    {
        $lineList = $Text -split "`r`n" -split "(?<=[^\.].[\.\?\!]) +"
        foreach ($line in $lineList)
        {
            if (![String]::IsNullOrWhiteSpace($line)) { $line }
        }
    }
}

Function Get-StringHash
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)] [string] $String,
        [Parameter(Position=1)] [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5', 'RIPEMD160')]
            [string] $HashName = 'SHA1'
    )
    End
    {
        $stringBuilder = New-Object System.Text.StringBuilder
        $algorithm = [System.Security.Cryptography.HashAlgorithm]::Create($HashName)
        $bytes = $algorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))
        $bytes | ForEach-Object { [void]$stringBuilder.Append($_.ToString('x2')) }
        $stringBuilder.ToString()
    }
}

Function Get-UnindentedText
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true, Position=0)] [string[]] $Text
    )
    Begin
    {
        $lineList = New-Object System.Collections.Generic.List[string]
    }
    Process
    {
        foreach ($line in $Text) { $lineList.Add($line) }
    }
    End
    {
        $allText = $lineList -join "`r`n"
        $regex = [regex]"(?m)^( *)\S"
        $baseWhitespaceCount = $regex.Matches($allText) |
            ForEach-Object { $_.Groups[1].Length } |
            Measure-Object -Minimum |
            ForEach-Object Minimum
        if ($baseWhitespaceCount -eq 0) { return $allText }
        $allText -replace "(?m)^ {$baseWhitespaceCount}"
    }
}

Function Get-Weekday
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Position=0,ValueFromPipeline=$true)] [datetime] $Date = [DateTime]::Now,
        [Parameter(Mandatory=$true, ParameterSetName='Next')]
            [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
            [string] $Next,
        [Parameter(Mandatory=$true, ParameterSetName='Last')]
            [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
            [string] $Last,
        [Parameter()] [switch] $NotToday,
        [Parameter()] [string] $Format,
        [Parameter()] [int] $WeeksAway = 1
    )
    Process
    {
        $returnDate = $null
        $weekDayCount = 7 * ($WeeksAway - 1)
        if ($PSCmdlet.ParameterSetName -eq 'Next')
        {
            if ($NotToday.IsPresent -and $Date.DayOfWeek -eq $Next) { $Date = $Date.AddDays(1) }
            $daysUntilNext = (([int]([System.DayOfWeek]::$Next)) - ([int]$Date.DayOfWeek) + 7) % 7
            $returnDate = $Date.AddDays($daysUntilNext + $weekDayCount)
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Last')
        {
            if ($NotToday.IsPresent -and $Date.DayOfWeek -eq $Last) { $Date = $Date.AddDays(-1) }
            $daysUntilPrevious = (([int]$Date.DayOfWeek) - ([int]([System.DayOfWeek]::$Last)) + 7) % 7
            $returnDate = $Date.AddDays(-1 * $daysUntilPrevious - $weekDayCount)
        }

        if ($Format)
        {
            $returnDate.ToString($Format)
        }
        else
        {
            $returnDate
        }
    }
}

Function ConvertTo-Object
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0, Mandatory=$true)] [string] $Property,
        [Parameter()] [switch] $Unique
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[string]
    }
    Process
    {
        if ($InputObject -is [string])
        {
            $stringList = $InputObject -split "[`r`n]"
            foreach ($string in $stringList)
            {
                if (![String]::IsNullOrWhiteSpace($string)) { $inputObjectList.Add($string) }
            }
        }
        else
        {
            $inputObjectList.Add($InputObject)
        }
    }
    End
    {
        $inputObjectList |
            Select-Object @{Name=$Property; Expression={$_}} -Unique:$Unique
    }
}

Function Sort-ByPropertyValue
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string] $Property,
        [Parameter(Position=1)] [string[]] $Begin,
        [Parameter()] [string[]] $End
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        if (!$InputObject) { return }
        $inputObjectList.Add($InputObject)
    }
    End
    {
        $inputObjectDict = $inputObjectList | ConvertTo-Dictionary -Keys $Property -Ordered
        $usedValueDict = @{}
        foreach ($value in $Begin) { $usedValueDict[$value] = $true }
        foreach ($value in $End) { $usedValueDict[$value] = $true }
        foreach ($value in $Begin)
        {
            if ($inputObjectDict[$value]) { $inputObjectDict[$value] }
        }
        foreach ($value in $inputObjectDict.Keys)
        {
            if (!$usedValueDict[$value]) { $inputObjectDict[$value] }
        }
        foreach ($value in $End)
        {
            if ($inputObjectDict[$value]) { $inputObjectDict[$value] }
        }
    }
}

Function Select-UniformProperty
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
        $propertyDict = [ordered]@{}
    }
    Process
    {
        $inputObjectList.Add($InputObject)
        foreach ($property in $InputObject.PSObject.Properties.Name)
        {
            if (!$propertyDict.Contains($property))
            {
                $propertyDict[$property] = $true
            }
        }
    }
    End
    {
        $inputObjectList | Select-Object @($propertyDict.Keys)
    }
}

Function Assert-Count
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [int64[]] $Count,
        [Parameter()] [string] $Message
    )
    Begin
    {
        $inputObjectList = New-Object System.Collections.Generic.List[object]
    }
    Process
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }
        if (!$MyInvocation.ExpectingInput) { throw "You must provide pipeline input to this function." }
        $inputObjectList.Add($inputObjectList)
    }
    End
    {
        trap { $PSCmdlet.ThrowTerminatingError($_) }
        if ($inputObjectList.Count -notin $Count)
        {
            if (!$Message) { $Message = "Assertion failed: Object count was $($inputObjectList.Count), expected $($Count -join ', ')." }
            throw $Message
        }
    }
}

Function Compress-PlainText
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Position=0, ValueFromPipeline=$true)] [string] $Text,
        [Parameter()] [switch] $AsBase64
    )
    Begin
    {
        $lineList = New-Object System.Collections.Generic.List[string]
    }
    Process
    {
        $lineList.Add($Text)
    }
    End
    {
        $textBytes = [System.Text.Encoding]::UTF8.GetBytes(($lineList -join "`r`n"))
        $stream = New-Object System.IO.MemoryStream
        $zip = New-Object System.IO.Compression.GZipStream $stream, ([System.IO.Compression.CompressionMode]::Compress)
        $zip.Write($textBytes, 0, $textBytes.Length)
        $zip.Close()
        if ($AsBase64) { return [Convert]::ToBase64String($stream.ToArray()) }
        $stream.ToArray()
    }
}

Function Expand-PlainText
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(ParameterSetName='Bytes', Position=0)] [byte[]] $CompressedBytes,
        [Parameter(ValueFromPipeline=$true, ParameterSetName='Base64', Position=0)] [string] $CompressedBase64
    )
    Process
    {
        if ($CompressedBase64) { $CompressedBytes = [Convert]::FromBase64String($CompressedBase64) }
        $inputStream = New-Object System.IO.MemoryStream (,$CompressedBytes)
        $outputStream = New-Object System.IO.MemoryStream
        $zip = New-Object System.IO.Compression.GZipStream $inputStream, ([System.IO.Compression.CompressionMode]::Decompress)

        $temp = [Array]::CreateInstance([byte], 4096)
        while ($true -and $inputStream.Length)
        {
            $count= $zip.Read($temp, 0, 4096)
            if ($count -eq 0) { break }
            $outputStream.Write($temp, 0, $count)
        }
        $zip.Close()
        [System.Text.Encoding]::UTF8.GetString($outputStream.ToArray())
    }
}
