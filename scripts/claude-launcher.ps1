param()

$ErrorActionPreference = 'Stop'

function S([int[]]$Codes) {
  return -join ($Codes | ForEach-Object { [char]$_ })
}

function Quote-Arg([string]$Value) {
  return '"' + ($Value -replace '"', '\"') + '"'
}

function Read-EnvFile([string]$Path) {
  $map = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $map }

  $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false))
  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }

    $parts = $trimmed.Split('=', 2)
    if ($parts.Count -eq 2) {
      $map[$parts[0].Trim()] = $parts[1].Trim()
    }
  }
  return $map
}

function Get-LauncherConfigPath {
  $dir = Join-Path $HOME '.claude-code-oneclick'
  return Join-Path $dir 'launcher.env'
}

function Test-UsableValue([string]$Value) {
  if (-not $Value) { return $false }
  if ($Value -match 'replace_with') { return $false }
  if ($Value -eq 'local-deepseek-proxy') { return $false }
  return $true
}

function Get-MapValue($Primary, $Secondary, [string[]]$Keys, [string]$Fallback) {
  foreach ($key in $Keys) {
    if ($Primary.ContainsKey($key) -and (Test-UsableValue $Primary[$key])) { return $Primary[$key] }
  }
  foreach ($key in $Keys) {
    if ($Secondary.ContainsKey($key) -and (Test-UsableValue $Secondary[$key])) { return $Secondary[$key] }
  }
  return $Fallback
}

function Normalize-ClaudeBaseUrl([string]$Url) {
  $u = $Url.Trim().TrimEnd('/')
  if ($u.EndsWith('/v1', [System.StringComparison]::OrdinalIgnoreCase) -and $u -notmatch 'siliconflow\.(cn|com)') {
    return $u.Substring(0, $u.Length - 3).TrimEnd('/')
  }
  return $u
}

function Test-ProxyProviderUrl([string]$Url) {
  if (-not $Url) { return $false }
  return ($Url -match 'api\.deepseek\.com' -or $Url -match 'siliconflow\.(cn|com)')
}

function Resolve-ProviderModel([string]$Model, [string]$Url) {
  if (-not $Model) { return $Model }
  if ($Url -match 'siliconflow\.(cn|com)') {
    if ($Model -eq 'flash' -or $Model -eq 'deepseek-v4-flash') { return 'deepseek-ai/DeepSeek-V4-Flash' }
    if ($Model -eq 'pro' -or $Model -eq 'deepseek-v4-pro') { return 'deepseek-ai/DeepSeek-V4-Pro' }
  } else {
    if ($Model -eq 'flash') { return 'deepseek-v4-flash' }
    if ($Model -eq 'pro') { return 'deepseek-v4-pro' }
  }
  return $Model
}

function Get-ModelEndpointCandidates([string]$Url) {
  $u = $Url.Trim().TrimEnd('/')
  if ($u -match '^https://api\.deepseek\.com(/anthropic)?/?$') {
    return @('https://api.deepseek.com/models')
  }
  if ($u.EndsWith('/v1', [System.StringComparison]::OrdinalIgnoreCase)) {
    return @("$u/models")
  }
  return @("$u/v1/models", "$u/models")
}

$workspace = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $workspace '.env.local'
$launcherConfigFile = Get-LauncherConfigPath
$envMap = Read-EnvFile $envFile
$globalMap = Read-EnvFile $launcherConfigFile

$defaultBaseUrl = Get-MapValue $envMap $globalMap @('DEEPSEEK_BASE_URL', 'ANTHROPIC_BASE_URL') 'https://api.deepseek.com'
$defaultApiKey = Get-MapValue $envMap $globalMap @('DEEPSEEK_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_API_KEY') ''
$defaultModel = Get-MapValue $envMap $globalMap @('DEEPSEEK_MODEL', 'ANTHROPIC_MODEL') 'deepseek-v4-flash'
$defaultWorkspace = Get-MapValue $envMap $globalMap @('CLAUDE_WORKSPACE') $workspace
$defaultCleanMode = (Get-MapValue $envMap $globalMap @('CLAUDE_CLEAN_MODE') '0') -eq '1'
$defaultHookSafe = (Get-MapValue $envMap $globalMap @('CLAUDE_HOOK_SAFE') '1') -eq '1'

