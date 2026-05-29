param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$Prompt,
  [switch]$Print,
  [string]$Model,
  [ValidateSet('low', 'medium', 'high', 'xhigh', 'max')]
  [string]$Effort,
  [ValidateSet('acceptEdits', 'auto', 'bypassPermissions', 'default', 'dontAsk', 'plan')]
  [string]$PermissionMode,
  [string]$BaseUrl,
  [string]$ApiKey,
  [switch]$Bare,
  [switch]$DisableHooks,
  [switch]$HookSafe,
  [switch]$CleanMode,
  [switch]$NoPet,
  [double]$PetScale = 0.48,
  [switch]$PetMotion,
  [switch]$NoChinesePrompt,
  [switch]$NoChineseUiHelp
)

$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $workspace '.env.local'
$proxyProcess = $null
$proxyLog = Join-Path $workspace 'deepseek-proxy.log'

function Test-ProxyProviderUrl([string]$Value) {
  if (-not $Value) { return $false }
  return ($Value -match 'api\.deepseek\.com' -or $Value -match 'siliconflow\.(cn|com)')
}

function Test-ProxyProviderModel([string]$Value) {
  if (-not $Value) { return $false }
  return ($Value -like 'deepseek-*' -or $Value -like 'deepseek-ai/*' -or $Value -like 'Pro/*')
}

function Resolve-ProviderModel([string]$Value, [string]$BaseUrl) {
  if (-not $Value) { return $Value }
  $isSilicon = ($BaseUrl -match 'siliconflow\.(cn|com)')
  if ($isSilicon) {
    if ($Value -eq 'flash' -or $Value -eq 'deepseek-v4-flash') { return 'deepseek-ai/DeepSeek-V4-Flash' }
    if ($Value -eq 'pro' -or $Value -eq 'deepseek-v4-pro') { return 'deepseek-ai/DeepSeek-V4-Pro' }
  } else {
    if ($Value -eq 'flash') { return 'deepseek-v4-flash' }
    if ($Value -eq 'pro') { return 'deepseek-v4-pro' }
  }
  return $Value
}

function Repair-HookifyPromptRules([string[]]$Roots) {
  $seen = @{}
  foreach ($root in $Roots) {
    if (-not $root) { continue }
    $claudeDir = Join-Path $root '.claude'
    if (-not (Test-Path -LiteralPath $claudeDir)) { continue }
    Get-ChildItem -LiteralPath $claudeDir -Filter 'hookify.*.local.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ($seen.ContainsKey($_.FullName)) { return }
      $seen[$_.FullName] = $true
      try {
        $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.UTF8Encoding]::new($false))
        $eventLine = [regex]::Match($text, '(?im)^\s*event\s*:\s*([A-Za-z]+)\s*(?:#.*)?$')
        $eventName = $(if ($eventLine.Success) { $eventLine.Groups[1].Value.ToLowerInvariant() } else { '' })
        $isPromptRule = ($eventName -eq '' -or $eventName -eq 'prompt' -or $eventName -eq 'userprompt' -or $eventName -eq 'userpromptsubmit' -or $eventName -eq 'all')
        $isBlocking = ($text -match '(?im)^\s*action\s*:\s*[''"]?block[''"]?\s*(?:#.*)?$')
        $noKeywordText = -join (@(19981, 21253, 21547, 20219, 20309, 25351, 23450) | ForEach-Object { [char]$_ })
        $keywordText = -join (@(25351, 23450, 30340, 20851, 38190, 35789) | ForEach-Object { [char]$_ })
        $anyKeywordText = -join (@(20219, 20309, 20851, 38190, 35789) | ForEach-Object { [char]$_ })
        $userMessageText = -join (@(29992, 25143, 28040, 24687) | ForEach-Object { [char]$_ })
        $greetingText = -join (@(31616, 21333, 38382, 20505) | ForEach-Object { [char]$_ })
        $learnText = -join (@(23398, 20064, 35760, 24405) | ForEach-Object { [char]$_ })
        $looksLikeGate = ($text -match '(?im)^\s*operator\s*:\s*[''"]?not_contains[''"]?\s*(?:#.*)?$' -or $text.Contains($noKeywordText) -or $text.Contains($keywordText) -or $text.Contains($anyKeywordText) -or $text.Contains($userMessageText) -or $text.Contains($greetingText) -or $text.Contains($learnText))
        if ($isPromptRule -and $isBlocking -and $looksLikeGate) {
          $backup = "$($_.FullName).bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
          Copy-Item -LiteralPath $_.FullName -Destination $backup -Force
          if ($text -match '(?im)^\s*enabled\s*:') {
            $fixed = [regex]::Replace($text, '(?im)^(\s*enabled\s*:\s*)true(\s*(?:#.*)?)$', '${1}false${2}')
          } else {
            $fixed = [regex]::Replace($text, '(?m)^---\s*$', "---`nenabled: false", 1)
          }
          $fixed = [regex]::Replace($fixed, '(?im)^(\s*action\s*:\s*)[''"]?block[''"]?(\s*(?:#.*)?)$', '${1}warn${2}')
          if ($fixed -ne $text) {
            [System.IO.File]::WriteAllText($_.FullName, $fixed, [System.Text.UTF8Encoding]::new($false))
            Write-Host "HookSafe: disabled blocking prompt hookify rule: $($_.FullName)" -ForegroundColor Yellow
          }
        }
      } catch {
        Write-Warning "HookSafe failed for $($_.FullName): $($_.Exception.Message)"
      }
    }
  }
}

