# FortiDDoS Blocklist Append

PowerShell 7 scripts that convert a raw blocklist into structured JSON and push it to a FortiDDoS appliance over SSH.

## Workflow

```
blocklist.txt  →  Convert-Blocklist.ps1  →  blocklist.json  →  Push-Blocklist.ps1  →  FortiDDoS
```

## Files

| File | Purpose |
|------|---------|
| `blocklist.txt` | Raw input: one IP or domain per line; converted entries are commented out automatically |
| `Convert-Blocklist.ps1` | Parses `blocklist.txt`, validates and deduplicates entries, writes `blocklist.json` |
| `blocklist.json` | Intermediate output: `blocked_domains` and `blocked_ips` arrays |
| `Push-Blocklist.ps1` | Reads `blocklist.json`, SSHs into FortiDDoS, appends each entry via CLI |
| `config.json` | SSH credentials — **never committed** (gitignored) |

## Setup

```powershell
# Install SSH module once
Install-Module -Name Posh-SSH -Scope CurrentUser

# Fill in real credentials
# config.json: { "host", "port", "username", "password" }
```

## Running

```powershell
# Step 1: convert raw list to JSON
pwsh ./Convert-Blocklist.ps1

# Step 2: push to appliance
pwsh ./Push-Blocklist.ps1
```

## FortiDDoS CLI commands used

```
execute domain-blocklist append domain <domain>
execute ipv4-blocklist append address <ip>
```

## Output classification

| Symbol | Meaning |
|--------|---------|
| `[+]` | Successfully added |
| `[~]` | Duplicate — already on appliance |
| `[!]` | Hard failure — check appliance logs |
| `[?]` | Unexpected output — treated as failure |

Empty SSH output = success. `already exists` = duplicate. `Command fail` = hard error.
