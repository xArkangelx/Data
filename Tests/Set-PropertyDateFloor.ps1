Import-Module (Get-Module -Name Data).Path -DisableNameChecking -Force

Describe "Set-PropertyDateFloor" {
    
    $time1 = [pscustomobject]@{A=[datetime]"3/4/2019 11:55:45.123 PM"; B=[Datetime]"4/5/2019 4:30:15 AM"}

    Context 'Default' {
        It 'Passes nothing with null input' {
            $out = $null | Set-PropertyDateFloor -Property Nothing -Hour 1
            $out.Count | Should Be 0
        }

        It 'Works with -Second 1' {
            $time1 | Set-PropertyDateFloor -Property A -Second 1 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:45 PM')
        }

        It 'Works with -Second 2' {
            $time1 | Set-PropertyDateFloor -Property A -Second 2 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:44 PM')
        }

        It 'Works with -Second 10' {
            $time1 | Set-PropertyDateFloor -Property A -Second 10 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:40 PM')
        }

        It 'Works with -Second 15' {
            $time1 | Set-PropertyDateFloor -Property A -Second 15 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:45 PM')
        }

        It 'Works with -Minute 1' {
            $time1 | Set-PropertyDateFloor -Property A -Minute 1 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:00 PM')
        }

        It 'Works with -Minute 2' {
            $time1 | Set-PropertyDateFloor -Property A -Minute 2 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:54:00 PM')
        }

        It 'Works with -Minute 10' {
            $time1 | Set-PropertyDateFloor -Property A -Minute 10 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:50:00 PM')
        }

        It 'Works with -Minute 15' {
            $time1 | Set-PropertyDateFloor -Property A -Minute 15 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:45:00 PM')
        }

        It 'Works with -Hour 1' {
            $time1 | Set-PropertyDateFloor -Property A -Hour 1 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:00:00 PM')
        }

        It 'Works with -Hour 2' {
            $time1 | Set-PropertyDateFloor -Property A -Hour 2 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 10:00:00 PM')
        }

        It 'Works with -Hour 6' {
            $time1 | Set-PropertyDateFloor -Property A -Hour 6 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 6:00:00 PM')
        }

        It 'Works with -Day' {
            $time1 | Set-PropertyDateFloor -Property A -Day |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 12:00:00 AM')
        }

        It 'Works with -Month' {
            $time1 | Set-PropertyDateFloor -Property A -Month |
                ForEach-Object A |
                Should Be ([datetime]'3/1/2019 12:00:00 AM')
        }

        It 'Works with two properties' {
            $result = $time1 | Set-PropertyDateFloor -Property A, B -Minute 30
            $result.A | Should Be ([datetime]"3/4/2019 11:30:00 PM")
            $result.B | Should Be ([datetime]"4/5/2019 4:30:00 AM")
        }

        It 'Works with ToNewProperty' {
            $time1 | Set-PropertyDateFloor -Property A -ToNewProperty New -Day |
                ForEach-Object New |
                Should Be ([datetime]'3/4/2019 12:00:00 AM')
        }
    }
}
