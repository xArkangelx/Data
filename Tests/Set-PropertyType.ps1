Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertyType" {

    Context 'Default' {
        It 'Converts Double to Int' {
            $result = [pscustomobject]@{
                A = 1.1
                B = 2.6
            } | Set-PropertyType A, B Int
            $result.A | Should Be 1
            $result.B | Should Be 3
            $result.A.GetType() | Should Be ([int])
        }

        It 'Converts String to Int' {
            $result = [pscustomobject]@{String='5'} |
                Set-PropertyType String Int
            $result.String | Should Be 5
            $result.String.GetType() | Should Be ([int])
        }

        It 'Converts String to DateTime' {
            $result = [pscustomobject]@{Date="1/1/2020"} |
                Set-PropertyType Date DateTime

            $result.Date | Should Be ([datetime]"1/1/2020")
            $result.Date.GetType() | Should Be ([datetime])
        }

        It 'Converts String to Double' {
            $result = [pscustomobject]@{Value="1.51"} |
                Set-PropertyType Value Double
            $result.Value | Should Be 1.51
            $result.Value.GetType() | Should Be ([double])
        }

        It 'Converts Int to String' {
            $result = [pscustomobject]@{Value=9} |
                Set-PropertyType Value String
            $result.Value | Should Be "9"
            $result.Value.GetType() | Should Be ([string])
        }

        It 'Errors when it can''t convert' {
            trap { 'OK' | Should Be 'OK'; return }
            $result = [pscustomobject]@{Value="Testing"} |
                Set-PropertyType Value DateTime -ErrorAction Stop
            throw "Did not throw an exception!"
        }

        It 'Can have errors suppressed' {
            $result = [pscustomobject]@{Value="Testing"} |
                Set-PropertyType Value DateTime -ErrorAction Ignore
            'OK' | Should Be 'OK'
        }

        It 'Works with DateTime::ParseExact' {
            $result = [pscustomobject]@{Value="201101-120156"} |
                Set-PropertyType Value DateTime -ParseExact 'yyMMdd-mmHHss'
            $result.Value | Should Be ([datetime]"2020-11-01 01:12:56")
        }
    }
}
