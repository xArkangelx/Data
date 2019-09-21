Import-Module (Get-Module -Name Data).Path -DisableNameChecking -Force

Describe "Expand-Normalized" {

    Context 'Default' {
        
        It 'Adds Missing Properties' {
            $result = [pscustomobject][ordered]@{A=1} |
                Expand-Normalized B

            @($result).Count | Should Be 1
            $result.PSObject.Properties.Name -join '+' | Should Be A+B
            $result.A | Should Be 1
            $result.B | Should Be $null
        }

        It 'Works with a single value' {
            $result = [pscustomobject][ordered]@{A=1;B='23'} |
                Expand-Normalized B

            @($result).Count | Should Be 1
            $result.PSObject.Properties.Name -join '+' | Should Be A+B
            $result.A | Should Be 1
            $result.B | Should Be '23'
        }

        It 'Works with array values' {
            $result = [pscustomobject][ordered]@{A=1;B=2,3,4} |
                Expand-Normalized B

            @($result).Count | Should Be 3
            $result[0].PSObject.Properties.Name -join '+' | Should Be A+B
            $result[0].B | Should Be 2
            $result[1].B | Should Be 3
            $result[2].B | Should Be 4
        }

        It 'Works with string split' {
            $result = [pscustomobject][ordered]@{A=1;B='2|3|4'} |
                Expand-Normalized B -SplitOn '\|'

            @($result).Count | Should Be 3
            $result[0].PSObject.Properties.Name -join '+' | Should Be A+B
            $result[0].B | Should Be 2
            $result[1].B | Should Be 3
            $result[2].B | Should Be 4            
        }

        It 'Expands single objects' {
            $result = [pscustomobject][ordered]@{
                A = 1
                B = [pscustomobject][ordered]@{C=3;D=4}
            } |
                Expand-Normalized B -IsObject

            @($result).Count | Should Be 1
            $result.PSObject.Properties.Name -join '+' | Should Be A+C+D
            $result.A | Should Be 1
            $result.C | Should Be 3
            $result.D | Should Be 4
        }

        It 'Expands array objects' {
            $result = [pscustomobject][ordered]@{
                A = 1
                B = @(
                    [pscustomobject][ordered]@{C=3;D=4}
                    [pscustomobject][ordered]@{C=-3;D=-4}
                )
            } |
                Expand-Normalized B -IsObject

            @($result).Count | Should Be 2
            $result[0].PSObject.Properties.Name -join '+' | Should Be A+C+D
            $result[0].A | Should Be 1
            $result[0].C | Should Be 3
            $result[0].D | Should Be 4
            $result[1].A | Should Be 1
            $result[1].C | Should Be -3
            $result[1].D | Should Be -4
        }
    }
}
