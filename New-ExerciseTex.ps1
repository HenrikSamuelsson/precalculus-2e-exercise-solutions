<# 
 .SYNOPSIS
    Generate a new Abramson (2021) exercise .tex file from the cmbright+CC template.
 .DESCRIPTION
    Fills metadata in the template:
      - \exSource  : section | review
      - \exChapter : chapter number (e.g., 1)
      - \exSection : section number (e.g., 1.1) when Source=section
      - \exNumber  : exercise number as in the book
      - \exVariant : optional letter, prints as "(a)" in header
      - \exTitle   : optional short title under header
    Produces a kebab-case filename that encodes the source and location,
    e.g.:
      abramson-2021-sec-01-01-ex-06-functions-and-relations.tex
      abramson-2021-ch-01-review-ex-01a-determine-function.tex

 .PARAMETER Source
    'section' or 'review'
 .PARAMETER Chapter
    Chapter number (integer)
 .PARAMETER Section
    Section number string like "1.1" (required when Source='section')
 .PARAMETER Number
    Exercise number (integer)
 .PARAMETER Variant
    Optional letter like 'a'. Will be rendered as "(a)" in the header and
    appended to the filename as '...-ex-06a-...'
 .PARAMETER Slug
    Short kebab-case slug for the filename, e.g., "functions-and-relations"
 .PARAMETER Title
    Optional human-readable title printed under the header. Defaults to a
    title-cased version of the slug.
 .PARAMETER Template
    Path to the LaTeX template. Defaults to
    .\abramson-2021-exercise-template-cmbright-cc-header.tex
 .PARAMETER OutDir
    Output directory. Defaults to the current directory.
 .PARAMETER OpenAfter
    If set, opens the created file in VS Code (if 'code' is on PATH).
#>
function New-ExerciseTex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('section','review')]
        [string]$Source,

        [Parameter(Mandatory)]
        [int]$Chapter,

        [Parameter()]
        [string]$Section,

        [Parameter(Mandatory)]
        [int]$Number,

        [Parameter()]
        [string]$Variant,

        [Parameter(Mandatory)]
        [string]$Slug,

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$Template = ".\abramson-2021-exercise-template-cmbright-cc-header.tex",

        [Parameter()]
        [string]$OutDir = ".",

        [switch]$OpenAfter
    )

    if ($Source -eq 'section' -and [string]::IsNullOrWhiteSpace($Section)) {
        throw "When -Source section, you must provide -Section like '1.1'."
    }

    if (-not (Test-Path $Template)) {
        throw "Template not found: $Template"
    }

    function Pad2($n) { return ('{0:d2}' -f [int]$n) }

    # Normalize/derive pieces
    $chapFmt = Pad2 $Chapter
    $numFmt  = Pad2 $Number

    $varNorm = ''
    $varFile = ''
    if ($Variant) {
        $v = $Variant.Trim()
        $v = $v.Trim('()')
        $varNorm = "($v)"
        $varFile = $v.ToLower()
    }

    # Slugify (lowercase, kebab-case)
    $slug = $Slug.ToLower()
    $slug = ($slug -replace '[^a-z0-9]+','-').Trim('-')

    if (-not $Title) {
        # Title case the slug
        $Title = ($slug -split '-') | ForEach-Object { if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } } | ForEach-Object { $_ } -join ' '
    }

    # Build filename
    if ($Source -eq 'section') {
        $parts = $Section -split '[\.\-]'
        if ($parts.Count -lt 2) { throw "Section should look like '1.1'." }
        $secFmt = ("{0}-{1}" -f (Pad2 $parts[0]), (Pad2 $parts[1]))
        $file = if ($varFile) {
            "abramson-2021-sec-$secFmt-ex-$numFmt$varFile-$slug.tex"
        } else {
            "abramson-2021-sec-$secFmt-ex-$numFmt-$slug.tex"
        }
    }
    else {
        $file = if ($varFile) {
            "abramson-2021-ch-$chapFmt-review-ex-$numFmt$varFile-$slug.tex"
        } else {
            "abramson-2021-ch-$chapFmt-review-ex-$numFmt-$slug.tex"
        }
    }

    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
    $outPath = Join-Path $OutDir $file

    # Read template
    $src = Get-Content -Raw -Encoding UTF8 $Template

    # Helper to replace \newcommand lines robustly
    function Set-NewCommandValue {
        param(
            [string]$text,
            [string]$name,
            [string]$value
        )
        $pattern = "\\newcommand\{\\$name\}\{[^\}]*\}"
        $replacement = "\newcommand{\$name}{$value}"
        return ($text -replace $pattern, [System.Text.RegularExpressions.Regex]::Escape($replacement) -replace '\\\\','\')
    }

    $dst = $src
    $dst = Set-NewCommandValue -text $dst -name 'exSource'  -value $Source
    $dst = Set-NewCommandValue -text $dst -name 'exChapter' -value $Chapter
    $dst = Set-NewCommandValue -text $dst -name 'exSection' -value ($Section ? $Section : ' ')
    $dst = Set-NewCommandValue -text $dst -name 'exNumber'  -value $Number
    $dst = Set-NewCommandValue -text $dst -name 'exVariant' -value $varNorm
    $dst = Set-NewCommandValue -text $dst -name 'exTitle'   -value $Title

    # Write output
    Set-Content -Path $outPath -Value $dst -Encoding UTF8
    Write-Host "Created $outPath"

    if ($OpenAfter) {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            & code $outPath
        } else {
            Write-Warning "'code' not found on PATH. Open the file in your editor manually."
        }
    }

    return $outPath
}

# Examples:
# . .\New-ExerciseTex.ps1
# New-ExerciseTex -Source section -Chapter 1 -Section 1.1 -Number 6 -Slug "functions-and-relations" -Title "Functions and Relations" -OpenAfter
# New-ExerciseTex -Source review  -Chapter 1              -Number 1 -Slug "determine-function"      -Title "Review — Function or Not" -OpenAfter