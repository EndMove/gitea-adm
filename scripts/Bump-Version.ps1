[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [ValidatePattern('^r\d{2}$')]
    [string]$Revision = 'r01',

    [string]$Notes = '',

    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

function Get-ReplacedContent {
    <# Returns edited text only when exactly one marker exists, does not write files #>
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Replacement
    )

    $text = [IO.File]::ReadAllText($Path)
    if ([regex]::Matches($text, $Pattern).Count -ne 1) {
        throw "Expected one version marker in $Path"
    }

    return [regex]::Replace($text, $Pattern, $Replacement)
}

$packageVersion = "$Version.$Revision"
$config = Get-Content "$Root/CONTROL/config.json" -Raw | ConvertFrom-Json
$currentPackageVersion = $config.general.version
$currentVersion = (Get-Content "$Root/gitea_version" -Raw).Trim()
$currentRevision = [int]($currentPackageVersion -replace '^.*\.r', '')

if ([version]$Version -lt [version]$currentVersion) {
    throw 'Gitea version cannot go backwards.'
}
if ($Version -eq $currentVersion -and [int]$Revision.Substring(1) -le $currentRevision) {
    throw 'The package revision must increase when keeping the same Gitea version.'
}

# Capture groups retain surrounding text without reformatting entire files
$escapedVersion = [regex]::Escape($currentVersion)
$replacements = @(
    @{
        Path = 'CONTROL/config.json'
        Pattern = '("version"\s*:\s*")' + [regex]::Escape($currentPackageVersion) + '(")'
        Replacement = '${1}' + $packageVersion + '${2}'
    },
    @{
        Path = 'CONTROL/description-fr.txt'
        Pattern = '(Version actuelle de Gitea : )' + $escapedVersion
        Replacement = '${1}' + $Version
    },
    @{
        Path = 'CONTROL/description.txt'
        Pattern = '(Gitea current version: )' + $escapedVersion
        Replacement = '${1}' + $Version
    },
    @{
        Path = 'README.md'
        Pattern = '(__Gitea version__: _`)' + $escapedVersion + '(`_)'
        Replacement = '${1}' + $Version + '${2}'
    },
    @{
        Path = 'LICENSE'
        Pattern = 'Copyright \(C\) \d{4} EndMove'
        Replacement = "Copyright (C) $((Get-Date).Year) EndMove"
    }
)

# Validate every marker before writing. This prevents partial updates on validation
# errors, but does not make filesystem writes transactional
$updates = [ordered]@{}
foreach ($replacement in $replacements) {
    $parameters = @{
        Path = Join-Path $Root $replacement.Path
        Pattern = $replacement.Pattern
        Replacement = $replacement.Replacement
    }
    $updates[$replacement.Path] = Get-ReplacedContent @parameters
}
$updates['gitea_version'] = $Version

$changelog = [IO.File]::ReadAllText("$Root/CONTROL/changelog.txt")
if ($changelog -match "(?m)^Version $([regex]::Escape($packageVersion))\s*$") {
    throw 'Changelog entry already exists.'
}

$releaseUrl = "https://github.com/go-gitea/gitea/releases/tag/v$Version"
$entryLines = @(
    "Version $packageVersion"
    "- Update Gitea to $Version, release notes ($releaseUrl)."
)
if ($Notes.Trim()) {
    $entryLines += $Notes.Trim().Replace("`r`n", "`n")
}
$updates['CONTROL/changelog.txt'] = ($entryLines -join "`n") + "`n`n" + $changelog

$encoding = [Text.UTF8Encoding]::new($false)
foreach ($path in $updates.Keys) {
    [IO.File]::WriteAllText((Join-Path $Root $path), $updates[$path], $encoding)
}

Write-Host "Updated Gitea to $packageVersion"
