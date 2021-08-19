Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Select-Including" {

    Context 'Default' {

        It 'Filters' {
            $result = @(
                [pscustomobject]@{PropA=1}
                [pscustomobject]@{PropA=2}
            ) |
                Select-Including PropA @([pscustomobject]@{PropA=1}) PropA

            @($result).Count | Should Be 1
            $result.PropA | Should Be 1
        }

        It 'Filters with InputKeys if CompareKeys not set' {
            $result = @(
                [pscustomobject]@{PropA=1}
                [pscustomobject]@{PropA=2}
            ) |
                Select-Including PropA @([pscustomobject]@{PropA=1})

            @($result).Count | Should Be 1
            $result.PropA | Should Be 1
        }
    }
}
