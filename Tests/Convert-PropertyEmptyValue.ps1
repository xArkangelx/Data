Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Convert-PropertyEmptyValue" {

    Context "Sanity checks" {
        It "Ignores empty/null input" {
            @(
                @() | Convert-PropertyEmptyValue -ToEmptyString
                $null | Convert-PropertyEmptyValue -ToEmptyString
            ) |
                Measure-Object |
                ForEach-Object Count |
                Should Be 0
        }
    }

    Context "Conversion tests" {

        It "Converts Null to Empty String" {

            $result = [pscustomobject]@{Value=$null} |
                Convert-PropertyEmptyValue -ToEmptyString

            $result.Value | Should Be ""
        }

        It "Converts DBNull to Empty String" {

            $result = [pscustomobject]@{Value=[System.DBNull]::Value} |
                Convert-PropertyEmptyValue -ToEmptyString

            $result.Value | Should Be ""
        }

        It "Converts @() to Empty String" {

            $result = [pscustomobject]@{Value=@()} |
                Convert-PropertyEmptyValue -ToEmptyString

            $result.Value | Should Be ""
        }

        It "Converts whitespace to Empty String" {

            $result = [pscustomobject]@{Value=" "} |
                Convert-PropertyEmptyValue -ToEmptyString

            $result.Value | Should Be ""
        }

        It "Converts whitespace to null" {

            $result = [pscustomobject]@{Value=" "} |
                Convert-PropertyEmptyValue -ToNull

            @($result).Count | Should Be 1
            $result[0].PSObject.Properties.Name | Should Be 'Value'
            $result[0].Value | Should Be $null
        }
               
        It "Converts whitespace to specific values" {

            $result = [pscustomobject]@{Value=" "} |
                Convert-PropertyEmptyValue -ToValue 'Unset'

            $result.Value | Should Be "Unset"
        }
    }

    Context "Property Tests" {
        It "Can be limited to specific properties" {
            $result = [pscustomobject]@{A=1; B=$null; C=''; D=''; E=2} |
                Convert-PropertyEmptyValue A, B, C -ToValue Empty
            $result.A | Should Be 1
            $result.B | Should Be "Empty"
            $result.C | Should Be "Empty"
            $result.D | Should Be ""
            $result.E | Should Be 2
        }
    }
}

return

# ================================================================================
# Performance Reasonings

# ================================================================================
# Question: Does a switch property need to be accessed with IsPresent?
# Why: To shorten code

$switchValue = [switch]$false

Measure-Command {
    for ($i = 0; $i -lt 100000; $i++)
    {
        if ($switchValue) { 1/0 }
    }
}

Measure-Command {
    for ($i = 0; $i -lt 100000; $i++)
    {
        if ($switchValue.IsPresent) { 1/0 }
    }
}

# Answer: 300 ms vs 250 ms
# Verdict: It does sort of matter, though we're not doing it inside a loop right now
