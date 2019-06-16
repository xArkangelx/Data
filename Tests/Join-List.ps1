Import-Module (Get-Module -Name Data).Path -DisableNameChecking -Force

Describe "Join-List" {

    Context 'Default' {
        
        $clusterList = "
            ClusterId,ClusterName,ClusterType
            1,SQL001,SQL
            2,SQL002,SQL
            3,CAFile,File
            4,TXFile,File
            6,SQL003,SQL
        ".Trim() -replace '\A +' | ConvertFrom-Csv

        $groupList = "
            ClusterId,GroupName
            1,INST1
            1,INST2
            2,INST1
            3,Departments
            3,IT
            4,IT
            5,Finance
        ".Trim() -replace '\A +' | ConvertFrom-Csv

        It 'Works' {
            $resultList = $groupList | Join-List ClusterId $clusterList ClusterId
            $resultList[0].ClusterName | Should Be SQL001
            $resultList[0].ClusterType | Should Be SQL
            $resultList[-1].ClusterName | Should Be $null
            $resultList[-1].ClusterType | Should Be $null
            @($resultList[-1].PSObject.Properties)[-2].Name | Should Be ClusterName
            @($resultList[-1].PSObject.Properties)[-1].Name | Should Be ClusterType
        }

        It 'Works with -MatchesOnly' {
            $resultList = $groupList | Join-List ClusterId $clusterList ClusterId -MatchesOnly
            $resultList[0].ClusterName | Should Be SQL001
            $resultList[-1].ClusterName | Should Not Be $null
        }

        It 'Works with a null key' {
            $resultList = $groupList | Join-List NotAMatch $clusterList ClusterId
            $resultList[0].ClusterName | Should Be $null
        }

        It 'Works with -KeepProperty' {
            $resultList = $groupList | Join-List ClusterId $clusterList ClusterId -KeepProperty ClusterName
            $resultList[0].ClusterName | Should Be SQL001
            $found = @($resultList[0].ClusterType) -eq 'ClusterType'
            $found | Should Be $null
        }

        It 'Works with -KeepProperty and a null key' {
            $resultList = $groupList | Join-List NotAMatch $clusterList ClusterId -KeepProperty ClusterName
            $found = @($resultList[0].ClusterType) -eq 'ClusterType'
            $found | Should Be $null
        }
    }
}
