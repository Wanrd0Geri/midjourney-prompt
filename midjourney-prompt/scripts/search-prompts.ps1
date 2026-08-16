[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Query,

    [string[]]$Category = @(),

    [ValidateRange(1, 25)]
    [int]$Limit = 6,

    [ValidateRange(300, 4000)]
    [int]$MaxExcerptChars = 1400,

    [ValidateSet("exclude", "allow", "prefer")]
    [string]$ReferenceMode = "exclude",

    [switch]$IncludeMetaPrompts,
    [switch]$IncludeRawContent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$skillRoot = Split-Path -Parent $PSScriptRoot
$refsDir = Join-Path $skillRoot "references"
$manifestPath = Join-Path $refsDir "manifest.json"
$lexiconPath = Join-Path $refsDir "query-lexicon.json"

foreach ($requiredPath in @($manifestPath, $lexiconPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required retrieval file not found: $requiredPath"
    }
}

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$lexicon = Get-Content -Raw -Encoding UTF8 -LiteralPath $lexiconPath | ConvertFrom-Json
$categories = @($manifest.categories)

function Get-RequestedCategories {
    param([string[]]$Values)

    $requested = @(
        foreach ($value in $Values) {
            foreach ($part in ($value -split ',')) {
                $trimmed = $part.Trim()
                if ($trimmed) { $trimmed }
            }
        }
    )

    if ($requested.Count -eq 0) { return @($categories) }

    $selected = @($categories | Where-Object {
        $slug = [string]$_.slug
        $title = [string]$_.title
        $file = [string]$_.file
        $requested -contains $slug -or $requested -contains $title -or $requested -contains $file
    })
    if ($selected.Count -eq 0) {
        throw "No requested categories matched. Valid slugs: $($categories.slug -join ', ')"
    }
    return $selected
}

function Convert-ToSearchEnglish {
    param([string]$Text)

    $value = $Text.Trim().ToLowerInvariant()
    $translations = @($lexicon.translations.PSObject.Properties | Sort-Object { $_.Name.Length } -Descending)
    foreach ($entry in $translations) {
        $value = $value.Replace([string]$entry.Name, " $([string]$entry.Value) ")
    }
    return (($value -replace '\s+', ' ').Trim())
}

function Get-Tokens {
    param([string]$Text)

    return @(
        [regex]::Matches($Text.ToLowerInvariant(), '[a-z0-9]+(?:-[a-z0-9]+)*') |
            ForEach-Object { $_.Value } |
            Where-Object { $_.Length -ge 2 -and $script:stopWords -notcontains $_ }
    )
}

function Get-Concepts {
    param([string]$Text)

    $concepts = [ordered]@{}
    foreach ($token in (Get-Tokens -Text $Text)) {
        $canonical = if ($script:termToCanonical.ContainsKey($token)) {
            [string]$script:termToCanonical[$token]
        } else {
            $token
        }
        if (-not $concepts.Contains($canonical)) {
            $terms = if ($script:canonicalToTerms.ContainsKey($canonical)) {
                @($script:canonicalToTerms[$canonical])
            } else {
                @($token)
            }
            $concepts[$canonical] = $terms
        }
    }
    return $concepts
}

function Get-TermMatchCount {
    param(
        [string]$Text,
        [regex]$Pattern
    )
    return $Pattern.Matches($Text).Count
}

function Test-IsMetaPrompt {
    param(
        [string]$Title,
        [string]$Description,
        [string]$Content
    )

    $sample = "$Title`n$Description`n$($Content.Substring(0, [Math]::Min($Content.Length, 1800)))"
    return $sample -match '(?i)system prompt|not an image generation prompt|you are (an?|the) .{0,60}(agent|expert|designer|engineer)|execute the following (thought|thinking|research) process|real-time web search capabilities'
}

function Remove-CorpusNoise {
    param([string]$Text)

    $clean = $Text
    $clean = [regex]::Replace($clean, 'https?://\S+', ' ')
    $clean = [regex]::Replace($clean, '\{argument\s+name=.*?\}', ' ', 'IgnoreCase')
    $clean = [regex]::Replace($clean, '(?im)^\s*(system prompt|role setting|core task instruction|instructions? for .+|thinking process|negative prompts?).*$', ' ')
    $clean = [regex]::Replace($clean, '(?i)\b(Nano Banana(?: Pro| 2)?|Gemini Pro mode)\b', ' ')
    $clean = [regex]::Replace($clean, '\s+', ' ')
    return $clean.Trim()
}

function Add-FlattenedJsonValues {
    param(
        [object]$Value,
        [System.Collections.Generic.List[string]]$Output,
        [string]$Key = ''
    )

    if ($null -eq $Value) { return }
    if ($Key -match '(?i)negative|constraint|reference|identity|argument|instruction|system|task|role|url|source|output') {
        return
    }
    if ($Value -is [string] -or $Value -is [ValueType]) {
        $textValue = Remove-CorpusNoise -Text ([string]$Value)
        if ($textValue) { $Output.Add($textValue) }
        return
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($entry in $Value.GetEnumerator()) {
            Add-FlattenedJsonValues -Value $entry.Value -Output $Output -Key ([string]$entry.Key)
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [pscustomobject])) {
        foreach ($item in $Value) {
            Add-FlattenedJsonValues -Value $item -Output $Output -Key $Key
        }
        return
    }
    foreach ($property in $Value.PSObject.Properties) {
        Add-FlattenedJsonValues -Value $property.Value -Output $Output -Key ([string]$property.Name)
    }
}

function Get-VisualExcerpt {
    param(
        [string]$Content,
        [int]$MaximumLength
    )

    $clean = ''
    $trimmed = $Content.TrimStart()
    if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) {
        try {
            $parsed = $Content | ConvertFrom-Json
            $parts = [System.Collections.Generic.List[string]]::new()
            Add-FlattenedJsonValues -Value $parsed -Output $parts
            $clean = ($parts | Select-Object -Unique) -join '; '
        } catch {
            $clean = Remove-CorpusNoise -Text $Content
        }
    } else {
        $lines = @(
            $Content -split "`r?`n" |
                Where-Object {
                    $_ -and $_ -notmatch '(?i)^\s*(you are|role:|task:|instructions?:|thinking process|negative prompt|must have|output:)'
                } |
                ForEach-Object { Remove-CorpusNoise -Text $_ } |
                Where-Object { $_ }
        )
        $clean = $lines -join '; '
    }

    if ($clean.Length -gt $MaximumLength) {
        return $clean.Substring(0, $MaximumLength).TrimEnd() + '...'
    }
    return $clean
}

