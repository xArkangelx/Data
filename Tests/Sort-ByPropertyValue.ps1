Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Sort-ByPropertyValue" {

    Context 'Default' {
        It 'Sorts with -Begin and -End' {
            $serviceList = Get-Service | Sort-Object Name
            $sortedList = $serviceList | Sort-ByPropertyValue Name -Begin Spooler, SysMain -End Themes
            $sortedList[0].Name | Should Be "Spooler"
            $sortedList[1].Name | Should Be "SysMain"
            $sortedList[$sortedList.Count - 1].Name | Should Be Themes
        }

        It 'Preserves Previous Order' {
            $values = 'X', 'A', 'Y', 'Z', 'C', 'B' |
                ForEach-Object { [pscustomobject]@{Value=$_} } |
                Sort-ByPropertyValue Value -Begin Z -End A

            $values.Value -join '' | Should Be ZXYCBA
        }
    }
}