$launcherVersion = '2026.05.27-hook-safe2'
$launcherTitle = 'Claude Code ' + (S @(20013,25991,21551,21160,22120)) + ' ' + $launcherVersion

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = $launcherTitle
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(620, 520)
$form.MinimumSize = New-Object System.Drawing.Size(620, 520)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 27, 24)
$form.ForeColor = [System.Drawing.Color]::FromArgb(246, 232, 214)

$font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$titleFont = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
$form.Font = $font

function Add-Label($text, $x, $y) {
  $label = New-Object System.Windows.Forms.Label
  $label.Text = $text
  $label.AutoSize = $true
  $label.Location = New-Object System.Drawing.Point($x, $y)
  $form.Controls.Add($label)
  return $label
}

function Add-TextBox($x, $y, $w, $text) {
  $box = New-Object System.Windows.Forms.TextBox
  $box.Location = New-Object System.Drawing.Point($x, $y)
  $box.Size = New-Object System.Drawing.Size($w, 28)
  $box.Text = $text
  $form.Controls.Add($box)
  return $box
}

function Add-Combo($x, $y, $w, $items, $selected) {
  $combo = New-Object System.Windows.Forms.ComboBox
  $combo.DropDownStyle = 'DropDownList'
  $combo.Location = New-Object System.Drawing.Point($x, $y)
  $combo.Size = New-Object System.Drawing.Size($w, 28)
  [void]$combo.Items.AddRange($items)
  if ($items -contains $selected) {
    $combo.SelectedItem = $selected
  } else {
    [void]$combo.Items.Insert(0, $selected)
    $combo.SelectedItem = $selected
  }
  $form.Controls.Add($combo)
  return $combo
}

function New-ConfigContent([string]$BaseUrl, [string]$ApiKey, [string]$Model, [string]$Folder, [bool]$CleanMode, [bool]$HookSafe) {
  $selectedBaseUrl = Normalize-ClaudeBaseUrl $BaseUrl
  $selectedModel = Resolve-ProviderModel $Model $selectedBaseUrl
  $cleanValue = $(if ($CleanMode) { '1' } else { '0' })
  $hookSafeValue = $(if ($HookSafe) { '1' } else { '0' })
  if ((Test-ProxyProviderUrl $selectedBaseUrl) -or $selectedModel -like 'deepseek-*' -or $selectedModel -like 'deepseek-ai/*' -or $selectedModel -like 'Pro/*') {
    if ($selectedBaseUrl -match 'siliconflow\.(cn|com)' -and $selectedModel -notlike 'deepseek-ai/*' -and $selectedModel -notlike 'Pro/*') {
      throw "SiliconFlow must use a SiliconFlow model id, for example deepseek-ai/DeepSeek-V4-Flash."
    }
    return @(
      "DEEPSEEK_BASE_URL=$selectedBaseUrl",
      "DEEPSEEK_API_KEY=$ApiKey",
      "DEEPSEEK_MODEL=$selectedModel",
      "ANTHROPIC_BASE_URL=http://127.0.0.1:17860",
      "ANTHROPIC_AUTH_TOKEN=local-deepseek-proxy",
      "ANTHROPIC_MODEL=$selectedModel",
      "CLAUDE_WORKSPACE=$Folder",
      "CLAUDE_CLEAN_MODE=$cleanValue",
      "CLAUDE_HOOK_SAFE=$hookSafeValue"
    ) -join [Environment]::NewLine
  }
  return @(
    "ANTHROPIC_BASE_URL=$selectedBaseUrl",
    "ANTHROPIC_API_KEY=$ApiKey",
    "ANTHROPIC_MODEL=$selectedModel",
    "CLAUDE_WORKSPACE=$Folder",
    "CLAUDE_CLEAN_MODE=$cleanValue",
    "CLAUDE_HOOK_SAFE=$hookSafeValue"
  ) -join [Environment]::NewLine
}

