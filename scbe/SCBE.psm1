#Requires -Version 5.1
<#
.SYNOPSIS
    SCBE tools for PowerShell — discover the SCBE CLI tool surface, run a tool,
    and expose the whole catalog to AI assistants over MCP.

.DESCRIPTION
    Bundled with the PowerShellSCBE fork under scbe/. Reads scbe/manifest.json
    (the catalog of every scbe command) and bridges to the real scbe CLI.

    Set the path to your SCBE checkout once per session to enable execution:
        $env:SCBE_CLI  = 'C:\path\to\scbe-aethermoore\scbe.py'   # or...
        $env:SCBE_REPO = 'C:\path\to\scbe-aethermoore'

    Discovery (Get-ScbeManifest) works offline from the bundled manifest.json
    even before SCBE_CLI is set.

.EXAMPLE
    Import-Module ./scbe/SCBE.psm1
    Get-ScbeManifest -Names            # list all tool paths
    Invoke-ScbeTool -Name score -ArgumentList 'find me a prime'
    Test-ScbeMcp                       # MCP self-test
    Start-ScbeMcp                      # run the MCP server for an AI client
#>

$script:ScbeRoot     = $PSScriptRoot
$script:ScbeManifest = Join-Path $PSScriptRoot 'manifest.json'
$script:ScbeServer   = Join-Path $PSScriptRoot 'scbe_cli_server.py'

function Resolve-ScbeCli {
    <#  .SYNOPSIS  Resolve the path to scbe.py from SCBE_CLI / SCBE_REPO, or $null. #>
    [CmdletBinding()]
    param()
    if ($env:SCBE_CLI -and (Test-Path $env:SCBE_CLI)) { return $env:SCBE_CLI }
    if ($env:SCBE_REPO) {
        $candidate = Join-Path $env:SCBE_REPO 'scbe.py'
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Get-ScbeManifest {
    <#  .SYNOPSIS  Read the bundled SCBE tool catalog. Use -Names for just the tool paths. #>
    [CmdletBinding()]
    param([switch]$Names)
    if (-not (Test-Path $script:ScbeManifest)) {
        throw "SCBE manifest not found: $script:ScbeManifest"
    }
    $manifest = Get-Content -Raw -Path $script:ScbeManifest | ConvertFrom-Json
    if ($Names) { return $manifest.tools | ForEach-Object { $_.path } }
    return $manifest
}

function Invoke-ScbeTool {
    <#  .SYNOPSIS  Run one SCBE tool by name (e.g. 'score' or 'chem atomize') via the real CLI. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$ArgumentList,
        [switch]$Json
    )
    $cli = Resolve-ScbeCli
    if (-not $cli) {
        throw 'Set $env:SCBE_CLI to your scbe.py path (or $env:SCBE_REPO to the repo root).'
    }
    $parts = $Name -split '\s+'           # 'chem atomize' -> @('chem','atomize')
    $argv = @($cli) + $parts + $ArgumentList
    if ($Json) { $argv += '--json' }
    & python @argv
}

function Start-ScbeMcp {
    <#  .SYNOPSIS  Run the SCBE MCP server (stdio) so an AI client can call the tools. #>
    [CmdletBinding()]
    param()
    if (-not (Test-Path $script:ScbeServer)) { throw "SCBE MCP server not found: $script:ScbeServer" }
    & python $script:ScbeServer
}

function Test-ScbeMcp {
    <#  .SYNOPSIS  Run the MCP server self-test (lists tools; executes one if SCBE_CLI is set). #>
    [CmdletBinding()]
    param()
    if (-not (Test-Path $script:ScbeServer)) { throw "SCBE MCP server not found: $script:ScbeServer" }
    & python $script:ScbeServer --self-test
}

Export-ModuleMember -Function Resolve-ScbeCli, Get-ScbeManifest, Invoke-ScbeTool, Start-ScbeMcp, Test-ScbeMcp
