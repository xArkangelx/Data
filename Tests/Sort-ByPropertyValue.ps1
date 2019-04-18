Import-Module (Get-Module -Name Data).Path -DisableNameChecking -Force

Describe "Sort-ByPropertyValue" {

    Context 'Default' {
        It 'Sorts with -Begin and -End' {
            $serviceList = Get-Service | Sort-Object Name
            $sortedList = $serviceList | Sort-ByPropertyValue Name -Begin Spooler, SysMain -End Themes
            $sortedList[0].Name | Should Be "Spooler"
            $sortedList[1].Name | Should Be "SysMain"
            $sortedList[$sortedList.Count - 1].Name | Should Be Themes
        }
    }
}
