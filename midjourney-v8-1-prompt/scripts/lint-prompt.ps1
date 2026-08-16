[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Prompt,

    [ValidateSet("web", "discord")]
    [string]$Surface = "web",

    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$parameterMatches = @([regex]::Matches($Prompt, '(?<!\S)--(?<name>[a-z]+)(?:\s+(?!-{2})(?<value>[^\s]+))?', 'IgnoreCase'))
$parameterNames = @($parameterMatches | ForEach-Object { $_.Groups['name'].Value.ToLowerInvariant() })
$allowed = @(
    'v', 'version', 'ar', 'aspect', 'raw', 's', 'stylize', 'c', 'chaos', 'no',
    'seed', 'sref', 'sw', 'iw', 'tile', 'weird', 'w', 'profile', 'p', 'hd', 'sd',
    'draft', 'fast', 'relax', 'repeat', 'r', 'public', 'stealth'
)
$forbidden = @('q', 'quality', 'oref', 'ow', 'cref', 'cw', 'turbo', 'niji')

foreach ($name in $parameterNames) {
    if ($forbidden -contains $name) { $errors.Add("unsupported_parameter:$name") }
    elseif ($allowed -notcontains $name) { $warnings.Add("unknown_parameter:$name") }
}

$versionMatch = [regex]::Match($Prompt, '(?<!\S)--(?:v|version)\s+(?<value>[^\s]+)', 'IgnoreCase')
if (-not $versionMatch.Success) {
    $errors.Add('missing_version:--v 8.1')
} elseif ($versionMatch.Groups['value'].Value -ne '8.1') {
    $errors.Add("wrong_version:$($versionMatch.Groups['value'].Value)")
}

if ($parameterNames -contains 'draft' -and $Surface -eq 'discord') {
    $errors.Add('draft_is_web_only_for_v8.1')
}
if ($parameterNames -contains 'sw' -and $parameterNames -notcontains 'sref') {
    $errors.Add('sw_requires_sref')
}
if ($parameterNames -contains 'iw' -and $Prompt -notmatch '^\s*https?://\S+') {
    $errors.Add('iw_requires_leading_image_url')
}
if ($parameterNames -contains 'repeat' -or $parameterNames -contains 'r') {
    if ($parameterNames -notcontains 'fast') { $warnings.Add('repeat_requires_fast_mode_in_v8.1') }
}

$aspectMatch = [regex]::Match($Prompt, '(?<!\S)--(?:ar|aspect)\s+(?<w>[^:\s]+):(?<h>[^\s]+)', 'IgnoreCase')
if ($aspectMatch.Success) {
    $width = 0
    $height = 0
    if (-not [int]::TryParse($aspectMatch.Groups['w'].Value, [ref]$width) -or
        -not [int]::TryParse($aspectMatch.Groups['h'].Value, [ref]$height) -or
        $width -le 0 -or $height -le 0) {
        $errors.Add('aspect_ratio_must_use_positive_integers')
    } else {
        $ratio = [Math]::Max($width / [double]$height, $height / [double]$width)
        $maximum = if ($parameterNames -contains 'hd') { 4.0 } else { 14.0 }
        if ($ratio -gt $maximum) { $errors.Add("aspect_ratio_exceeds_$($maximum):1") }
    }
}

$firstParameterIndex = $Prompt.IndexOf('--')
if ($firstParameterIndex -gt 0) {
    $promptText = $Prompt.Substring(0, $firstParameterIndex)
    if ($promptText -match '::') { $errors.Add('multiprompt_weights_unavailable_in_v8.1') }
}

if ($Prompt.TrimStart().StartsWith('{') -or $Prompt -match '(?i)"(?:type|positive|negative_prompt)"\s*:') {
    $errors.Add('raw_json_leakage')
}
if ($Prompt -match '(?i)\{argument\s+name=|\bNano Banana(?: Pro| 2)?\b|\bGemini Pro mode\b') {
    $errors.Add('source_template_leakage')
}
if ($Prompt -match '(?i)^\s*(you are|role:|task:|system prompt)') {
    $errors.Add('meta_instruction_leakage')
}
if ($Prompt -match '(?i)\b(masterpiece|best quality|8k|16k|award-winning)\b') {
    $warnings.Add('quality_filler_detected')
}
if ($Prompt -match '(?i)\bnegative prompt\s*:') {
    $warnings.Add('convert_negative_prompt_to_short_--no_list')
}

$duplicates = @($parameterNames | Group-Object | Where-Object { $_.Count -gt 1 -and $_.Name -notin @('sref', 'no') })
foreach ($duplicate in $duplicates) { $errors.Add("duplicate_parameter:$($duplicate.Name)") }

foreach ($match in $parameterMatches) {
    $value = $match.Groups['value'].Value
    if ($value -match '[,;.]$') { $errors.Add("parameter_value_has_punctuation:$($match.Groups['name'].Value)") }
}

if ($Strict -and $warnings.Count -gt 0) {
    foreach ($warning in @($warnings)) { $errors.Add("strict:$warning") }
}

[pscustomobject]@{
    valid = ($errors.Count -eq 0)
    surface = $Surface
    errors = @($errors | Select-Object -Unique)
    warnings = @($warnings | Select-Object -Unique)
    parameters = @($parameterNames)
} | ConvertTo-Json -Depth 5

if ($errors.Count -gt 0) { exit 1 }
