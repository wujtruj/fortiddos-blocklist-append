# FortiDDoS Blocklist Append

Two PowerShell 7 scripts that convert a raw threat-intel blocklist into structured JSON and push every entry to a FortiDDoS appliance over SSH.

## Requirements

- PowerShell 7+
- [Posh-SSH](https://github.com/darkoperator/Posh-SSH) module

```powershell
Install-Module -Name Posh-SSH -Scope CurrentUser
```

## Setup

Copy `config.json.example` to `config.json` and fill in your credentials (`config.json` is gitignored):

```powershell
cp config.json.example config.json
```

## Usage

### Step 1 — Convert

Add raw IPs and domains to `blocklist.txt`, one entry per line. Then run:

```powershell
pwsh ./Convert-Blocklist.ps1
```

- Strips protocols (`http://`, `hxxps://`), URL paths, and bracket obfuscation (`[.]`)
- Validates and classifies each entry as an IPv4 address or domain
- Deduplicates and writes results to `blocklist.json`
- Comments out successfully converted lines in `blocklist.txt`

### Step 2 — Push

```powershell
pwsh ./Push-Blocklist.ps1
```

Opens an SSH session to the FortiDDoS appliance and appends each entry:

```
execute domain-blocklist append domain <domain>
execute ipv4-blocklist append address <ip>
```

Progress is printed in real time:

```
Connecting to 192.168.1.1:22...
Pushing 9 domains and 1 IPs...
  [+] cmailer.pro
  [~] dreamdie.com (duplicate)
  [!] bad..entry (FAILED: Command fail. Return code is 255)
  ...

Done. Added: 8  Skipped: 1  Failed: 1

Failed (check appliance logs):
  domain: bad..entry
```

Running a second time shows all entries as duplicates (`[~]`) — nothing is double-added.

## Output symbols

| Symbol | Meaning |
|--------|---------|
| `[+]` | Added successfully |
| `[~]` | Already on appliance (skipped) |
| `[!]` | Hard failure — check appliance logs |
| `[?]` | Unexpected response — treated as failure |

## File overview

| File | Description |
|------|-------------|
| `blocklist.txt` | Raw input list |
| `Convert-Blocklist.ps1` | Converts `blocklist.txt` → `blocklist.json` |
| `blocklist.json` | Structured intermediate output |
| `Push-Blocklist.ps1` | Pushes `blocklist.json` to FortiDDoS over SSH |
| `config.json.example` | SSH credentials template (committed) |
| `config.json` | SSH credentials — copy from example, fill in values (gitignored) |
