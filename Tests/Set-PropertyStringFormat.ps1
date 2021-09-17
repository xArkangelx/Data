Import-Module Pester -RequiredVersion 3.4.0
Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Set-PropertyStringFormat" {

    Context 'Default' {

        It 'Passes nothing with null input' {
            $result = $null | Set-PropertyStringFormat Size "{0:n2} MB"
            $result.Count | Should Be 0
        }

        It 'Ignores null values' {
            $result = [pscustomobject]@{Size=$null} |
                Set-PropertyStringFormat Size "{0:n2} MB"
            $result.Size | Should Be $null
        }

        It 'Ignores empty strings' {
            $result = [pscustomobject]@{Size=''} |
                Set-PropertyStringFormat Size "{0:n2} MB"
            $result.Size | Should Be ''
        }

        It 'Formats properties' {
            $result = [pscustomobject]@{Size=2000} |
                Set-PropertyStringFormat Size "{0:n2} MB"
            $result.Size | Should Be "2,000.00 MB"
        }

        It 'Can divide' {
            $result = [pscustomobject]@{Size=1.5GB} |
                Set-PropertyStringFormat Size "{0:n3} GB" -DivideBy 1GB
            $result.Size | Should Be "1.500 GB"
        }

        It 'Formats multiple properties' {
            $result = [pscustomobject]@{FileSize=3000; FolderSize=4000} |
                Set-PropertyStringFormat FileSize, FolderSize "{0:n0} MB"

            $result.FileSize | Should Be "3,000 MB"
            $result.FolderSize | Should Be "4,000 MB"
        }
    }
}
