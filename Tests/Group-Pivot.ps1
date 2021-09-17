Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Group-Pivot" {

    Context 'Default' {
        It 'Works' {
            $result = [pscustomobject]@{K=1; A=3; B=-3},[pscustomobject]@{K=1; A=4; B=-4},[pscustomobject]@{K=2; A=3; B=-3} |
                Group-Pivot -GroupProperty K -ColumnProperty A -ValueProperty B

            @($result).Count | Should Be 2

            $result[0].PSObject.Properties.Name -join '+' | Should Be "K+Count+3+4"
            $result[0].K | Should Be 1
            $result[0].Count | Should Be 2
            $result[0].'3' | Should Be -3
            $result[0].'4' | Should Be -4
            
            $result[1].PSObject.Properties.Name -join '+' | Should Be "K+Count+3+4"
            $result[1].K | Should Be 2
            $result[1].Count | Should Be 1
            $result[1].'3' | Should Be -3
            $result[1].'4' | Should Be $null            
        }

        It 'Respects -NoCount' {
            $result = [pscustomobject]@{K=1; A='Col'; B='Val'} |
                Group-Pivot -GroupProperty K -ColumnProperty A -ValueProperty B -NoCount
            $result[0].PSObject.Properties.Name -join '+' | Should Be "K+Col"
        }

        It 'Works with datetime keys' {
            $result = [pscustomobject]@{Timestamp = [DateTime]::Today.AddMilliseconds(123); Column = 'A'; Present = $true} |
                Group-Pivot Timestamp Column Present
            $result.A | Should Be $true
        }
    }
}
