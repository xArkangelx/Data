Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Select-DedupByPropertyValue" {

    Context 'Default' {

        It 'Works with 1 item 1 key' {
            $results = @(
                [pscustomobject]@{Series = 'A'; Index = 1}
                [pscustomobject]@{Series = 'A'; Index = 2}
                [pscustomobject]@{Series = 'B'; Index = 1}
            ) | Select-DedupByPropertyValue Series
            
            @($results).Count | Should Be 2

            $results[0].Series | Should Be A
            $results[0].Index | Should Be 1

            $results[1].Series | Should Be B
            $results[1].Index | Should Be 1
        }

        It 'Works with 1 item 2 keys' {
            $results = @(
                [pscustomobject]@{Series = 'A'; Subseries='Blue'; Index = 1}
                [pscustomobject]@{Series = 'A'; Subseries='Blue'; Index = 2}
                [pscustomobject]@{Series = 'A'; Subseries='Green'; Index = 1}
            ) | Select-DedupByPropertyValue Series, Subseries

            @($results).Count | Should Be 2

            $results[0].Series | Should Be A
            $results[0].Subseries | Should Be Blue
            $results[0].Index | Should Be 1

            $results[1].Series | Should Be A
            $results[1].Subseries | Should Be Green
            $results[1].Index | Should Be 1
        }

        It 'Works with 2 items 1 key' {
            $results = @(
                [pscustomobject]@{Series = 'A'; Index = 1}
                [pscustomobject]@{Series = 'A'; Index = 2}
                [pscustomobject]@{Series = 'A'; Index = 3}
                [pscustomobject]@{Series = 'B'; Index = 1}
            ) | Select-DedupByPropertyValue Series -Count 2

            @($results).Count | Should Be 3

            $results[0].Series | Should Be A
            $results[0].Index | Should Be 1

            $results[1].Series | Should Be A
            $results[1].Index | Should Be 2

            $results[2].Series | Should Be B
            $results[2].Index | Should Be 1
        }
    }
}
