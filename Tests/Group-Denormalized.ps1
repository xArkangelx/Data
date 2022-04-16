Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Group-Denormalized" {
    Context "Basic Tests" {
        It "All measurements work" {
            $result = @(
                [pscustomobject]@{A=1; B=2}
                [pscustomobject]@{A=1; B=1}
                [pscustomobject]@{A=1; B=1}
                [pscustomobject]@{A=1; B=4}
                [pscustomobject]@{A=1; B=3}
            ) |
                Group-Denormalized A -KeepAll B -KeepFirst B -KeepLast B -Sum B -Avg B -Min B -Max B -KeepUnique B -CountAll B -CountUnique B -JoinWith '+'

            @($result).Count | Should Be 1
            $result.A | Should Be 1
            $result.Count | Should Be 5
            $result.FirstB | Should Be 2
            $result.LastB | Should Be 3
            $result.MinB | Should Be 1
            $result.MaxB | Should Be 4
            $result.SumB | Should Be 11
            $result.AvgB | Should Be (11/5)
            $result.BCountAll | Should Be 5
            $result.BCountUnique | Should Be 4
            $result.AllB | Should Be '2+1+1+4+3'
            $result.UniqueB | Should Be '2+1+4+3'
        }

        It 'CountProperty' {
            $result = @(
                [pscustomobject]@{A=1}
                [pscustomobject]@{A=1}
            ) |
                Group-Denormalized A -CountProperty Items
            
            @($result).Count | Should Be 1
            $result.PSObject.Properties.Name -join '+' | Should Be "A+Items"
            $result.A | Should Be 1
            $result.Items | Should Be 2
        }
    }

    Context "Special Inputs" {
        It "Handles empty input" {
            $result = @() | Group-Denormalized Property
            @($result).Count | Should Be 0
        }

        It "Handles null input" {
            $result = $null | Group-Denormalized Property
            @($result).Count | Should Be 0            
        }
    }
}
