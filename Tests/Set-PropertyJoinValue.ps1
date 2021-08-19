Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertyJoinValue" {

    Context 'Default' {
        It 'Works' {
            [pscustomobject]@{A=1,2,3} |
                Set-PropertyJoinValue A '+' |
                ForEach-Object A |
                Should Be '1+2+3'
        }
    }
}
