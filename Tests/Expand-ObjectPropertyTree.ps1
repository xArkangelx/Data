Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Expand-ObjectPropertyTree" {

    Context 'Default' {

        It 'Walks a simple object' {
            $result = [pscustomobject]@{A=1; B=2} |
                Expand-ObjectPropertyTree

            $result[0].IndexedPath | Should Be "/A"
            $result[0].NamedPath | Should Be "/A"
            $result[0].Value | Should Be 1

            $result[1].IndexedPath | Should Be "/B"
            $result[1].NamedPath | Should Be "/B"
            $result[1].Value | Should Be 2
        }

        It 'Walks a complex object' {
            $result = [pscustomobject]@{A=1; B=[pscustomobject]@{C=3;D=4}} |
                Expand-ObjectPropertyTree

            $result[0].IndexedPath | Should Be "/A"
            $result[0].NamedPath | Should Be "/A"
            $result[0].Value | Should Be 1

            $result[1].IndexedPath | Should Be "/B/C"
            $result[1].NamedPath | Should Be "/B/C"
            $result[1].Value | Should Be 3

            $result[2].IndexedPath | Should Be "/B/D"
            $result[2].NamedPath | Should Be "/B/D"
            $result[2].Value | Should Be 4
        }

        It 'Indexes simple arrays' {
            $result = [pscustomobject]@{A=9,10;B=5} |
                Expand-ObjectPropertyTree

            $result[0].IndexedPath | Should Be "/A[0]"
            $result[0].NamedPath | Should Be "/A"
            $result[0].Value | Should Be 9

            $result[1].IndexedPath | Should Be "/A[1]"
            $result[1].NamedPath | Should Be "/A"
            $result[1].Value | Should Be 10

            $result[2].IndexedPath | Should Be "/B"
            $result[2].NamedPath | Should Be "/B"
            $result[2].Value | Should Be 5
        }

        It 'Indexes complex arrays' {
            $result = [pscustomobject]@{A='One'; B=@(
                [pscustomobject]@{Level='One'}
                [pscustomobject]@{Level='Two'; Properties=2; Array='a','b'}
            )} |
                Expand-ObjectPropertyTree

            $result[0].IndexedPath | Should Be "/A"
            $result[0].NamedPath | Should Be "/A"
            $result[0].Value | Should Be 'One'

            $result[1].IndexedPath | Should Be "/B[0]/Level"
            $result[1].NamedPath | Should Be "/B/Level"
            $result[1].Value | Should Be 'One'

            $result[2].IndexedPath | Should Be "/B[1]/Level"
            $result[2].NamedPath | Should Be "/B/Level"
            $result[2].Value | Should Be 'Two'

            $result[3].IndexedPath | Should Be "/B[1]/Properties"
            $result[3].NamedPath | Should Be "/B/Properties"
            $result[3].Value | Should Be 2

            $result[4].IndexedPath | Should Be "/B[1]/Array[0]"
            $result[4].NamedPath | Should Be "/B/Array"
            $result[4].Value | Should Be 'a'

            $result[5].IndexedPath | Should Be "/B[1]/Array[1]"
            $result[5].NamedPath | Should Be "/B/Array"
            $result[5].Value | Should Be 'b'
        }
    }
}
