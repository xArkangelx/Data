Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Join-Self" {

    Context 'Basic Tests' {

        It 'Performs a simple self join' {
            $result = @(
                [pscustomobject]@{A=1;B=1}
                [pscustomobject]@{A=1;B=2}
                [pscustomobject]@{A=2;B=3}
            ) |
                Join-Self A { $input | Group-Object A } Name -KeepProperty Count

            @($result).Count | Should Be 3

            $result[0].PSObject.Properties.Name -join '+' | Should Be "A+B+Count"

            $result[0].A | Should Be 1
            $result[0].B | Should Be 1
            $result[0].Count | Should Be 2

            $result[1].A | Should Be 1
            $result[1].B | Should Be 2
            $result[1].Count | Should Be 2

            $result[2].A | Should Be 2
            $result[2].B | Should Be 3
            $result[2].Count | Should Be 1
        }

        It 'Performs a join without keys' {
            $result = @(
                [pscustomobject]@{A=1;Number=2}
                [pscustomobject]@{A=2;Number=4}
            ) | Join-Self -ScriptBlock { $input | Measure-Object Number -Average -Sum | Select-Object Average, Sum }

            @($result).Count | Should Be 2

            $result[0].PSObject.Properties.Name -join '+' | Should Be "A+Number+Average+Sum"

            $result[0].A | Should Be 1
            $result[0].Number | Should Be 2
            $result[0].Average | Should Be 3
            $result[0].Sum | Should Be 6

            $result[1].A | Should Be 2
            $result[1].Number | Should Be 4
            $result[1].Average | Should Be 3
            $result[1].Sum | Should Be 6
        }

        It 'Renames' {
            $result = @(
                [pscustomobject]@{A=1;Number=2}
                [pscustomobject]@{A=2;Number=4}
            ) | Join-Self -ScriptBlock { $input | Measure-Object Number -Average -Sum | Select-Object Average, Sum } -KeepProperty Sum, @{Average='Avg'}

            @($result).Count | Should Be 2

            $result[0].PSObject.Properties.Name -join '+' | Should Be "A+Number+Sum+Avg"

            $result[0].A | Should Be 1
            $result[0].Number | Should Be 2
            $result[0].Avg | Should Be 3
            $result[0].Sum | Should Be 6

            $result[1].A | Should Be 2
            $result[1].Number | Should Be 4
            $result[1].Avg | Should Be 3
            $result[1].Sum | Should Be 6
        }
    }
}
