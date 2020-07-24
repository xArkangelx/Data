Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertyDateTimeFormat" {
    
    $time1 = [pscustomobject]@{A=[datetime]"3/4/2019 11:55:45.123 PM"; B=[Datetime]"4/5/2019 4:30:15 AM"}

    Context 'Default' {
        It 'Passes nothing with null input' {
            $out = $null | Set-PropertyDateTimeFormat Nothing 'yyyy-MM-dd HH:mm:ss'
            $out.Count | Should Be 0
        }

        It 'Works' {
            $timestamp = [DateTime]::Now
            $result = [pscustomobject]@{A=1;Timestamp=$timestamp} |
                Set-PropertyDateTimeFormat Timestamp 'yyyy-MM-dd HH:mm:ss dddd h tt'

            $result.A | Should Be 1
            $result.Timestamp | Should Be ($timestamp.ToString('yyyy-MM-dd HH:mm:ss dddd h tt'))
        }

        It 'Works with AppendTimeZone Short' {
            [pscustomobject]@{Date="1/1/2020"} |
                Set-PropertyDateTimeFormat Date yyyy-MM-dd -AppendTimeZone Short
        }

        It 'Works with AppendTimeZone Long' {
            [pscustomobject]@{Date="1/1/2020"} |
                Set-PropertyDateTimeFormat Date yyyy-MM-dd -AppendTimeZone Long
        }
    }
}
