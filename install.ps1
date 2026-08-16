[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceFolder = Join-Path $packageRoot "midjourney-prompt"

if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $codexRoot = Join-Path $env:USERPROFILE ".codex"
} else {
    $codexRoot = $env:CODEX_HOME
}

$skillsRoot = Join-Path $codexRoot "skills"
$targetFolder = Join-Path $skillsRoot "midjourney-prompt"
$legacyFolder = Join-Path $skillsRoot "midjourney-v8-1-prompt"
$sourceSkill = Join-Path $sourceFolder "SKILL.md"

if (-not (Test-Path -LiteralPath $sourceSkill -PathType Leaf)) {
    throw "The package is incomplete. Missing: $sourceSkill"
}
if (Test-Path -LiteralPath $targetFolder) {
    throw "An existing skill was found at: $targetFolder`nClose Codex, back up or rename that folder, and run this installer again."
}

New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
$createdTarget = $false
try {
    Copy-Item -LiteralPath $sourceFolder -Destination $targetFolder -Recurse
    $createdTarget = $true

    $requiredRelativeFiles = @(
        "SKILL.md",
        "agents\openai.yaml",
        "scripts\search-prompts.ps1",
        "scripts\lint-prompt.ps1",
        "scripts\validate-artifact.ps1",
        "references\manifest.json",
        "references\query-lexicon.json",
        "references\retrieval-policy.md",
        "references\version-parameters.md",
        "references\YOUMIND-LICENSE.txt",
        "tests\search-cases.json",
        "tests\lint-cases.json",
        "tests\forward-prompts.json"
    )
    foreach ($relative in $requiredRelativeFiles) {
        $requiredFile = Join-Path $targetFolder $relative
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            throw "Post-install validation failed. Missing: $requiredFile"
        }
    }

    $manifestPath = Join-Path $targetFolder "references\manifest.json"
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
    $ids = [Collections.Generic.HashSet[string]]::new()
    $rowCount = 0
    foreach ($category in @($manifest.categories)) {
        $categoryPath = Join-Path (Join-Path $targetFolder 'references') ([string]$category.file)
        $records = Get-Content -Raw -Encoding UTF8 -LiteralPath $categoryPath | ConvertFrom-Json
        if (@($records).Count -ne [int]$category.count) {
            throw "Post-install validation failed. Category count mismatch: $($category.slug)"
        }
        foreach ($record in $records) {
            $rowCount++
            [void]$ids.Add([string]$record.id)
        }
    }
    if ($rowCount -ne [int]$manifest.totalRows) {
        throw "Post-install validation failed. Row count $rowCount does not match $($manifest.totalRows)."
    }
    if ($ids.Count -ne [int]$manifest.totalPrompts) {
        throw "Post-install validation failed. Unique ID count $($ids.Count) does not match $($manifest.totalPrompts)."
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $sourceFolder -Recurse -File)
    foreach ($sourceFile in $sourceFiles) {
        $relative = $sourceFile.FullName.Substring($sourceFolder.Length).TrimStart('\')
        $targetFile = Join-Path $targetFolder $relative
        if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
            throw "Post-install hash validation failed. Missing target file: $relative"
        }
        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFile.FullName).Hash
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $targetFile).Hash
        if ($sourceHash -ne $targetHash) {
            throw "Post-install hash validation failed: $relative"
        }
    }

    Write-Host ""
    Write-Host "Installation completed: $targetFolder" -ForegroundColor Green
    Write-Host "Local corpus: $($manifest.totalPrompts) unique prompts, $($manifest.totalRows) category rows, $(@($manifest.categories).Count) categories" -ForegroundColor Green
    Write-Host "Integrity: $($sourceFiles.Count) files copied with matching SHA-256 hashes" -ForegroundColor Green
    Write-Host "Restart Codex, then invoke the skill with:" -ForegroundColor Yellow
    if (Test-Path -LiteralPath $legacyFolder) {
        Write-Host "Legacy Skill still exists and may trigger ambiguously: $legacyFolder" -ForegroundColor Yellow
        Write-Host "After verifying this installation, move or remove the legacy folder." -ForegroundColor Yellow
    }
    Write-Host '$midjourney-prompt cinematic portrait for a vertical social post' -ForegroundColor Cyan
} catch {
    $message = $_.Exception.Message
    if ($createdTarget -and (Test-Path -LiteralPath $targetFolder)) {
        Remove-Item -LiteralPath $targetFolder -Recurse -Force
    }
    throw "$message`nThe incomplete new installation was removed."
}
