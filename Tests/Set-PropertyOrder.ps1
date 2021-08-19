Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertyOrder" {
    
    Context 'Default' {
        It 'Works with default positional parameters' {
            $result = [pscustomobject]@{C=1; D=2; A=3; B=4; Z=5; Y=6} |
                Set-PropertyOrder A, B
            $result.PSObject.Properties.Name -join ',' | Should Be 'A,B,C,D,Z,Y'
        }

        It 'Works with End parameter' {
            $result = [pscustomobject]@{C=1; D=2; A=3; B=4; Z=5; Y=6} |
                Set-PropertyOrder -End A, B
            $result.PSObject.Properties.Name -join ',' | Should Be 'C,D,Z,Y,A,B'
        }

        It 'Works with Begin and End together' {
            $result = [pscustomobject]@{C=1; D=2; A=3; B=4; Z=5; Y=6} |
                Set-PropertyOrder -Begin A -End Z
            $result.PSObject.Properties.Name -join ',' | Should Be 'A,C,D,B,Y,Z'
        }
    }
}
