param(
  [string]$SupabaseUrl = "",
  [string]$ServiceRoleKey = "",
  [string]$CleanCsvPath = "supabase\imports\workpulse_employee_import_clean.csv",
  [string]$OutputDirectory = "supabase\imports",
  [string[]]$PilotNames = @(
    "William Nyanja",
    "LOWRY NATALA",
    "WAKUNGOLI LUBASI",
    "Paul Chinyemba",
    "Ithamar Nyangu"
  ),
  [switch]$Execute
)

$ErrorActionPreference = "Stop"

function Normalize-Name {
  param([string]$Value)
  if ($null -eq $Value) {
    return ""
  }
  return ($Value.Trim() -replace "\s+", " ").ToLowerInvariant()
}

function New-TemporaryPassword {
  $bytes = [byte[]]::new(18)
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $base = [Convert]::ToBase64String($bytes)
  return ($base -replace "[+/=]", "x") + "A1!"
}

function Read-AppEnv {
  $envPath = Join-Path (Get-Location) "env.json"
  if (Test-Path $envPath) {
    return Get-Content $envPath -Raw | ConvertFrom-Json
  }
  return $null
}

$appEnv = Read-AppEnv
if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -and $null -ne $appEnv) {
  $SupabaseUrl = $appEnv.SUPABASE_URL
}
if ([string]::IsNullOrWhiteSpace($ServiceRoleKey)) {
  $ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  throw "SupabaseUrl is required. Pass -SupabaseUrl or add SUPABASE_URL to env.json."
}

if ($Execute -and [string]::IsNullOrWhiteSpace($ServiceRoleKey)) {
  throw "Service role key is required when -Execute is used. Set `$env:SUPABASE_SERVICE_ROLE_KEY or pass -ServiceRoleKey."
}

$employees = Import-Csv $CleanCsvPath
$targetNames = @{}
foreach ($name in $PilotNames) {
  $targetNames[(Normalize-Name $name)] = $true
}

$pilotRows = $employees |
  Where-Object { $targetNames.ContainsKey((Normalize-Name $_.full_name)) } |
  Sort-Object full_name

$missingNames = @()
foreach ($name in $PilotNames) {
  $normalized = Normalize-Name $name
  if (-not ($pilotRows | Where-Object { (Normalize-Name $_.full_name) -eq $normalized })) {
    $missingNames += $name
  }
}

if ($missingNames.Count -gt 0) {
  Write-Warning "These pilot names were not found in the clean CSV: $($missingNames -join ', ')"
}

if ($pilotRows.Count -eq 0) {
  throw "No pilot rows found. Check the names or clean CSV path."
}

$credentialRows = @()
$headers = @{
  "apikey" = $ServiceRoleKey
  "Authorization" = "Bearer $ServiceRoleKey"
  "Content-Type" = "application/json"
}

foreach ($employee in $pilotRows) {
  $password = New-TemporaryPassword
  $credentialRows += [pscustomobject][ordered]@{
    employee_id = $employee.employee_id
    full_name = $employee.full_name
    email = $employee.email
    temporary_password = $password
    status = if ($Execute) { "pending" } else { "dry_run" }
    note = ""
  }
}

if (-not $Execute) {
  $credentialRows |
    Select-Object employee_id, full_name, email, status |
    Format-Table -AutoSize
  Write-Host ""
  Write-Host "Dry run only. Add -Execute to create these Auth users."
  Write-Host "When executing, credentials will be written to $OutputDirectory\workpulse_pilot_auth_credentials.csv"
  return
}

$endpoint = "$($SupabaseUrl.TrimEnd('/'))/auth/v1/admin/users"

foreach ($row in $credentialRows) {
  $body = @{
    email = $row.email
    password = $row.temporary_password
    email_confirm = $true
    user_metadata = @{
      employee_id = $row.employee_id
      full_name = $row.full_name
      role = "employee"
    }
  } | ConvertTo-Json -Depth 5

  try {
    Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body | Out-Null
    $row.status = "created"
  } catch {
    $row.status = "failed"
    $row.note = $_.Exception.Message
  }
}

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$outputPath = Join-Path $OutputDirectory "workpulse_pilot_auth_credentials.csv"
$credentialRows | Export-Csv -NoTypeInformation -Encoding UTF8 $outputPath

$credentialRows |
  Select-Object employee_id, full_name, email, status, note |
  Format-Table -AutoSize

Write-Host ""
Write-Host "Wrote temporary credentials to $outputPath"
