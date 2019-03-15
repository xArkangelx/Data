Function Join-List
{
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Position=0)] [string[]] $InputKeys,
        [Parameter(Position=1)] [object[]] $JoinData,
        [Parameter(Position=2)] [string[]] $JoinKeys,
        [Parameter()] [switch] $MatchesOnly,
        [Parameter()] [switch] $FirstRightOnly,
        [Parameter()] [switch] $IncludeUnmatchedRight,
        [Parameter()] [string[]] $KeepProperty,
        [Parameter()] [switch] $OverwriteAll,
        [Parameter()] [switch] $OverwriteNull
    )
    Begin
    {
        $joinDict = [ordered]@{}
        foreach ($joinObject in $JoinData)
        {
            $keyValue = $(foreach ($joinKey in $JoinKeys) { $joinObject.$joinKey }) -join '|'
            if (!$joinDict.Contains($keyValue))
            {
                $joinDict[$keyValue] = New-Object System.Collections.Generic.List[object]
            }
            $joinDict[$keyValue].Add($joinObject)
        }
        $usedKeys = @{}
        $joinObjectPropertyList = $joinObject.PSObject.Properties |
            Where-Object Name -NotIn $JoinKeys |
            Select-Object -ExpandProperty Name
    }
    Process
    {
        if (!$InputObject) { return }
        $keyValue = $(foreach ($inputKey in $InputKeys) { $InputObject.$inputKey }) -join '|'
        $joinObject = $joinDict[$keyValue]
        if (!$joinObject -and $MatchesOnly) { return }
        if (!$joinObject)
        {
            $newObject = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties)
            {
                $newObject[$property.Name] = $property.Value
            }
            foreach ($propertyName in $joinObjectPropertyList)
            {
                $newObject[$propertyName] = $null
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
                if ($PSBoundParameters.ContainsKey('KeepProperty') -and $property.Name -notin $KeepProperty) { continue }
                if ($newObject.Contains($property.Name) -and (!$OverwriteAll -or
                    ([String]::IsNullOrWhiteSpace($newObject[$property.Name] -and !$OverwriteNull)))) { continue }
                $newObject[$property.Name] = $property.Value
                [pscustomobject]$newObject
            }
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
                    if ($joinProperty.Name -in $JoinKeys) { continue }
                    if ($PSBoundParameters.Contains('KeepProperty') -and $property.Name -notin $KeepProperty) { continue }
                    $newObject[$joinProperty.Name] = $joinProperty.Value
                }
                [pscustomobject]$newObject
                if ($FirstRightOnly) { break }
            }
        }
    }
}


