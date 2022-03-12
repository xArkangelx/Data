Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertyDateTimeFloor" {

    $time1 = [pscustomobject]@{A=[datetime]"3/4/2019 11:55:45.123 PM"; B=[Datetime]"4/5/2019 4:30:15 AM"}

    Context 'Default' {
        It 'Passes nothing with null input' {
            $out = $null | Set-PropertyDateTimeFloor -Property Nothing -Hour 1
            $out.Count | Should Be 0
        }

        It 'Ignores null values' {
            $result = [pscustomobject]@{A=$null} |
                Set-PropertyDateTimeFloor A -Day
            $result.A | Should Be $null
        }

        It 'Ignores empty strings' {
            $result = [pscustomobject]@{A=''} |
                Set-PropertyDateTimeFloor A -Day
            $result.A | Should Be ''
        }

        It 'Works with -Second 1' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Second 1 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:45 PM')
        }

        It 'Works with -Second 2' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Second 2 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:44 PM')
        }

        It 'Works with -Second 10' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Second 10 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:40 PM')
        }

        It 'Works with -Second 15' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Second 15 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:45 PM')
        }

        It 'Works with -Minute 1' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Minute 1 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:00 PM')
        }

        It 'Works with -Minute 2' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Minute 2 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:54:00 PM')
        }

        It 'Works with -Minute 10' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Minute 10 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:50:00 PM')
        }

        It 'Works with -Minute 15' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Minute 15 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:45:00 PM')
        }

        It 'Works with -Hour 1' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Hour 1 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:00:00 PM')
        }

        It 'Works with -Hour 2' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Hour 2 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 10:00:00 PM')
        }

        It 'Works with -Hour 6' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Hour 6 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 6:00:00 PM')
        }

        It 'Works with -Day' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Day |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 12:00:00 AM')
        }

        It 'Works with -Month' {
            $time1 | Set-PropertyDateTimeFloor -Property A -Month |
                ForEach-Object A |
                Should Be ([datetime]'3/1/2019 12:00:00 AM')
        }

        It 'Works with -Months' {
            $result = [pscustomobject]@{A="1/2/2019"; B="2/3/2019"; C="3/4/2019"; D="4/5/2019"; E="6/1/2019"; F="12/4/2019"} |
                Set-PropertyDateTimeFloor -Property A, B, C, D, E, F -Months 2
            $result.A | Should Be ([datetime]"1/1/2019")
            $result.B | Should Be ([datetime]"1/1/2019")
            $result.C | Should Be ([datetime]"3/1/2019")
            $result.D | Should Be ([datetime]"3/1/2019")
            $result.E | Should Be ([datetime]"5/1/2019")
            $result.F | Should Be ([datetime]"11/1/2019")

        }

        It 'Works with two properties' {
            $result = $time1 | Set-PropertyDateTimeFloor -Property A, B -Minute 30
            $result.A | Should Be ([datetime]"3/4/2019 11:30:00 PM")
            $result.B | Should Be ([datetime]"4/5/2019 4:30:00 AM")
        }

        It 'Works with ToNewProperty' {
            $time1 | Set-PropertyDateTimeFloor -Property A -ToNewProperty New -Day |
                ForEach-Object New |
                Should Be ([datetime]'3/4/2019 12:00:00 AM')
        }

        It 'Works with -Format' {
            $result = [pscustomobject]@{A="1/1/2019 12:33:00 PM"} |
                Set-PropertyDateTimeFloor A -Minute 30 -Format 'yyyy-MM-dd HH:mm:ss'
            $result.A | Should Be '2019-01-01 12:30:00'
        }
    }

    Context 'Alias' {
        It 'Works with -Second 1' {
            $time1 | Set-PropertyDateFloor -Property A -Second 1 |
                ForEach-Object A |
                Should Be ([datetime]'3/4/2019 11:55:45 PM')
        }
    }
}
