#Requires -Version 7
#Requires -Modules Posh-SSH

$configFile    = Join-Path $PSScriptRoot 'config.json'
$blocklistFile = Join-Path $PSScriptRoot 'blocklist.json'

# --- Load config ---
if (-not (Test-Path $configFile)) {
    Write-Error "config.json not found. Create it with host, port, username, password."
    exit 1
}

$config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json

$securePass = ConvertTo-SecureString $config.password -AsPlainText -Force
$credential = [PSCredential]::new($config.username, $securePass)

# --- Load blocklist ---
if (-not (Test-Path $blocklistFile)) {
    Write-Error "blocklist.json not found. Run Convert-Blocklist.ps1 first."
    exit 1
}

$blocklist = Get-Content -LiteralPath $blocklistFile -Raw | ConvertFrom-Json
$domains   = @($blocklist.blocked_domains)
$ips       = @($blocklist.blocked_ips)

# --- Open SSH session ---
Write-Host "Connecting to $($config.host):$($config.port)..."

$session = New-SSHSession -ComputerName $config.host `
                          -Port $config.port `
                          -Credential $credential `
                          -AcceptKey `
                          -ErrorAction Stop

Write-Host "Pushing $($domains.Count) domains and $($ips.Count) IPs..."

$added        = 0
$skipped      = 0
$failed       = 0
$failedItems  = [System.Collections.Generic.List[string]]::new()
$skippedItems = [System.Collections.Generic.List[string]]::new()

function Invoke-BlocklistAppend {
    param(
        [int]    $SessionId,
        [string] $Command,
        [string] $Label
    )

    $result = Invoke-SSHCommand -SessionId $SessionId -Command $Command
    # IP errors use different phrasing than domain errors; normalise by joining all output lines
    $output = ($result.Output -join ' ').Trim()

    if ($output -eq '') {
        Write-Host "  [+] $Label"
        return 'added'
    } elseif ($output -match 'already exists') {
        Write-Host "  [~] $Label (duplicate)"
        return 'skipped'
    } elseif ($output -match 'Command fail') {
        Write-Host "  [!] $Label (FAILED: $output)"
        return 'failed'
    } else {
        Write-Host "  [?] $Label (unexpected: $output)"
        return 'failed'
    }
}

# --- Push domains ---
foreach ($domain in $domains) {
    $cmd    = "execute domain-blocklist append domain $domain"
    $status = Invoke-BlocklistAppend -SessionId $session.SessionId -Command $cmd -Label $domain
    switch ($status) {
        'added'   { $added++ }
        'skipped' { $skipped++; $skippedItems.Add("domain: $domain") }
        'failed'  { $failed++;  $failedItems.Add("domain: $domain") }
    }
}

# --- Push IPs ---
foreach ($ip in $ips) {
    $cmd    = "execute ipv4-blocklist append address $ip"
    $status = Invoke-BlocklistAppend -SessionId $session.SessionId -Command $cmd -Label $ip
    switch ($status) {
        'added'   { $added++ }
        'skipped' { $skipped++; $skippedItems.Add("ip: $ip") }
        'failed'  { $failed++;  $failedItems.Add("ip: $ip") }
    }
}

# --- Close session ---
Remove-SSHSession -SessionId $session.SessionId | Out-Null

# --- Summary ---
Write-Host ""
Write-Host "Done. Added: $added  Skipped: $skipped  Failed: $failed"

if ($skippedItems.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped (already on appliance):"
    $skippedItems | ForEach-Object { Write-Host "  $_" }
}

if ($failedItems.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed (check appliance logs):"
    $failedItems | ForEach-Object { Write-Host "  $_" }
}
