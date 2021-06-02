Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Join-PropertySetComparison" {

    Context 'Default' {

        It 'Finds Same' {
            $result = [pscustomobject]@{Base='A', 'B', 'C'; Comparison='A', 'B', 'C'} |
                Join-PropertySetComparison -BaseProperty Base -ComparisonProperty Comparison -ResultProperty Result -SameDifferentMissingExtraValues S, D, M, E

            $result.Result | Should Be S
        }

        It 'Finds Different' {
            $result = [pscustomobject]@{Base='A', 'B', 'C', 'D'; Comparison='A', 'B', 'C', 'E'} |
                Join-PropertySetComparison -BaseProperty Base -ComparisonProperty Comparison -ResultProperty Result -SameDifferentMissingExtraValues S, D, M, E

            $result.Result | Should Be D
        }

        It 'Finds Missing' {
            $result = [pscustomobject]@{Base='A', 'B', 'C', 'D'; Comparison='A', 'B', 'C'} |
                Join-PropertySetComparison -BaseProperty Base -ComparisonProperty Comparison -ResultProperty Result -MissingProperty Missing -SameDifferentMissingExtraValues S, D, M, E

            $result.Missing | Should Be 'D'
            $result.Result | Should Be M
        }

        It 'Finds Extra' {
            $result = [pscustomobject]@{Base='A', 'B', 'C'; Comparison='A', 'B', 'C', 'D'} |
                Join-PropertySetComparison -BaseProperty Base -ComparisonProperty Comparison -ResultProperty Result -ExtraProperty Extra -SameDifferentMissingExtraValues S, D, M, E

            $result.Result | Should Be E
            $result.Extra | Should Be 'D'
        }

        It 'Handles Integers/Order' {
            $result = [pscustomobject]@{Base=1,2,3,4; Comparison=5,4,2,1} |
                Join-PropertySetComparison -BaseProperty Base -ComparisonProperty Comparison -ExtraProperty Extra -MissingProperty Missing
            $result.Missing | Should Be 3
            $result.Extra | Should Be 5
        }
    }
}
