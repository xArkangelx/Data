Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Get-IndentedText" {
    Context "Basic Tests" {
        It "Works" {
            "abc" | Get-IndentedText | Should Be "    abc"
        }

        It "Handles Empty Lines" {
            $result = @(
                "Function Test"
                "{"
                ""
                "    Write-Host Test"
                ""
                "}"
            ) -join "`r`n" | Get-IndentedText

            $expected = @(
                "    Function Test"
                "    {"
                ""
                "        Write-Host Test"
                ""
                "    }"
            ) -join "`r`n"

            $result | Should Be $expected
        }

        It "Handles Null" {
            $null | Get-IndentedText | Should Be ''
        }
    }
}
