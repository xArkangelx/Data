Get-ChildItem $PSScriptRoot\Tests -File |
    ForEach-Object { & $_.FullName }