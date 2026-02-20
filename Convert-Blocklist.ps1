#Requires -Version 7

$inputFile  = Join-Path $PSScriptRoot 'blocklist.txt'
$outputFile = Join-Path $PSScriptRoot 'blocklist.json'

$domains   = [System.Collections.Generic.List[string]]::new()
$ips       = [System.Collections.Generic.List[string]]::new()
$converted = [System.Collections.Generic.HashSet[int]]::new()

$ipPattern     = '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
$domainPattern = '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'

$lines = Get-Content -LiteralPath $inputFile

foreach ($i in 0..($lines.Count - 1)) {
    # 1. Trim whitespace; skip blank lines
    $entry = $lines[$i].Trim()
    if ([string]::IsNullOrEmpty($entry)) { continue }

    # 2. Skip already-commented lines
    if ($entry.StartsWith('#')) { continue }

    # 3. Strip protocol prefix (e.g. hxxps://, http://)
    $entry = $entry -replace '^[a-zA-Z][a-zA-Z0-9+\-.]*://', ''

    # 4. Strip URL path (everything from first / onward)
    $slashIdx = $entry.IndexOf('/')
    if ($slashIdx -ge 0) {
        $entry = $entry.Substring(0, $slashIdx)
    }

    # 5. De-obfuscate brackets
    $entry = $entry -replace '[\[\]]', ''

    # 6. Lowercase
    $entry = $entry.ToLowerInvariant()

    # 7. Validate and classify
    if ($entry -match $ipPattern) {
        $ips.Add($entry)
        $null = $converted.Add($i)
    } elseif ($entry -match $domainPattern) {
        $domains.Add($entry)
        $null = $converted.Add($i)
    }
    # else: discard invalid entry
}

# Comment out successfully converted lines in blocklist.txt
$updatedLines = $lines | ForEach-Object -Begin { $i = 0 } -Process {
    if ($converted.Contains($i++)) { "# $_" } else { $_ }
}
Set-Content -LiteralPath $inputFile -Value $updatedLines -Encoding UTF8

# Deduplicate
$blocked_domains = $domains | Sort-Object -Unique
$blocked_ips     = $ips     | Sort-Object -Unique

$result = [ordered]@{
    blocked_domains = @($blocked_domains)
    blocked_ips     = @($blocked_ips)
}

$result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $outputFile -Encoding UTF8

Write-Host "Written to $outputFile"
Write-Host "  Domains : $($blocked_domains.Count)"
Write-Host "  IPs     : $($blocked_ips.Count)"
