Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Join-Hashtable" {

    Context 'Default' {

        It "Empty test" {
            $result1 = @() | Join-Hashtable Value NewValue @{}
            @($result1).Count | Should Be 0

            $result2 = $null | Join-Hashtable Value NewValue @{}
            @($result2).Count | Should Be 0
        }

        It 'Basic test' {
            $result = @(
                [pscustomobject]@{Value=1}
                [pscustomobject]@{Value=2}
                [pscustomobject]@{Value=3}
            ) |
                Join-Hashtable Value Text @{1='One'; 2='Two'; '3'='Three should not be found'}

            @($result).Count | Should Be 3
            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Value+Text'
            
            $result[0].Value | Should Be 1
            $result[0].Text | Should Be One

            $result[1].Value | Should Be 2
            $result[1].Text | Should Be Two

            $result[2].Value | Should Be 3
            $result[2].Text | Should Be $null
        }

        It '-AsString' {
            $result = @(
                [pscustomobject]@{Value=1}
                [pscustomobject]@{Value='2'}
                [pscustomobject]@{Value=$null}
            ) |
                Join-Hashtable Value Text @{'1'='One'; '2'='Two'; ''='Empty'} -AsString

            @($result).Count | Should Be 3
            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Value+Text'
            
            $result[0].Value | Should Be 1
            $result[0].Text | Should Be One

            $result[1].Value | Should Be 2
            $result[1].Text | Should Be Two

            $result[2].Value | Should Be $null
            $result[2].Text | Should Be 'Empty'
        }

        It '-IfNotFound' {
            $result = @(
                [pscustomobject]@{Value=1}
                [pscustomobject]@{Value=2}
                [pscustomobject]@{Value=3}
            ) |
                Join-Hashtable Value Text @{1='One'; 2='Two'} -IfNotFound 'Not Found'

            @($result).Count | Should Be 3
            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Value+Text'
            
            $result[0].Value | Should Be 1
            $result[0].Text | Should Be One

            $result[1].Value | Should Be 2
            $result[1].Text | Should Be Two

            $result[2].Value | Should Be 3
            $result[2].Text | Should Be 'Not Found'
        }
    }
}
