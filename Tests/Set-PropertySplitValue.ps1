Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertySplitValue" {

    Context 'Default' {
        It 'Works' {
            [pscustomobject]@{A='1+2+3'} |
                Set-PropertySplitValue A '\+' |
                ForEach-Object { $_.A -join '/' } |
                Should Be '1/2/3'
        }
    }
}
