Import-Module (Get-Module -Name Data).Path -DisableNameChecking -Force

Describe "Set-PropertyDateFloor" {
    
    $time1 = [pscustomobject]@{A=[datetime]"3/4/2019 11:55:45.123 PM"; B=[Datetime]"4/5/2019 4:30:15 AM"}

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
