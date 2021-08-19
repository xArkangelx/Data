Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Select-Excluding" {

    Context 'Default' {

        It 'Filters' {
            $result = @(
                [pscustomobject]@{PropA=1}
                [pscustomobject]@{PropA=2}
            ) |
                Select-Excluding PropA @([pscustomobject]@{PropA=1}) PropA

            @($result).Count | Should Be 1
            $result.PropA | Should Be 2
        }

        It 'Filters with InputKeys if CompareKeys not set' {
            $result = @(
                [pscustomobject]@{PropA=1}
                [pscustomobject]@{PropA=2}
            ) |
                Select-Excluding PropA @([pscustomobject]@{PropA=1})

            @($result).Count | Should Be 1
            $result.PropA | Should Be 2
        }
    }
}