function Save-Config([string]$BaseUrl, [string]$ApiKey, [string]$Model, [string]$Folder, [bool]$CleanMode, [bool]$HookSafe) {
  $content = New-ConfigContent $BaseUrl $ApiKey $Model $Folder $CleanMode $HookSafe
  [System.IO.File]::WriteAllText($envFile, $content + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
  $configDir = Split-Path -Parent $launcherConfigFile
  New-Item -ItemType Directory -Force -Path $configDir | Out-Null
  [System.IO.File]::WriteAllText($launcherConfigFile, $content + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
  return $content
}

$title = New-Object System.Windows.Forms.Label
$title.Text = $launcherTitle
$title.Font = $titleFont
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(24, 20)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Local gateway / SiliconFlow proxy / model detect'
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(214, 139, 82)
$subtitle.Location = New-Object System.Drawing.Point(26, 55)
$form.Controls.Add($subtitle)

[void](Add-Label ((S @(19978,28216,22320,22336)) + ' / URL') 28 92)
$urlBox = Add-TextBox 150 88 320 $defaultBaseUrl

$detectButton = New-Object System.Windows.Forms.Button
$detectButton.Text = S @(26816,27979,27169,22411)
$detectButton.Size = New-Object System.Drawing.Size(92, 30)
$detectButton.Location = New-Object System.Drawing.Point(482, 86)
$detectButton.BackColor = [System.Drawing.Color]::FromArgb(64, 55, 47)
$detectButton.ForeColor = [System.Drawing.Color]::FromArgb(246, 232, 214)
$detectButton.FlatStyle = 'Flat'
$form.Controls.Add($detectButton)

[void](Add-Label 'API Key' 28 132)
$keyBox = Add-TextBox 150 128 424 $defaultApiKey
$keyBox.UseSystemPasswordChar = $true

[void](Add-Label ((S @(24037,20316,25991,20214,22841)) + ' / Folder') 28 172)
$folderBox = Add-TextBox 150 168 320 $defaultWorkspace

$folderButton = New-Object System.Windows.Forms.Button
$folderButton.Text = S @(36873,25321)
$folderButton.Size = New-Object System.Drawing.Size(92, 30)
$folderButton.Location = New-Object System.Drawing.Point(482, 166)
$folderButton.BackColor = [System.Drawing.Color]::FromArgb(64, 55, 47)
$folderButton.ForeColor = [System.Drawing.Color]::FromArgb(246, 232, 214)
$folderButton.FlatStyle = 'Flat'
$form.Controls.Add($folderButton)

[void](Add-Label ((S @(27169,22411)) + ' / Model') 28 212)
$modelCombo = Add-Combo 150 208 424 @('deepseek-v4-flash', 'deepseek-v4-pro', 'deepseek-ai/DeepSeek-V4-Flash', 'deepseek-ai/DeepSeek-V4-Pro', 'flash', 'pro', 'gpt-5.5', 'gpt-5.4', 'gpt-5.4-mini', 'gpt-5.3-codex', 'gpt-5.2') $defaultModel

[void](Add-Label ((S @(24605,32771,31243,24230)) + ' / Effort') 28 252)
$effortCombo = Add-Combo 150 248 424 @('low', 'medium', 'high', 'xhigh', 'max') 'medium'

[void](Add-Label ((S @(21551,21160,27169,24335)) + ' / Mode') 28 292)
$modeCombo = Add-Combo 150 288 424 @('default', 'acceptEdits', 'plan', 'dontAsk', 'bypassPermissions') 'default'

$chineseCheck = New-Object System.Windows.Forms.CheckBox
$chineseCheck.Text = S @(20013,25991,21451,22909)
$chineseCheck.Checked = $true
$chineseCheck.AutoSize = $true
$chineseCheck.Location = New-Object System.Drawing.Point(150, 328)
$form.Controls.Add($chineseCheck)

$bareCheck = New-Object System.Windows.Forms.CheckBox
$bareCheck.Text = (S @(31934,31616,27169,24335)) + ' / Bare'
$bareCheck.Checked = $false
$bareCheck.AutoSize = $true
$bareCheck.Location = New-Object System.Drawing.Point(270, 328)
$form.Controls.Add($bareCheck)

$petCheck = New-Object System.Windows.Forms.CheckBox
$petCheck.Text = (S @(26700,23456)) + ' / Pet'
$petCheck.Checked = $true
$petCheck.AutoSize = $true
$petCheck.Location = New-Object System.Drawing.Point(370, 328)
$form.Controls.Add($petCheck)

$motionCheck = New-Object System.Windows.Forms.CheckBox
$motionCheck.Text = 'Motion'
$motionCheck.Checked = $false
$motionCheck.AutoSize = $true
$motionCheck.Location = New-Object System.Drawing.Point(470, 328)
$form.Controls.Add($motionCheck)

$cleanCheck = New-Object System.Windows.Forms.CheckBox
$cleanCheck.Text = 'Clean / No Hooks'
$cleanCheck.Checked = $defaultCleanMode
$cleanCheck.AutoSize = $true
$cleanCheck.Location = New-Object System.Drawing.Point(150, 355)
$form.Controls.Add($cleanCheck)

$hookSafeCheck = New-Object System.Windows.Forms.CheckBox
$hookSafeCheck.Text = 'Hook Safe'
$hookSafeCheck.Checked = $defaultHookSafe
$hookSafeCheck.AutoSize = $true
$hookSafeCheck.Location = New-Object System.Drawing.Point(300, 355)
$form.Controls.Add($hookSafeCheck)

$status = New-Object System.Windows.Forms.Label
$status.Text = S @(25552,31034,65306,21487,36755,20837,32,47,118,49,32,25110,19981,24102,32,47,118,49,32,30340,19978,28216,22320,22336,65292,28857,20987,26816,27979,27169,22411,12290)
$status.Size = New-Object System.Drawing.Size(546, 45)
$status.ForeColor = [System.Drawing.Color]::FromArgb(180, 169, 158)
$status.Location = New-Object System.Drawing.Point(28, 382)
$form.Controls.Add($status)

$launchButton = New-Object System.Windows.Forms.Button
$launchButton.Text = S @(21551,21160,32,67,108,97,117,100,101,32,67,111,100,101)
$launchButton.Size = New-Object System.Drawing.Size(180, 38)
$launchButton.Location = New-Object System.Drawing.Point(160, 435)
$launchButton.BackColor = [System.Drawing.Color]::FromArgb(214, 139, 82)
$launchButton.ForeColor = [System.Drawing.Color]::FromArgb(24, 21, 18)
$launchButton.FlatStyle = 'Flat'
$form.Controls.Add($launchButton)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = 'Save Config'
$saveButton.Size = New-Object System.Drawing.Size(150, 38)
$saveButton.Location = New-Object System.Drawing.Point(360, 435)
$saveButton.BackColor = [System.Drawing.Color]::FromArgb(64, 55, 47)
$saveButton.ForeColor = [System.Drawing.Color]::FromArgb(246, 232, 214)
$saveButton.FlatStyle = 'Flat'
$form.Controls.Add($saveButton)

$folderButton.Add_Click({
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = S @(36873,25321,32,67,108,97,117,100,101,32,67,111,100,101,32,21551,21160,30340,24037,20316,25991,20214,22841)
  if (Test-Path -LiteralPath $folderBox.Text) {
    $dialog.SelectedPath = $folderBox.Text
  }
  if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $folderBox.Text = $dialog.SelectedPath
  }
})

$detectButton.Add_Click({
  try {
    $detectButton.Enabled = $false
    $status.Text = S @(27491,22312,26816,27979,19978,28216,27169,22411,46,46,46)
    [System.Windows.Forms.Application]::DoEvents()

    $headers = @{
      Authorization = "Bearer $($keyBox.Text)"
      'x-api-key' = $keyBox.Text
    }

    $models = @()
    $usedEndpoint = $null
    foreach ($endpoint in (Get-ModelEndpointCandidates $urlBox.Text)) {
      try {
        $response = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $headers -TimeoutSec 15
        if ($response.data) {
          $models = @($response.data | ForEach-Object { $_.id } | Where-Object { $_ })
        }
        if ($models.Count -gt 0) {
          $usedEndpoint = $endpoint
          break
        }
      } catch {
      }
    }

    if ($models.Count -eq 0) {
      throw 'No models returned.'
    }

    $current = $modelCombo.Text
    $modelCombo.Items.Clear()
    [void]$modelCombo.Items.AddRange([string[]]$models)
    if ($models -contains $current) {
      $modelCombo.SelectedItem = $current
    } elseif ($models -contains $defaultModel) {
      $modelCombo.SelectedItem = $defaultModel
    } else {
      $modelCombo.SelectedIndex = 0
    }

    $claudeBase = Normalize-ClaudeBaseUrl $urlBox.Text
    $status.Text = (S @(26816,27979,25104,21151,65306)) + " $($models.Count) models, endpoint: $usedEndpoint, Claude base: $claudeBase"
  } catch {
    $status.Text = (S @(26816,27979,22833,36133,65306)) + " $($_.Exception.Message)"
  } finally {
    $detectButton.Enabled = $true
  }
})

$saveButton.Add_Click({
  try {
    if (-not (Test-Path -LiteralPath $folderBox.Text)) {
      [System.Windows.Forms.MessageBox]::Show((S @(24037,20316,25991,20214,22841,19981,23384,22312)) + ": $($folderBox.Text)", $launcherTitle) | Out-Null
      return
    }
    $selectedModel = [string]$modelCombo.SelectedItem
    [void](Save-Config $urlBox.Text $keyBox.Text $selectedModel $folderBox.Text $cleanCheck.Checked $hookSafeCheck.Checked)
    $status.Text = "Saved config to .env.local and $launcherConfigFile"
  } catch {
    [System.Windows.Forms.MessageBox]::Show("Failed to save config: $($_.Exception.Message)", $launcherTitle) | Out-Null
  }
})

$launchButton.Add_Click({
  if (-not (Test-Path -LiteralPath $folderBox.Text)) {
    [System.Windows.Forms.MessageBox]::Show((S @(24037,20316,25991,20214,22841,19981,23384,22312)) + ": $($folderBox.Text)", $launcherTitle) | Out-Null
    return
  }

  try {
    $selectedModel = [string]$modelCombo.SelectedItem
    [void](Save-Config $urlBox.Text $keyBox.Text $selectedModel $folderBox.Text $cleanCheck.Checked $hookSafeCheck.Checked)
    $selectedBaseUrl = Normalize-ClaudeBaseUrl $urlBox.Text
    $selectedModel = Resolve-ProviderModel $selectedModel $selectedBaseUrl
  } catch {
    [System.Windows.Forms.MessageBox]::Show("Failed to save config: $($_.Exception.Message)", $launcherTitle) | Out-Null
    return
  }

  $script = Join-Path $workspace 'scripts\start-claude.ps1'
  $argList = @(
    '-NoExit',
    '-ExecutionPolicy', 'BYPASS',
    '-File', (Quote-Arg $script),
    '-BaseUrl', (Quote-Arg $urlBox.Text),
    '-ApiKey', (Quote-Arg $keyBox.Text),
    '-Model', (Quote-Arg $selectedModel),
    '-Effort', (Quote-Arg $effortCombo.SelectedItem)
  )
  if ($modeCombo.SelectedItem -ne 'default') {
    $argList += @('-PermissionMode', (Quote-Arg $modeCombo.SelectedItem))
  }
  if (-not $chineseCheck.Checked) {
    $argList += '-NoChinesePrompt'
  }
  if ($bareCheck.Checked) {
    $argList += '-Bare'
  }
  if ($cleanCheck.Checked) {
    $argList += '-CleanMode'
  }
  if ($hookSafeCheck.Checked) {
    $argList += '-HookSafe'
  }
  if (-not $petCheck.Checked) {
    $argList += '-NoPet'
  }
  if ($motionCheck.Checked) {
    $argList += '-PetMotion'
  }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
  $psi.Arguments = ($argList -join ' ')
  $psi.WorkingDirectory = $folderBox.Text
  [void][System.Diagnostics.Process]::Start($psi)
  $form.Close()
})

[void]$form.ShowDialog()
