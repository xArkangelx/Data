Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Convert-DateTimeZone" {

    Context 'Conversions' {
        It 'Sanity check for local not being utc' {
            $local = [DateTime]::Now
            $utc = $local.ToUniversalTime()
            $local -eq $utc | Should Be $false
        }

        It 'Converts Local to UTC' {
            $local = [DateTime]::Now
            $result = [pscustomobject]@{Time=$local} | Convert-DateTimeZone Time -FromLocal -ToUtc
            $result.Time | Should Be $local.ToUniversalTime()
        }

        It 'Converts UTC to Local' {
            $utc = [DateTime]::UtcNow
            $result = [pscustomobject]@{Time=$utc} | Convert-DateTimeZone Time -FromUtc -ToLocal
            $result.Time | Should Be $utc.ToLocalTime()
        }

        It 'Gracefully handles null values' {
            $result = [pscustomobject]@{Time=$null} | Convert-DateTimeZone Time -FromUtc -ToLocal
            $result.Time | Should Be $null
        }

        It 'Gracefully handles empty strings' {
            $result = [pscustomobject]@{Time=''} | Convert-DateTimeZone Time -FromUtc -ToLocal
            $result.Time | Should Be $null
        }
    }

    Context 'Format' {

        It 'Can also format as string' {
            $local = [DateTime]::Now
            $result = [pscustomobject]@{Time=$local} | Convert-DateTimeZone Time -FromLocal -ToUtc -Format 'yyyy-MM-dd HH:mm:ss'
            $result.Time | Should Be $local.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
        }

        It 'Can also format as string and append long time zone (UTC)' {
            $local = [DateTime]::Now
            $result = [pscustomobject]@{Time=$local} | Convert-DateTimeZone Time -FromLocal -ToUtc -Format 'yyyy-MM-dd HH:mm:ss' -AppendTimeZone Long
            $result.Time | Should Be "$($local.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC"
        }
    }
}
