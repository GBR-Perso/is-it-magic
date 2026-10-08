# Fails (exit 1) when lines added since HEAD, including untracked files, carry more comment than the budget allows.
# The budget is absolute, never relative to the existing codebase: a relative baseline would ratchet up with every change.

$CommentLinesPerCodeLine = 0.2
$MinAllowancePerFile = 3

$CStyleExtensions = @('.cs', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.vue', '.go', '.java', '.kt', '.swift', '.rs', '.c', '.h', '.cpp', '.hpp', '.css', '.scss')
$HashStyleExtensions = @('.py', '.ps1', '.psm1', '.sh', '.tf', '.rb')
$MarkupCommentExtensions = @('.vue', '.html')
$ExcludedPathPattern = '(^|/)(Migrations|generated)/|\.g\.cs$|\.Designer\.cs$|\.d\.ts$|\.min\.js$'
$ApiDocPathPattern = '(^|/)Controllers/.+\.cs$'
$ApiDocPrefix = '^\s*///'

$CStylePrefix = '^(///?|/\*\*?|\*/|\*)'
$HashPrefix = '^#'
$MarkupPrefix = '^(<!--|-->)'
$XmlDocTagOnly = '^</?\w+>$'

function Get-LineKind([string] $line, [string] $extension) {
    $text = $line.Trim()
    if ($text -eq '') { return 'blank' }

    $prefix = $null
    if ($CStyleExtensions -contains $extension -and $text -match $CStylePrefix) { $prefix = $Matches[0] }
    elseif ($HashStyleExtensions -contains $extension -and $text -match $HashPrefix) { $prefix = $Matches[0] }
    elseif ($MarkupCommentExtensions -contains $extension -and $text -match $MarkupPrefix) { $prefix = $Matches[0] }
    if ($null -eq $prefix) { return 'code' }

    # Delimiter and bare XML-doc tag lines (/**, */, /// <summary>) are not counted, so a one-line summary costs one line.
    $body = $text.Substring($prefix.Length).Trim() -replace '\*/$', '' -replace '-->$', ''
    $body = $body.Trim()
    if ($body -eq '' -or $body -match $XmlDocTagOnly) { return 'blank' }
    return 'comment'
}

$addedLinesByFile = @{}

$currentFile = $null
foreach ($line in (git -c core.quotepath=off diff HEAD --unified=0 --no-color --no-ext-diff)) {
    if ($line -match '^\+\+\+ (b/(.+)|/dev/null)$') { $currentFile = $Matches[2]; continue }
    if ($null -ne $currentFile -and $line.StartsWith('+')) {
        if (-not $addedLinesByFile.ContainsKey($currentFile)) { $addedLinesByFile[$currentFile] = [System.Collections.Generic.List[string]]::new() }
        $addedLinesByFile[$currentFile].Add($line.Substring(1))
    }
}
foreach ($file in (git -c core.quotepath=off ls-files --others --exclude-standard)) {
    $addedLinesByFile[$file] = [System.Collections.Generic.List[string]]::new([string[]] @(Get-Content -LiteralPath $file))
}

$rows = foreach ($file in $addedLinesByFile.Keys) {
    $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
    $isSource = ($CStyleExtensions + $HashStyleExtensions + $MarkupCommentExtensions) -contains $extension
    if (-not $isSource -or $file -match $ExcludedPathPattern) { continue }

    $lines = $addedLinesByFile[$file]
    # Controller XML docs feed the OpenAPI spec: they are API documentation, not comments.
    if ($file -match $ApiDocPathPattern) { $lines = $lines | Where-Object { $_ -notmatch $ApiDocPrefix } }
    $kinds = $lines | ForEach-Object { Get-LineKind $_ $extension }
    $code = @($kinds | Where-Object { $_ -eq 'code' }).Count
    $comment = @($kinds | Where-Object { $_ -eq 'comment' }).Count
    $allowed = [Math]::Max($MinAllowancePerFile, [Math]::Floor($code * $CommentLinesPerCodeLine))
    [pscustomobject]@{ File = $file; Code = $code; Comment = $comment; Allowed = $allowed; Over = $comment -gt $allowed }
}

if (-not $rows) {
    Write-Output 'Comment budget: PASS (no added source lines)'
    exit 0
}

$rows | Sort-Object -Property @{ Expression = 'Over'; Descending = $true }, File |
    Format-Table File, Code, Comment, Allowed, @{ Label = 'Status'; Expression = { if ($_.Over) { 'OVER' } else { 'ok' } } } -AutoSize |
    Out-String -Width 4096 | Write-Output

$over = @($rows | Where-Object Over)
if ($over.Count -gt 0) {
    Write-Output "Comment budget: FAIL - $($over.Count) file(s) over budget (at most 1 comment line per $([int](1 / $CommentLinesPerCodeLine)) added code lines, minimum $MinAllowancePerFile per file). Cut comments, never code."
    exit 1
}
Write-Output 'Comment budget: PASS'
exit 0
