Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertyDateTimeBreakpoint" {

    Function DefineTimeSpan($Span,$Expected)
    {
        $spanDict[[TimeSpan]::Parse($Span)] = $Expected
    }

    Context 'Default' {

        It 'Works with all time types (datetime)' {

            $spanDict = [ordered]@{}

            DefineTimeSpan 0.00:01 "0 - 15 Minutes"
            DefineTimeSpan 0.00:15 "0 - 15 Minutes"
            DefineTimeSpan 0.00:30 "15 Minutes - 30 Minutes"
            DefineTimeSpan 0.01:00 "30 Minutes - 1 Hour"
            DefineTimeSpan 0.02:00 "1 Hour - 5 Hours"
            DefineTimeSpan 0.03:00 "1 Hour - 5 Hours"
            DefineTimeSpan 0.05:00 "1 Hour - 5 Hours"
            DefineTimeSpan 0.10:00 "5 Hours - 10 Hours"
            DefineTimeSpan 0.11:00 "10 Hours - 11 Hours"
            DefineTimeSpan 0.15:00 "12 Hours - 1 Day"
            DefineTimeSpan 1.15:00 "1 Day - 2 Days"
            DefineTimeSpan 2.1:00 "2 Days - 1 Week"
            DefineTimeSpan 3.0:00 "2 Days - 1 Week"
            DefineTimeSpan 10.0:00 "1 Week - 2 Weeks"
            DefineTimeSpan 11.0:00 "1 Week - 2 Weeks"
            DefineTimeSpan 15.0:00 "2 Weeks - 1 Month"
            DefineTimeSpan 31.0:00 "2 Weeks - 1 Month"
            DefineTimeSpan 32.0:00 "1 Month - 2 Months"
            DefineTimeSpan 70.0:00 "2 Months - 1 Year"
            DefineTimeSpan 400.0:00 "Over 1 Year"

            $resultList = $spanDict.GetEnumerator() |
                ForEach-Object {
                    [pscustomobject]@{
                        Timestamp = [DateTime]::Now - $_.Key
                        ExpectedLabel = $_.Value
                    }
                } |
                Set-PropertyDateTimeBreakpoint -Property Timestamp -ToNewProperty Label -Minutes 15, 30 -Hours 1, 5, 10, 11, 12 -Days 1, 2 -Weeks 1, 2 -Months 1, 2 -Years 1

            foreach ($result in $resultList)
            {
                $result.Label | Should Be $result.ExpectedLabel
            }
        }

        It 'Works with all time types (timespan)' {

            $spanDict = [ordered]@{}

            DefineTimeSpan 0.00:01 "0 - 15 Minutes"
            DefineTimeSpan 0.00:15 "0 - 15 Minutes"
            DefineTimeSpan 0.00:30 "15 Minutes - 30 Minutes"
            DefineTimeSpan 0.01:00 "30 Minutes - 1 Hour"
            DefineTimeSpan 0.02:00 "1 Hour - 5 Hours"
            DefineTimeSpan 0.03:00 "1 Hour - 5 Hours"
            DefineTimeSpan 0.05:00 "1 Hour - 5 Hours"
            DefineTimeSpan 0.10:00 "5 Hours - 10 Hours"
            DefineTimeSpan 0.11:00 "10 Hours - 11 Hours"
            DefineTimeSpan 0.15:00 "12 Hours - 1 Day"
            DefineTimeSpan 1.15:00 "1 Day - 2 Days"
            DefineTimeSpan 2.1:00 "2 Days - 1 Week"
            DefineTimeSpan 3.0:00 "2 Days - 1 Week"
            DefineTimeSpan 10.0:00 "1 Week - 2 Weeks"
            DefineTimeSpan 11.0:00 "1 Week - 2 Weeks"
            DefineTimeSpan 15.0:00 "2 Weeks - 1 Month"
            DefineTimeSpan 31.0:00 "2 Weeks - 1 Month"
            DefineTimeSpan 32.0:00 "1 Month - 2 Months"
            DefineTimeSpan 70.0:00 "2 Months - 1 Year"
            DefineTimeSpan 400.0:00 "Over 1 Year"

            $resultList = $spanDict.GetEnumerator() |
                Select-Object Name, Value |
                Set-PropertyDateTimeBreakpoint -Property Name -ToNewProperty Label -Minutes 15, 30 -Hours 1, 5, 10, 11, 12 -Days 1, 2 -Weeks 1, 2 -Months 1, 2 -Years 1

            foreach ($result in $resultList)
            {
                $result.Label | Should Be $result.Value
            }
        }
    }
}