function Repair-UserPromptSubmitPromptHooks([string[]]$Roots) {
  $seen = @{}
  foreach ($root in $Roots) {
    if (-not $root) { continue }
    $claudeDir = Join-Path $root '.claude'
    if (-not (Test-Path -LiteralPath $claudeDir)) { continue }
    Get-ChildItem -LiteralPath $claudeDir -Filter 'settings*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ($seen.ContainsKey($_.FullName)) { return }
      $seen[$_.FullName] = $true
      try {
        $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.UTF8Encoding]::new($false))
        if ($text -notmatch '"UserPromptSubmit"') { return }
        if ($text -notmatch '"type"\s*:\s*"(prompt|agent)"' -and $text -notmatch '"UserPromptSubmit"\s*:') { return }

        $m = [regex]::Match($text, '"UserPromptSubmit"\s*:')
        if (-not $m.Success) { return }
        $valueStart = $m.Index + $m.Length
        while ($valueStart -lt $text.Length -and [char]::IsWhiteSpace($text[$valueStart])) { $valueStart++ }
        if ($valueStart -ge $text.Length) { return }

        $open = $text[$valueStart]
        if ($open -ne '[' -and $open -ne '{') { return }
        $close = $(if ($open -eq '[') { ']' } else { '}' })
        $depth = 0
        $inString = $false
        $escape = $false
        $valueEnd = -1
        for ($i = $valueStart; $i -lt $text.Length; $i++) {
          $ch = $text[$i]
          if ($inString) {
            if ($escape) {
              $escape = $false
            } elseif ($ch -eq '\') {
              $escape = $true
            } elseif ($ch -eq '"') {
              $inString = $false
            }
            continue
          }
          if ($ch -eq '"') {
            $inString = $true
          } elseif ($ch -eq $open) {
            $depth++
          } elseif ($ch -eq $close) {
            $depth--
            if ($depth -eq 0) {
              $valueEnd = $i + 1
              break
            }
          }
        }
        if ($valueEnd -lt 0) { return }

        $removeStart = $m.Index
        $removeEnd = $valueEnd
        $before = $text.Substring(0, $removeStart)
        $after = $text.Substring($removeEnd)

        $j = $removeStart - 1
        while ($j -ge 0 -and [char]::IsWhiteSpace($text[$j])) { $j-- }
        if ($j -ge 0 -and $text[$j] -eq ',') {
          $removeStart = $j
          $before = $text.Substring(0, $removeStart)
        } else {
          $k = 0
          while ($k -lt $after.Length -and [char]::IsWhiteSpace($after[$k])) { $k++ }
          if ($k -lt $after.Length -and $after[$k] -eq ',') {
            $after = $after.Substring($k + 1)
          }
        }

        $fixed = $before + $after
        if ($fixed -ne $text) {
          $backup = "$($_.FullName).bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
          Copy-Item -LiteralPath $_.FullName -Destination $backup -Force
          [System.IO.File]::WriteAllText($_.FullName, $fixed, [System.Text.UTF8Encoding]::new($false))
          Write-Host "HookSafe: removed UserPromptSubmit hooks from settings: $($_.FullName)" -ForegroundColor Yellow
        }
      } catch {
        Write-Warning "HookSafe settings repair failed for $($_.FullName): $($_.Exception.Message)"
      }
    }
  }
}