$script:stopWords = @(
    'a', 'an', 'and', 'are', 'art', 'create', 'for', 'from', 'image', 'in',
    'make', 'of', 'on', 'photo', 'picture', 'style', 'the', 'to', 'with'
)
$script:termToCanonical = @{}
$script:canonicalToTerms = @{}
foreach ($group in @($lexicon.groups)) {
    $canonical = [string]$group.canonical
    $terms = @($group.terms | ForEach-Object { ([string]$_).ToLowerInvariant() } | Select-Object -Unique)
    if ($terms -notcontains $canonical) { $terms = @($canonical) + $terms }
    $script:canonicalToTerms[$canonical] = $terms
    foreach ($term in $terms) { $script:termToCanonical[$term] = $canonical }
}

$selectedCategories = @(Get-RequestedCategories -Values $Category)
$normalizedQuery = Convert-ToSearchEnglish -Text $Query
$concepts = Get-Concepts -Text $normalizedQuery
if ($concepts.Count -eq 0) {
    Write-Output '[]'
    exit 0
}

$normalizedPhrase = ((Get-Tokens -Text $normalizedQuery) -join ' ')
$phrasePattern = $null
if ($normalizedPhrase.Length -ge 3) {
    $phrasePattern = [regex]::new(
        '(?<![a-z0-9])' + [regex]::Escape($normalizedPhrase).Replace('\ ', '\s+') + '(?![a-z0-9])',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
}
$conceptMatchers = [System.Collections.Generic.List[object]]::new()
foreach ($conceptEntry in $concepts.GetEnumerator()) {
    $alternatives = @($conceptEntry.Value | ForEach-Object { [regex]::Escape([string]$_) }) -join '|'
    $conceptMatchers.Add([pscustomobject]@{
        canonical = [string]$conceptEntry.Key
        pattern = [regex]::new(
            '(?<![a-z0-9])(?:' + $alternatives + ')(?![a-z0-9])',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
    })
}
$modifierConcepts = @($lexicon.modifierConcepts)
$primaryConcept = @($concepts.Keys | Where-Object { $modifierConcepts -notcontains $_ } | Select-Object -First 1)
if ($primaryConcept.Count -eq 0) { $primaryConcept = @($concepts.Keys | Select-Object -First 1) }
$primaryConcept = [string]$primaryConcept[0]
$results = [System.Collections.Generic.List[object]]::new()

foreach ($categoryRecord in $selectedCategories) {
    $categoryPath = Join-Path $refsDir ([string]$categoryRecord.file)
    if (-not (Test-Path -LiteralPath $categoryPath -PathType Leaf)) { continue }

    $records = Get-Content -Raw -Encoding UTF8 -LiteralPath $categoryPath | ConvertFrom-Json
    foreach ($record in $records) {
        $title = [string]$record.title
        $description = [string]$record.description
        $content = [string]$record.content
        $needsReference = [bool]$record.needReferenceImages

        if ($ReferenceMode -eq 'exclude' -and $needsReference) { continue }
        if (-not $IncludeMetaPrompts -and (Test-IsMetaPrompt -Title $title -Description $description -Content $content)) {
            continue
        }

        $score = 0
        $matched = [System.Collections.Generic.List[string]]::new()
        $primaryMatchedInMetadata = $false

        if ($null -ne $phrasePattern) {
            if ($phrasePattern.IsMatch($title)) { $score += 36 }
            if ($phrasePattern.IsMatch($description)) { $score += 18 }
            if ($phrasePattern.IsMatch($content)) { $score += 5 }
        }

        foreach ($conceptMatcher in $conceptMatchers) {
            $titleMatches = Get-TermMatchCount -Text $title -Pattern $conceptMatcher.pattern
            $descriptionMatches = Get-TermMatchCount -Text $description -Pattern $conceptMatcher.pattern
            $contentMatches = Get-TermMatchCount -Text $content -Pattern $conceptMatcher.pattern
            if (($titleMatches + $descriptionMatches + $contentMatches) -gt 0) {
                $matched.Add([string]$conceptMatcher.canonical)
            }
            if ($conceptMatcher.canonical -eq $primaryConcept -and ($titleMatches + $descriptionMatches) -gt 0) {
                $primaryMatchedInMetadata = $true
            }
            $score += 14 * [Math]::Min($titleMatches, 2)
            $score += 6 * [Math]::Min($descriptionMatches, 3)
            $score += [Math]::Min($contentMatches, 5)
        }

        $minimumCoverage = if ($concepts.Count -ge 5) { 2 } else { 1 }
        if ($score -le 0 -or $matched.Count -lt $minimumCoverage) { continue }
        if ($matched -notcontains $primaryConcept -or -not $primaryMatchedInMetadata) { continue }
        $coverage = [Math]::Round($matched.Count / [double]$concepts.Count, 3)
        $score += [int](20 * $coverage)
        if ($ReferenceMode -eq 'prefer' -and $needsReference) { $score += 12 }

        $results.Add([pscustomobject]@{
            score = $score
            coverage = $coverage
            matchedConcepts = @($matched)
            category = [string]$categoryRecord.slug
            id = $record.id
            title = $title
            description = $description
            rawContent = $content
            sourceMedia = @($record.sourceMedia)
            needReferenceImages = $needsReference
            sourceUrl = "https://youmind.com/nano-banana-pro-prompts?id=$($record.id)"
        })
    }
}

$sorted = $results | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'coverage'; Descending = $true }, @{ Expression = 'id'; Descending = $false }
$seenIds = @{}
$seenTitles = @{}
$top = [System.Collections.Generic.List[object]]::new()

foreach ($item in $sorted) {
    $idKey = [string]$item.id
    $titleKey = (((Get-Tokens -Text ([string]$item.title)) | Sort-Object -Unique) -join ' ')
    if ($seenIds.ContainsKey($idKey) -or ($titleKey -and $seenTitles.ContainsKey($titleKey))) { continue }
    $seenIds[$idKey] = $true
    if ($titleKey) { $seenTitles[$titleKey] = $true }

    $record = [ordered]@{
        score = $item.score
        coverage = $item.coverage
        matchedConcepts = $item.matchedConcepts
        category = $item.category
        id = $item.id
        title = $item.title
        description = $item.description
        visualExcerpt = Get-VisualExcerpt -Content ([string]$item.rawContent) -MaximumLength $MaxExcerptChars
        sourceMedia = $item.sourceMedia
        needReferenceImages = $item.needReferenceImages
        sourceUrl = $item.sourceUrl
    }
    if ([string]$record.visualExcerpt -and ([string]$record.visualExcerpt).Length -lt 80) {
        $record.visualExcerpt = Remove-CorpusNoise -Text ([string]$item.description)
    }
    if ($IncludeRawContent) { $record.rawContent = $item.rawContent }
    $top.Add([pscustomobject]$record)
    if ($top.Count -ge $Limit) { break }
}

if ($top.Count -eq 0) {
    Write-Output '[]'
    exit 0
}

$top | ConvertTo-Json -Depth 7
