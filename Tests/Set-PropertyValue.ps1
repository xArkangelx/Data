foreach ($value in $true, $false)
{
    $Global:191cf922f94e46709f6b1818ae32f66b_ForceLoadPowerShellCmdlets = $value
    Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

    Describe "Set-PropertyValue" {

        Context "Default - PowerShell: $value" {
            It '-Property -Value' {
                [pscustomobject]@{A=1} |
                    Set-PropertyValue B 2 |
                    ForEach-Object B |
                    Should Be 2
            }

            It 'Clones' {
                $original = [pscustomobject]@{A=1}
                $new = $original | Set-PropertyValue B 2
                $new | Should Not Be $original
            }

            It '-NoClone' {
                [pscustomobject]@{A=1} |
                    Set-PropertyValue B 2 -NoClone |
                    ForEach-Object B |
                    Should Be 2
            }

            It "-Property -Value -NoClone" {
                $original = [pscustomobject]@{A=1}
                $new = $original | Set-PropertyValue B 2 -NoClone
                $new | Should Be $original
            }

            It "-Property -Value [ScriptBlock]" {
                [pscustomobject]@{A=3} |
                    Set-PropertyValue B { $_.A * 2 } |
                    ForEach-Object B |
                    Should Be 6
            }

            It "-Property -Value -IfUnset (When Unset)" {
                [pscustomobject]@{A=$null} |
                    Set-PropertyValue A 1 -IfUnset |
                    ForEach-Object A |
                    Should Be 1

                [pscustomobject]@{A=''} |
                    Set-PropertyValue A 1 -IfUnset |
                    ForEach-Object A |
                    Should Be 1

                [pscustomobject]@{A=' '} |
                    Set-PropertyValue A 1 -IfUnset |
                    ForEach-Object A |
                    Should Be 1
            }

            It "-Property -Value -IfUnset (When Set)" {
                [pscustomobject]@{A=3} |
                    Set-PropertyValue A 1 -IfUnset |
                    ForEach-Object A |
                    Should Be 3

                [pscustomobject]@{A=0} |
                    Set-PropertyValue A 1 -IfUnset |
                    ForEach-Object A |
                    Should Be 0
            }

            It "-Property -Value -Where [string]" {
                [pscustomobject]@{A=1} |
                    Set-PropertyValue B 2 -Where A |
                    ForEach-Object B |
                    Should Be 2

                [pscustomobject]@{A=0} |
                    Set-PropertyValue B 2 -Where A |
                    ForEach-Object B |
                    Should Be $null

                [pscustomobject]@{A=''} |
                    Set-PropertyValue B 2 -Where A |
                    ForEach-Object B |
                    Should Be $null

                [pscustomobject]@{A=$null} |
                    Set-PropertyValue B 2 -Where A |
                    ForEach-Object B |
                    Should Be $null

                [pscustomobject]@{A=' '} |
                    Set-PropertyValue B 2 -Where A |
                    ForEach-Object B |
                    Should Be 2
            }

            It "-Property -Value -Where [string] (Preserves Old)" {

                [pscustomobject]@{A=$null; B='old'} |
                    Set-PropertyValue B 2 -Where A |
                    ForEach-Object B |
                    Should Be 'old'
            }

            It "-Property -Value -Where [scriptblock]" {
                [pscustomobject]@{A=1} |
                    Set-PropertyValue B 2 -Where { $_.A } |
                    ForEach-Object B |
                    Should Be 2

                [pscustomobject]@{A=0} |
                    Set-PropertyValue B 2 -Where { $_.A } |
                    ForEach-Object B |
                    Should Be $null
            }

            It "-Property -Value [scriptblock] -Where [scriptblock] (Match)" {
                [pscustomobject]@{A="abc123def"} |
                    Set-PropertyValue B { $Matches[1] } -Where { $_.A -match "(\d+)" } |
                    ForEach-Object B |
                    Should Be 123

                [pscustomobject]@{A="abc123def"} |
                    Set-PropertyValue B { $Matches[1] } -Where { $_.A -match "xyz" } |
                    ForEach-Object B |
                    Should Be $null
            }
        }
    }
}