if ((-not $Prompt -or $Prompt.Count -eq 0) -and $args -and $args.Count -gt 0) {
  $Prompt = $args
}

if (-not (Test-Path -LiteralPath $envFile)) {
  throw "Missing .env.local. Create it from the expected local gateway settings first."
}

$lines = [System.IO.File]::ReadAllLines($envFile, [System.Text.UTF8Encoding]::new($false))
foreach ($line in $lines) {
  $trimmed = $line.Trim()
  if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }

  $parts = $trimmed.Split('=', 2)
  if ($parts.Count -ne 2) { continue }

  [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), 'Process')
}

$env:DISABLE_AUTOUPDATER = '1'
$env:DISABLE_UPDATES = '1'
if ($CleanMode) {
  $env:CLAUDE_CODE_SIMPLE = '1'
} else {
  Remove-Item Env:\CLAUDE_CODE_SIMPLE -ErrorAction SilentlyContinue
}
if ($HookSafe -and -not $CleanMode) {
  Repair-HookifyPromptRules @($workspace, (Get-Location).Path, $HOME)
  Repair-UserPromptSubmitPromptHooks @($workspace, (Get-Location).Path, $HOME)
}

$projectCommands = Join-Path $workspace '.claude\commands'
$userCommands = Join-Path $HOME '.claude\commands'
if (Test-Path -LiteralPath $projectCommands) {
  try {
    New-Item -ItemType Directory -Force -Path $userCommands | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectCommands 'pet*.md') -Destination $userCommands -Force -ErrorAction SilentlyContinue
  } catch {
    Write-Warning "Claude pet commands failed to sync: $($_.Exception.Message)"
  }
}

