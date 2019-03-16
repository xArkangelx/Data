
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
    }
}
"@

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
        [Parameter()] [switch] $OverwriteNull,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $joinDict = [ordered]@{}
        foreach ($joinObject in $JoinData)
        {
            $keyValue = $(foreach ($joinKey in $JoinKeys) { $joinObject.$joinKey }) -join $KeyJoin
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
        $keyValue = $(foreach ($inputKey in $InputKeys) { $InputObject.$inputKey }) -join $KeyJoin
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

Function Join-Index
{
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

Function ConvertTo-Dictionary
{
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
            if (!$dict.Contains($keyValue))
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

Function Select-DuplicatePropertyValue
{
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
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string[]] $InputKeys,
        [Parameter(Position=1)] [object[]] $CompareData,
        [Parameter(Mandatory=$true,Position=2)] [string[]] $CompareKeys,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $noData = !$CompareData
        $compareDict = @{}
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
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true,Position=0)] [string[]] $InputKeys,
        [Parameter(Position=1)] [object[]] $CompareData,
        [Parameter(Mandatory=$true,Position=2)] [string[]] $CompareKeys,
        [Parameter()] [string] $KeyJoin = '|'
    )
    Begin
    {
        $noData = !$CompareData
        $compareDict = @{}
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

Function Invoke-PipelineThreading
{
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

Function Set-PropertyValue
{
    Param
    (
        [Parameter(ValueFromPipeline=$true)] [object] $InputObject,
        [Parameter(Mandatory=$true, Position=0)] [string[]] $Property,
        [Parameter(Position=1)] [object] $Value
    )
    Process
    {
        $newInputObject = [Rhodium.Data.DataHelpers]::CloneObject($InputObject, $null)
        $newValue = $Value
        if ($Value -is [ScriptBlock])
        {
            $varList = New-Object System.Collections.Generic.List[PSVariable]
            $varList.Add((New-Object PSVariable "_", $InputObject))
            $newValue = foreach ($item in $Value.InvokeWithContext($null, $varList, $null)) { $item }
        }
        foreach ($prop in $Property)
        {
            $newInputObject.$prop = $newValue
        }
        $newInputObject
    }
}

Function Set-PropertyJoinValue
{
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

Function Get-StringHash
{
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

Function Get-Weekday
{
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

Function Assert-Count
{
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
