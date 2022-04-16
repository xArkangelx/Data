Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Group-SequentialSame" {
    Context "Basic Tests" {
        It "Empty test" {
            $result1 = @() | Group-SequentialSame Series
            @($result1).Count | Should Be 0

            $result2 = $null | Group-SequentialSame Series
            @($result2).Count | Should Be 0
        }

        It "Single key test" {
            
            $result = @(
                [pscustomobject]@{Series='A'; Index=1}
                [pscustomobject]@{Series='A'; Index=2}
                [pscustomobject]@{Series='B'; Index=3}
                [pscustomobject]@{Series='B'; Index=4}
                [pscustomobject]@{Series='A'; Index=5}
                [pscustomobject]@{Series='C'; Index=6}
                [pscustomobject]@{Series='A'; Index=7}
                [pscustomobject]@{Series='A'; Index=8}
                [pscustomobject]@{Series='B'; Index=9}
            ) |
                Group-SequentialSame Series

            @($result).Count | Should Be 6

            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Series+Group'
            @($result[0].Group).Count | Should Be 2

            $result[0].Series | Should Be A
            $result[0].Group[0].Index | Should Be 1
            $result[0].Group[1].Index | Should Be 2

            $result[1].Series | Should Be B
            $result[1].Group[0].Index | Should Be 3

            $result[2].Series | Should Be A
            $result[2].Group[0].Index | Should Be 5

            $result[3].Series | Should Be C
            $result[3].Group[0].Index | Should Be 6

            $result[4].Series | Should Be A
            $result[4].Group[0].Index | Should Be 7

            $result[5].Series | Should Be B
            $result[5].Group[0].Index | Should Be 9

        }

        It 'Single value test' {
            $result = @(
                [pscustomobject]@{Series='A'; Index=1}
            ) |
                Group-SequentialSame Series

            @($result).Count | Should Be 1
            $result[0].Series | Should Be A
            $result[0].Group[0].Index | Should Be 1
        }

        It 'Two value test' {
            $result = @(
                [pscustomobject]@{Series='A'; Index=1}
                [pscustomobject]@{Series='A'; Index=2}
            ) |
                Group-SequentialSame Series
            
            @($result).Count | Should Be 1
            $result[0].Series | Should Be A
            $result[0].Group.Count | Should Be 2
            $result[0].Group[0].Index | Should Be 1
            $result[0].Group[1].Index | Should Be 2
        }

        It "Multi key test" {

            $result = @(
                [pscustomobject]@{Series='A'; Color='Blue'; Index=1}
                [pscustomobject]@{Series='A'; Color='Blue'; Index=2}
                [pscustomobject]@{Series='A'; Color='Green'; Index=3}
                [pscustomobject]@{Series='B'; Color='Blue'; Index=4}
            ) |
                Group-SequentialSame Series, Color

            @($result).Count | Should Be 3
            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Series+Color+Group'

            $result[0].Series | Should Be A
            $result[0].Color | Should Be Blue

            $result[1].Series | Should Be A
            $result[1].Color | Should Be Green

            $result[2].Series | Should Be B
            $result[2].Color | Should Be Blue
        }

        It '-GroupProperty' {
            $result = @(
                [pscustomobject]@{Series='A'; Index=1}
            ) |
                Group-SequentialSame Series -GroupProperty Items
            
            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Series+Items'
        }

        It '-CountProperty' {
            $result = @(
                [pscustomobject]@{Series='A'}
                [pscustomobject]@{Series='A'}
                [pscustomobject]@{Series='B'}
            ) |
                Group-SequentialSame Series -CountProperty ItemCount
            
            $result[0].PSObject.Properties.Name -join '+' | Should Be 'ItemCount+Series+Group'
            $result[0].ItemCount | Should Be 2
            $result[1].ItemCount | Should Be 1
        }

        It '-IndexProperty -IndexStart' {
            $result = @(
                [pscustomobject]@{Series='A'}
                [pscustomobject]@{Series='A'}
                [pscustomobject]@{Series='B'}
            ) |
                Group-SequentialSame Series -IndexProperty Index -IndexStart 1
            
            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Index+Series+Group'
            $result[0].Index | Should Be 1
            $result[1].Index | Should Be 2
        }

        It '-IndexProperty -CountProperty (property name check)' {
            $result = @(
                [pscustomobject]@{Series='A'; Index=1}
                [pscustomobject]@{Series='A'; Index=2}
                [pscustomobject]@{Series='B'; Index=3}
                [pscustomobject]@{Series='B'; Index=4}
                [pscustomobject]@{Series='A'; Index=5}
                [pscustomobject]@{Series='C'; Index=6}
                [pscustomobject]@{Series='A'; Index=7}
                [pscustomobject]@{Series='A'; Index=8}
                [pscustomobject]@{Series='B'; Index=9}
            ) |
                Group-SequentialSame Series -IndexProperty Index -CountProperty Count

            $result[0].PSObject.Properties.Name -join '+' | Should Be 'Index+Count+Series+Group'
        }
    }
}
