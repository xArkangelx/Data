Import-Module $PSScriptRoot\.. -DisableNameChecking -Force

Describe "Invoke-PipelineChunks" {

    Context 'Default' {

        It 'Works with empty input' {
            @() | Invoke-PipelineChunks -ChunkSize 10 -ScriptBlock { $input * -1 }
        }

        It 'Works with oversized chunks' {
            $result = 'a', 'b', 'c' | Invoke-PipelineChunks -ChunkSize 100 -ScriptBlock { $input | ForEach-Object ToUpper }
            $result -join ',' | Should Be 'A,B,C'
        }

        It 'Splits the pipeline into chunks' {
            $result = 1..10 | Invoke-PipelineChunks 7 { $input -join ',' }
            @($result).Count | Should Be 2
            $result[0] | Should Be '1,2,3,4,5,6,7'
            $result[1] | Should Be '8,9,10'
        }

        It 'Works with SingleChunk switch' {
            $result = 1..10 | Invoke-PipelineChunks -SingleChunk { $input -join ',' }
            @($result).Count | Should Be 1
            $result | Should Be '1,2,3,4,5,6,7,8,9,10'
        }

        It 'Can set a chunk number variable' {
            $result = 1..10 |
                Invoke-PipelineChunks 7 -ChunkNumberVariable cnum {
                    [pscustomobject]@{
                        Chunk = $cnum
                        Items = $input -join ','
                    }
                }

            $result[0].Chunk | Should Be 1
            $result[0].Items | Should Be '1,2,3,4,5,6,7'
            $result[1].Chunk | Should Be 2
            $result[1].Items | Should Be '8,9,10'
        }
    }
}
