$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $workspace '.env.local'

if (-not (Test-Path -LiteralPath $envFile)) {
  throw "Missing .env.local."
}

$lines = [System.IO.File]::ReadAllLines($envFile, [System.Text.UTF8Encoding]::new($false))
foreach ($line in $lines) {
  $trimmed = $line.Trim()
  if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }

  $parts = $trimmed.Split('=', 2)
  if ($parts.Count -ne 2) { continue }

    [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), 'Process')
}

if (-not $env:ANTHROPIC_BASE_URL) { throw "ANTHROPIC_BASE_URL is not set." }
if (-not $env:ANTHROPIC_API_KEY -and -not $env:ANTHROPIC_AUTH_TOKEN) { throw "ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN is not set." }
if (-not $env:ANTHROPIC_MODEL) { $env:ANTHROPIC_MODEL = 'deepseek-v4-pro' }

if ($env:ANTHROPIC_BASE_URL -match '^https://api\.deepseek\.com/?$') {
  $env:ANTHROPIC_BASE_URL = 'https://api.deepseek.com/anthropic'
}
if ($env:ANTHROPIC_MODEL -eq 'pro') {
  $env:ANTHROPIC_MODEL = 'deepseek-v4-pro'
}
if ($env:ANTHROPIC_MODEL -eq 'flash') {
  $env:ANTHROPIC_MODEL = 'deepseek-v4-flash'
}

if ($env:ANTHROPIC_BASE_URL -match 'api\.deepseek\.com') {
  if (-not $env:ANTHROPIC_AUTH_TOKEN -and $env:ANTHROPIC_API_KEY) {
    $env:ANTHROPIC_AUTH_TOKEN = $env:ANTHROPIC_API_KEY
  }
  Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
}

$headers = @{
  'anthropic-version' = '2023-06-01'
  'content-type' = 'application/json'
}
if ($env:ANTHROPIC_AUTH_TOKEN) {
  $headers['Authorization'] = "Bearer $($env:ANTHROPIC_AUTH_TOKEN)"
} else {
  $headers['x-api-key'] = $env:ANTHROPIC_API_KEY
}

$body = @{
  model = $env:ANTHROPIC_MODEL
  max_tokens = 128
  messages = @(
    @{
      role = 'user'
      content = 'Reply with exactly: OK'
    }
  )
} | ConvertTo-Json -Depth 8

$response = Invoke-RestMethod -Method Post -Uri "$($env:ANTHROPIC_BASE_URL)/v1/messages" -Headers $headers -Body $body -TimeoutSec 60
$textBlock = @($response.content | Where-Object { $_.type -eq 'text' -and $_.text } | Select-Object -First 1)
$text = ''
if ($textBlock) {
  $text = $textBlock.text
}

Write-Output "Model: $($response.model)"
Write-Output "Reply: $text"
Write-Output "Usage: input=$($response.usage.input_tokens), output=$($response.usage.output_tokens)"

if ($text -ne 'OK') {
  throw "Unexpected model reply: $text"
}

Write-Output 'Model test passed.'