if (-not $Print -and -not $NoPet) {
  $petScript = Join-Path $workspace 'scripts\claude-pet.ps1'
  if (Test-Path -LiteralPath $petScript) {
    try {
      $petArgs = @(
        '-NoProfile',
        '-Sta',
        '-WindowStyle', 'Minimized',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$petScript`"",
        '-Workspace', "`"$workspace`"",
        '-Scale', ([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.##}', $PetScale))
      )
      if (-not $PetMotion) {
        $petArgs += '-ReducedMotion'
      }
      Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList ($petArgs -join ' ') `
        -WorkingDirectory $workspace | Out-Null
    } catch {
      Write-Warning "Claude pet failed to start: $($_.Exception.Message)"
    }
  }
}

if (-not $env:ANTHROPIC_MODEL) {
  $env:ANTHROPIC_MODEL = 'gpt-5.5'
}

if ($Model) {
  $env:ANTHROPIC_MODEL = $Model
}
if ($BaseUrl) {
  $normalizedBaseUrl = $BaseUrl.Trim().TrimEnd('/')
  if ($normalizedBaseUrl.EndsWith('/v1', [System.StringComparison]::OrdinalIgnoreCase) -and $normalizedBaseUrl -notmatch 'siliconflow\.(cn|com)') {
    $normalizedBaseUrl = $normalizedBaseUrl.Substring(0, $normalizedBaseUrl.Length - 3).TrimEnd('/')
  }
  $env:ANTHROPIC_BASE_URL = $normalizedBaseUrl
  if (Test-ProxyProviderUrl $normalizedBaseUrl) {
    $env:DEEPSEEK_BASE_URL = $normalizedBaseUrl
  } else {
    Remove-Item Env:\DEEPSEEK_BASE_URL -ErrorAction SilentlyContinue
  }
}

$providerBaseUrl = $(if ($env:DEEPSEEK_BASE_URL) { $env:DEEPSEEK_BASE_URL } else { $env:ANTHROPIC_BASE_URL })
$env:ANTHROPIC_MODEL = Resolve-ProviderModel $env:ANTHROPIC_MODEL $providerBaseUrl
$env:DEEPSEEK_MODEL = Resolve-ProviderModel $env:DEEPSEEK_MODEL $providerBaseUrl

$baseLooksProxyProvider = ((Test-ProxyProviderUrl $env:ANTHROPIC_BASE_URL) -or (Test-ProxyProviderUrl $env:DEEPSEEK_BASE_URL))
if (-not $baseLooksProxyProvider) {
  Remove-Item Env:\DEEPSEEK_API_KEY -ErrorAction SilentlyContinue
  Remove-Item Env:\DEEPSEEK_BASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:\DEEPSEEK_MODEL -ErrorAction SilentlyContinue
  if ($env:ANTHROPIC_AUTH_TOKEN -eq 'local-deepseek-proxy') {
    Remove-Item Env:\ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
  }
}

if ($Model) {
  $env:DEEPSEEK_MODEL = $env:ANTHROPIC_MODEL
}

$isDeepSeek = ((Test-ProxyProviderUrl $env:ANTHROPIC_BASE_URL) -or (Test-ProxyProviderUrl $env:DEEPSEEK_BASE_URL) -or $env:ANTHROPIC_AUTH_TOKEN -eq 'local-deepseek-proxy' -or (Test-ProxyProviderModel $env:ANTHROPIC_MODEL) -or (Test-ProxyProviderModel $env:DEEPSEEK_MODEL))
if ($ApiKey) {
  if ($isDeepSeek) {
    $env:DEEPSEEK_API_KEY = $ApiKey
  } else {
    $env:ANTHROPIC_API_KEY = $ApiKey
  }
}
if ($isDeepSeek) {
  if (-not $env:DEEPSEEK_API_KEY -and $env:ANTHROPIC_AUTH_TOKEN -and $env:ANTHROPIC_AUTH_TOKEN -ne 'local-deepseek-proxy') {
    $env:DEEPSEEK_API_KEY = $env:ANTHROPIC_AUTH_TOKEN
  }
  if (-not $env:DEEPSEEK_API_KEY -or $env:DEEPSEEK_API_KEY -match 'replace_with') {
    throw "Missing DeepSeek API key. Put it in DEEPSEEK_API_KEY or the launcher API Key box."
  }
  if (-not $env:DEEPSEEK_MODEL) {
    $env:DEEPSEEK_MODEL = $env:ANTHROPIC_MODEL
  }
  if (-not $env:DEEPSEEK_MODEL -or $env:DEEPSEEK_MODEL -eq 'gpt-5.5') {
    if ((Test-ProxyProviderUrl $env:ANTHROPIC_BASE_URL) -and $env:ANTHROPIC_BASE_URL -match 'siliconflow\.(cn|com)') {
      $env:DEEPSEEK_MODEL = 'deepseek-ai/DeepSeek-V4-Flash'
    } else {
      $env:DEEPSEEK_MODEL = 'deepseek-v4-flash'
    }
  }
  $env:DEEPSEEK_MODEL = Resolve-ProviderModel $env:DEEPSEEK_MODEL $(if ($env:DEEPSEEK_BASE_URL) { $env:DEEPSEEK_BASE_URL } else { $env:ANTHROPIC_BASE_URL })
  $env:ANTHROPIC_MODEL = $env:DEEPSEEK_MODEL
  $env:ANTHROPIC_AUTH_TOKEN = 'local-deepseek-proxy'
  Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue

  $proxyScript = Join-Path $workspace 'scripts\deepseek-claude-proxy.cjs'
  if (-not (Test-Path -LiteralPath $proxyScript)) {
    throw "Missing DeepSeek proxy script: $proxyScript"
  }
  $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
  if (-not $nodeCmd) {
    throw "Node.js is required for the DeepSeek local proxy."
  }

  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), 0)
  $listener.Start()
  $proxyPort = $listener.LocalEndpoint.Port
  $listener.Stop()

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $nodeCmd.Source
  $psi.Arguments = "`"$proxyScript`""
  $psi.WorkingDirectory = $workspace
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardError = $false
  $psi.RedirectStandardOutput = $false
  $psi.EnvironmentVariables['DEEPSEEK_PROXY_PORT'] = [string]$proxyPort
  $psi.EnvironmentVariables['DEEPSEEK_BASE_URL'] = $(if ($env:DEEPSEEK_BASE_URL) { $env:DEEPSEEK_BASE_URL } elseif (Test-ProxyProviderUrl $env:ANTHROPIC_BASE_URL) { $env:ANTHROPIC_BASE_URL } else { 'https://api.deepseek.com' })
  $psi.EnvironmentVariables['DEEPSEEK_API_KEY'] = $env:DEEPSEEK_API_KEY
  $psi.EnvironmentVariables['DEEPSEEK_MODEL'] = $env:DEEPSEEK_MODEL
  $psi.EnvironmentVariables['DEEPSEEK_PROXY_LOG'] = $proxyLog
  $proxyProcess = [System.Diagnostics.Process]::Start($psi)

  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 250
    try {
      $health = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$proxyPort/health" -TimeoutSec 2
      if ($health.ok) { break }
    } catch {
    }
    if ($i -eq 39) {
      throw "DeepSeek local proxy failed to start."
    }
  }
  $env:ANTHROPIC_BASE_URL = "http://127.0.0.1:$proxyPort"
  "[$(Get-Date -Format s)] proxy started on $($env:ANTHROPIC_BASE_URL), model=$($env:DEEPSEEK_MODEL)" | Out-File -LiteralPath $proxyLog -Encoding utf8 -Append
}

$claudeArgs = @('--model', $env:ANTHROPIC_MODEL)
if ($Effort -and -not $isDeepSeek) {
  $claudeArgs += @('--effort', $Effort)
}
if ($PermissionMode) {
  $claudeArgs += @('--permission-mode', $PermissionMode)
}
if ($Bare) {
  $claudeArgs = @('--bare') + $claudeArgs
}
if ($DisableHooks -and -not $CleanMode) {
  $claudeArgs += @('--settings', '{"disableAllHooks":true}')
}
if (-not $NoChinesePrompt) {
  $promptFile = Join-Path $workspace 'prompts\chinese-friendly.md'
  if (Test-Path -LiteralPath $promptFile) {
    $chinesePrompt = [System.IO.File]::ReadAllText($promptFile, [System.Text.UTF8Encoding]::new($false))
    $claudeArgs += @('--append-system-prompt', $chinesePrompt)
  }
}
if ($Print) {
  $claudeArgs += '-p'
}
if ($env:CLAUDE_LAUNCHER_DEBUG -eq '1') {
  Write-Output ($claudeArgs | ForEach-Object { "ARG: $_" })
}

$claudeCmd = Join-Path $workspace 'node_modules\.bin\claude.cmd'
if (-not (Test-Path -LiteralPath $claudeCmd)) {
  $claudeCmd = 'npx'
  $claudeArgs = @('claude') + $claudeArgs
}

if (-not $Print -and -not $NoChinesePrompt -and -not $NoChineseUiHelp) {
  $uiHelpFile = Join-Path $workspace 'docs\claude-code-ui-zh.md'
  if (Test-Path -LiteralPath $uiHelpFile) {
    $uiHelp = [System.IO.File]::ReadAllText($uiHelpFile, [System.Text.UTF8Encoding]::new($false))
    Write-Host ''
    Write-Host $uiHelp -ForegroundColor Cyan
    Write-Host ''
  }
}

try {
  if ($Prompt -and $Prompt.Count -gt 0) {
    $inputText = $Prompt -join ' '
    $inputText | & $claudeCmd @claudeArgs
  } else {
    & $claudeCmd @claudeArgs
  }
  $exitCode = $LASTEXITCODE
} finally {
  if ($proxyProcess -and -not $proxyProcess.HasExited) {
    try {
      $proxyProcess.Kill()
      $proxyProcess.WaitForExit(3000) | Out-Null
    } catch {
    }
  }
}
exit $exitCode
