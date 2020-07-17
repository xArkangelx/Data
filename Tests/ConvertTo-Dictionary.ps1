Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "ConvertTo-Dictionary" {

    Context 'Default' {
        It 'Works' {
            $serviceList = Get-Service
            $serviceDict = $serviceList | ConvertTo-Dictionary -Keys Name
            $serviceDict['Spooler'] | Should Not BeNullOrEmpty
            $serviceDict['Spooler'] | Should Be ($serviceList | Where-Object Name -eq Spooler)
        }

        It 'Works with -Ordered' {
            $serviceList = Get-Service
            $serviceDict = $serviceList | ConvertTo-Dictionary -Keys Name -Ordered
            $serviceDict[0] | Should Be $serviceList[0]
            $serviceDict['Spooler'] | Should Be ($serviceList | Where-Object Name -eq Spooler)
        }

        It 'Works with -Value' {
            $serviceList = Get-Service
            $serviceDict = $serviceList | ConvertTo-Dictionary -Keys Name -Value DisplayName
            $serviceDict['Spooler'] | Should Be ($serviceList | Where-Object Name -eq Spooler | ForEach-Object DisplayName)
        }

        It 'Works with -Value and -Ordered' {
            $serviceList = Get-Service
            $serviceDict = $serviceList | ConvertTo-Dictionary -Keys Name -Value DisplayName -Ordered
            $serviceDict[0] | Should Be $serviceList[0].DisplayName
            $serviceDict['Spooler'] | Should Be ($serviceList | Where-Object Name -eq Spooler | ForEach-Object DisplayName)
        }

        It 'Works with -KeyJoin' {
            $serviceList = Get-Service
            $serviceDict = $serviceList | ConvertTo-Dictionary -Keys Name, DisplayName -KeyJoin '+'
            $service = $serviceList | Where-Object Name -eq Spooler
            $key = $service.Name, $service.DisplayName -join '+'
            $serviceDict[$key] | Should Be $service
        }
    }
}
