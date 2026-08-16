[CmdletBinding()]
param(
    [switch]$SkipSearchTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$skillRoot = Split-Path -Parent $PSScriptRoot
$refsDir = Join-Path $skillRoot 'references'
$testsDir = Join-Path $skillRoot 'tests'
$searchScript = Join-Path $PSScriptRoot 'search-prompts.ps1'
$lintScript = Join-Path $PSScriptRoot 'lint-prompt.ps1'
$manifestPath = Join-Path $refsDir 'manifest.json'
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0

function Add-Pass { $script:passed++ }
function Add-Failure([string]$Message) { $script:failures.Add($Message) }

$requiredFiles = @(
    'SKILL.md', 'agents\openai.yaml', 'references\manifest.json',
    'references\v8-1-parameters.md', 'references\retrieval-policy.md',
    'references\query-lexicon.json', 'references\YOUMIND-LICENSE.txt',
    'scripts\search-prompts.ps1', 'scripts\lint-prompt.ps1',
    'tests\search-cases.json', 'tests\lint-cases.json', 'tests\forward-prompts.json'
)
foreach ($relative in $requiredFiles) {
    if (Test-Path -LiteralPath (Join-Path $skillRoot $relative) -PathType Leaf) { Add-Pass }
    else { Add-Failure "missing_file:$relative" }
}

try {
    $skillText = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes((Join-Path $skillRoot 'SKILL.md')))
    if ($skillText -match '(?s)^---\r?\nname: midjourney-v8-1-prompt\r?\ndescription: [^\r\n]+\r?\n---') { Add-Pass }
    else { Add-Failure 'invalid_skill_frontmatter' }
    if (($skillText -split "`n").Count -lt 500) { Add-Pass } else { Add-Failure 'skill_md_exceeds_500_lines' }
} catch { Add-Failure "skill_utf8_or_read_error:$($_.Exception.Message)" }

try {
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
    $ids = [Collections.Generic.HashSet[string]]::new()
    $rows = 0
    $bad = 0
    $uniqueReference = 0
    $uniqueJson = 0
    $seenForQuality = @{}
    foreach ($category in @($manifest.categories)) {
        $categoryPath = Join-Path $refsDir ([string]$category.file)
        $records = @(Get-Content -Raw -Encoding UTF8 -LiteralPath $categoryPath | ConvertFrom-Json | ForEach-Object { $_ })
        if ($records.Count -ne [int]$category.count) {
            Add-Failure "category_count_mismatch:$($category.slug):$($records.Count):$($category.count)"
        } else { Add-Pass }
        foreach ($record in $records) {
            $rows++
            $id = [string]$record.id
            if ([string]::IsNullOrWhiteSpace($id) -or
                [string]::IsNullOrWhiteSpace([string]$record.title) -or
                [string]::IsNullOrWhiteSpace([string]$record.content)) { $bad++ }
            [void]$ids.Add($id)
            if (-not $seenForQuality.ContainsKey($id)) {
                $seenForQuality[$id] = $true
                if ([bool]$record.needReferenceImages) { $uniqueReference++ }
                $trimmed = ([string]$record.content).TrimStart()
                if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) { $uniqueJson++ }
            }
        }
    }
    if ($bad -eq 0) { Add-Pass } else { Add-Failure "bad_required_records:$bad" }
    if ($rows -eq [int]$manifest.totalRows) { Add-Pass } else { Add-Failure "row_count:${rows}:$($manifest.totalRows)" }
    if ($ids.Count -eq [int]$manifest.totalPrompts) { Add-Pass } else { Add-Failure "unique_count:$($ids.Count):$($manifest.totalPrompts)" }
    if ($uniqueReference -eq [int]$manifest.quality.uniqueReferenceRequired) { Add-Pass } else { Add-Failure "reference_quality_count:$uniqueReference" }
    if ($uniqueJson -eq [int]$manifest.quality.uniqueJsonStructured) { Add-Pass } else { Add-Failure "json_quality_count:$uniqueJson" }
} catch { Add-Failure "manifest_or_corpus_error:$($_.Exception.Message)" }

$lintCases = @(Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $testsDir 'lint-cases.json') | ConvertFrom-Json | ForEach-Object { $_ })
foreach ($case in $lintCases) {
    $lintParameters = @{
        Prompt = [string]$case.prompt
        Surface = [string]$case.surface
    }
    if ($case.PSObject.Properties.Name -contains 'strict' -and [bool]$case.strict) { $lintParameters.Strict = $true }
    $output = & $lintScript @lintParameters
    $actual = $output | ConvertFrom-Json
    if ([bool]$actual.valid -eq [bool]$case.valid) { Add-Pass }
    else { Add-Failure "lint_case:$($case.id):expected=$($case.valid):actual=$($actual.valid):$($actual.errors -join ',')" }
    $global:LASTEXITCODE = 0
}

$forwardCases = @(Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $testsDir 'forward-prompts.json') | ConvertFrom-Json | ForEach-Object { $_ })
foreach ($case in $forwardCases) {
    $output = & $lintScript -Prompt ([string]$case.prompt) -Surface ([string]$case.surface)
    $actual = $output | ConvertFrom-Json
    if ([bool]$actual.valid) { Add-Pass }
    else { Add-Failure "forward_prompt:$($case.id):$($actual.errors -join ',')" }
    $global:LASTEXITCODE = 0
}

if (-not $SkipSearchTests) {
    $searchCases = @(Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $testsDir 'search-cases.json') | ConvertFrom-Json | ForEach-Object { $_ })
    foreach ($case in $searchCases) {
        try {
            $output = & $searchScript -Query ([string]$case.query) -Category ([string]$case.category) -Limit 3
            $records = @($output | ConvertFrom-Json | ForEach-Object { $_ })
            if ($records.Count -eq 0) {
                Add-Failure "search_case_empty:$($case.id)"
                continue
            }
            $metadata = ($records | ForEach-Object { "$($_.title) $($_.description)" }) -join "`n"
            if ($metadata -match [string]$case.expected) { Add-Pass }
            else { Add-Failure "search_case_irrelevant:$($case.id):$($records[0].title)" }
            $global:LASTEXITCODE = 0
        } catch {
            Add-Failure "search_case_error:$($case.id):$($_.Exception.Message)"
        }
    }
}

$total = $passed + $failures.Count
if ($failures.Count -gt 0) {
    Write-Output "VALIDATION_FAILED passed=$passed total=$total failures=$($failures.Count)"
    $failures | ForEach-Object { Write-Output "ERROR $_" }
    exit 1
}

Write-Output "VALIDATION_OK passed=$passed total=$total search_skipped=$([bool]$SkipSearchTests)"
