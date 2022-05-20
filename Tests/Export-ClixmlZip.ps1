Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Export-ClixmlZip" {

    Context 'Default' {

        $tempFilePath = [System.IO.Path]::GetTempFileName()

        It 'Exports and imports' {
            $object = [pscustomobject]@{
                Int = 1
                Timestamp = [DateTime]::UtcNow
                SubObject = @{
                    A = 'Ahhh'
                }
            }

            $object | Export-ClixmlZip $tempFilePath

            $rehydrated = Import-ClixmlZip $tempFilePath

            $rehydrated.Int | Should Be $object.Int
            $rehydrated.Timestamp | Should Be $object.Timestamp
            $rehydrated.SubObject.A | Should Be $object.SubObject.A
        }

        [System.IO.File]::Delete($tempFilePath)
    }
}
