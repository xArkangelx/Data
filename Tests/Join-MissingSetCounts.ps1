Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Join-MissingSetCounts" {

    Context 'Default' {
        It 'Handles Empty Data 1 Set' {
            $csv = Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Count"
                "A","0"
                "B","0"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Handles Empty Data 2 Sets' {
            $csv = Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Set2Property Prop2 -Set2Values X, Y |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Prop2","Count"
                "A","X","0"
                "A","Y","0"
                "B","X","0"
                "B","Y","0"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Inserts Data 1 Set' {
            $csv = [pscustomobject]@{Prop1='A';Count=1} |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Count"
                "A","1"
                "B","0"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Inserts Data 2 Sets' {
            $csv = @([pscustomobject]@{Prop1='A';Prop2='X';Count=1};[pscustomobject]@{Prop1='B';Prop2='Y';Count=2}) |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Set2Property Prop2 -Set2Values X, Y |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Prop2","Count"
                "A","X","1"
                "A","Y","0"
                "B","X","0"
                "B","Y","2"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Passes Data 1 Set A' {
            $csv = @([pscustomobject]@{Prop1='A';Count=1};[pscustomobject]@{Prop1='C';Count=3};) |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Count"
                "A","1"
                "B","0"
                "C","3"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Passes Data 1 Set B' {
            $csv = [pscustomobject]@{Prop1='C';Count=3} |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Count"
                "A","0"
                "B","0"
                "C","3"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Passes Data 2 Sets A' {
            $csv = @([pscustomobject]@{Prop1='A';Prop2='X';Count=1};[pscustomobject]@{Prop1='B';Prop2='W';Count=2}) |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Set2Property Prop2 -Set2Values X, Y |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Prop2","Count"
                "A","X","1"
                "A","Y","0"
                "A","W","0"
                "B","X","0"
                "B","Y","0"
                "B","W","2"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Passes Data 2 Sets B' {
            $csv = [pscustomobject]@{Prop1='B';Prop2='W';Count=2} |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Set2Property Prop2 -Set2Values X, Y |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Prop2","Count"
                "A","X","0"
                "A","Y","0"
                "A","W","0"
                "B","X","0"
                "B","Y","0"
                "B","W","2"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Filters Data 1 Set A' {
            $csv = @([pscustomobject]@{Prop1='A';Count=1};[pscustomobject]@{Prop1='C';Count=3};) |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Mode SortAndFilter |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Count"
                "A","1"
                "B","0"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Passes Data 1 Set B' {
            $csv = [pscustomobject]@{Prop1='C';Count=3} |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Mode SortAndFilter |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Count"
                "A","0"
                "B","0"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Filters Data 2 Sets A' {
            $csv = @([pscustomobject]@{Prop1='A';Prop2='X';Count=1};[pscustomobject]@{Prop1='B';Prop2='W';Count=2}) |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Set2Property Prop2 -Set2Values X, Y -Mode SortAndFilter |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Prop2","Count"
                "A","X","1"
                "A","Y","0"
                "B","X","0"
                "B","Y","0"
            '.Trim().Replace(' ','').Replace("`r","")
        }
        It 'Filters Data 2 Sets B' {
            $csv = [pscustomobject]@{Prop1='B';Prop2='W';Count=2} |
                Join-MissingSetCounts -Set1Property Prop1 -Set1Values A, B -Set2Property Prop2 -Set2Values X, Y -Mode SortAndFilter |
                ConvertTo-Csv -NoTypeInformation
            $csv -join "`n" | Should Be '
                "Prop1","Prop2","Count"
                "A","X","0"
                "A","Y","0"
                "B","X","0"
                "B","Y","0"
            '.Trim().Replace(' ','').Replace("`r","")
        }
    }
}
