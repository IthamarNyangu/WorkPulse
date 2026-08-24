param(
  [string]$ActiveWorkbookPath = "C:\Users\Inyangu\Downloads\work pulse employees.xlsx",
  [string]$DetailsWorkbookPath = "C:\Users\Inyangu\Desktop\Work pusle employee list without active-inactive.xlsx",
  [string]$OutputDirectory = "supabase\imports"
)

$ErrorActionPreference = "Stop"

function Convert-ExcelColumnNameToIndex {
  param([string]$Name)
  $index = 0
  foreach ($char in $Name.ToUpperInvariant().ToCharArray()) {
    $index = ($index * 26) + ([int][char]$char - [int][char]'A' + 1)
  }
  return $index
}

function Get-CellText {
  param(
    [System.Xml.XmlElement]$Cell,
    [string[]]$SharedStrings
  )

  if ($null -eq $Cell) {
    return ""
  }

  $valueNode = $Cell.GetElementsByTagName("v") | Select-Object -First 1
  if ($null -eq $valueNode) {
    $inlineNode = $Cell.GetElementsByTagName("t") | Select-Object -First 1
    if ($null -eq $inlineNode) {
      return ""
    }
    return [System.Net.WebUtility]::HtmlDecode($inlineNode.InnerText).Trim()
  }

  $value = $valueNode.InnerText
  if ($Cell.GetAttribute("t") -eq "s") {
    return $SharedStrings[[int]$value].Trim()
  }

  return $value.Trim()
}

function Read-XlsxFirstSheet {
  param([string]$Path)

  Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
  $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("workpulse-xlsx-" + [guid]::NewGuid())
  [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $tempPath)

  try {
    $sharedStrings = @()
    $sharedStringsPath = Join-Path $tempPath "xl\sharedStrings.xml"
    if (Test-Path $sharedStringsPath) {
      [xml]$sharedXml = Get-Content $sharedStringsPath
      foreach ($item in $sharedXml.sst.si) {
        $text = ""
        foreach ($node in $item.GetElementsByTagName("t")) {
          $text += $node.InnerText
        }
        $sharedStrings += $text
      }
    }

    [xml]$workbook = Get-Content (Join-Path $tempPath "xl\workbook.xml")
    $firstSheet = $workbook.workbook.sheets.sheet | Select-Object -First 1
    $relationshipId = $firstSheet.GetAttribute("id", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")

    [xml]$rels = Get-Content (Join-Path $tempPath "xl\_rels\workbook.xml.rels")
    $target = ($rels.Relationships.Relationship | Where-Object { $_.Id -eq $relationshipId }).Target
    $sheetPath = Join-Path (Join-Path $tempPath "xl") $target.Replace("/", "\")

    [xml]$sheet = Get-Content $sheetPath
    $rows = @()
    foreach ($row in $sheet.worksheet.sheetData.row) {
      $cellValues = @{}
      foreach ($cell in $row.c) {
        $columnName = ([regex]::Match($cell.r, "^[A-Z]+")).Value
        $columnIndex = Convert-ExcelColumnNameToIndex $columnName
        $cellValues[$columnIndex] = Get-CellText $cell $sharedStrings
      }
      $rows += ,$cellValues
    }

    if ($rows.Count -lt 2) {
      return @()
    }

    $headersByIndex = @{}
    foreach ($index in $rows[0].Keys) {
      $header = $rows[0][$index]
      if ([string]::IsNullOrWhiteSpace($header)) {
        $header = "Column$index"
      }
      if ($headersByIndex.Values -contains $header) {
        $header = "$header $index"
      }
      $headersByIndex[$index] = $header
    }

    $objects = @()
    foreach ($row in ($rows | Select-Object -Skip 1)) {
      $object = [ordered]@{}
      $hasContent = $false
      foreach ($index in ($headersByIndex.Keys | Sort-Object)) {
        $value = if ($row.ContainsKey($index)) { $row[$index] } else { "" }
        if (-not [string]::IsNullOrWhiteSpace($value)) {
          $hasContent = $true
        }
        $object[$headersByIndex[$index]] = $value
      }
      if ($hasContent) {
        $objects += [pscustomobject]$object
      }
    }

    return $objects
  } finally {
    Remove-Item -LiteralPath $tempPath -Recurse -Force
  }
}

function Normalize-EmployeeId {
  param([string]$Value)
  if ($null -eq $Value) {
    return ""
  }
  return $Value.Trim().TrimStart("_")
}

function Normalize-Text {
  param([string]$Value)
  if ($null -eq $Value) {
    return ""
  }
  return ($Value.Trim() -replace "\s+", " ")
}

function Test-Email {
  param([string]$Value)
  return $Value -match '^[^@\s]+@[^@\s]+\.[^@\s]+$'
}

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null

$activeRows = Read-XlsxFirstSheet $ActiveWorkbookPath
$detailRows = Read-XlsxFirstSheet $DetailsWorkbookPath

$detailsById = @{}
foreach ($row in $detailRows) {
  $id = Normalize-EmployeeId $row.employeeno
  if (-not [string]::IsNullOrWhiteSpace($id) -and -not $detailsById.ContainsKey($id)) {
    $detailsById[$id] = $row
  }
}

$activeById = @{}
foreach ($row in $activeRows) {
  $id = Normalize-EmployeeId $row.'Employee Code'
  if (-not [string]::IsNullOrWhiteSpace($id)) {
    $activeById[$id] = $row
  }
}

$emailCounts = @{}
foreach ($row in $activeRows) {
  $id = Normalize-EmployeeId $row.'Employee Code'
  if ($detailsById.ContainsKey($id)) {
    $email = (Normalize-Text $detailsById[$id].email).ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($email)) {
      if (-not $emailCounts.ContainsKey($email)) {
        $emailCounts[$email] = 0
      }
      $emailCounts[$email]++
    }
  }
}

$cleanRows = @()
$resolutionRows = @()

foreach ($active in ($activeRows | Sort-Object { Normalize-EmployeeId $_.'Employee Code' })) {
  $employeeId = Normalize-EmployeeId $active.'Employee Code'
  $status = Normalize-Text $active.'Employee Status'
  $firstName = Normalize-Text $active.'First Name'
  $lastName = Normalize-Text $active.'Last Name'
  $fullName = Normalize-Text "$firstName $lastName"
  $reasons = New-Object System.Collections.Generic.List[string]

  if ([string]::IsNullOrWhiteSpace($employeeId)) {
    $reasons.Add("missing_employee_id")
  }
  if ($status -ne "A - Active") {
    $reasons.Add("not_active_in_status_workbook")
  }
  if ([string]::IsNullOrWhiteSpace($fullName)) {
    $reasons.Add("missing_name")
  }

  $detail = $null
  if (-not [string]::IsNullOrWhiteSpace($employeeId) -and $detailsById.ContainsKey($employeeId)) {
    $detail = $detailsById[$employeeId]
  } else {
    $reasons.Add("missing_from_details_workbook")
  }

  $email = ""
  $department = ""
  $jobTitle = Normalize-Text $active.'Job Title'
  $province = Normalize-Text $active.Province
  $district = Normalize-Text $active.District
  $facility = Normalize-Text $active.Facility

  if ($null -ne $detail) {
    $email = (Normalize-Text $detail.email).ToLowerInvariant()
    $department = Normalize-Text $detail.department
    $jobTitle = Normalize-Text $detail.jobtitle
    $province = Normalize-Text $detail.province
    $district = Normalize-Text $detail.district
    $facility = Normalize-Text $detail.facility
  }

  if ([string]::IsNullOrWhiteSpace($email)) {
    $reasons.Add("missing_email")
  } elseif (-not (Test-Email $email)) {
    $reasons.Add("invalid_email_format")
  } elseif ($emailCounts[$email] -gt 1) {
    $reasons.Add("shared_email")
  } elseif ($email -match '@gmai\.com$') {
    $reasons.Add("suspicious_email_domain")
  }

  if ([string]::IsNullOrWhiteSpace($department)) {
    $reasons.Add("missing_department")
  }
  if ([string]::IsNullOrWhiteSpace($jobTitle)) {
    $reasons.Add("missing_job_title")
  }
  if ([string]::IsNullOrWhiteSpace($province)) {
    $reasons.Add("missing_province")
  }
  if ([string]::IsNullOrWhiteSpace($district)) {
    $reasons.Add("missing_district")
  }
  if ([string]::IsNullOrWhiteSpace($facility)) {
    $reasons.Add("missing_facility")
  }

  $base = [ordered]@{
    employee_id = $employeeId
    full_name = $fullName
    email = $email
    role = "employee"
    department = $department
    job_title = $jobTitle
    province = $province
    district = $district
    facility = $facility
    schedule_code = "MWF_STANDARD"
    is_active = "true"
  }

  if ($reasons.Count -eq 0) {
    $cleanRows += [pscustomobject]$base
  } else {
    $resolution = [ordered]@{}
    foreach ($key in $base.Keys) {
      $resolution[$key] = $base[$key]
    }
    $resolution["resolution_reason"] = ($reasons -join "; ")
    $resolution["source_status"] = $status
    $resolutionRows += [pscustomobject]$resolution
  }
}

foreach ($detail in ($detailRows | Sort-Object { Normalize-EmployeeId $_.employeeno })) {
  $employeeId = Normalize-EmployeeId $detail.employeeno
  if (-not [string]::IsNullOrWhiteSpace($employeeId) -and -not $activeById.ContainsKey($employeeId)) {
    $resolutionRows += [pscustomobject][ordered]@{
      employee_id = $employeeId
      full_name = Normalize-Text "$($detail.firstname) $($detail.lastname)"
      email = (Normalize-Text $detail.email).ToLowerInvariant()
      role = "employee"
      department = Normalize-Text $detail.department
      job_title = Normalize-Text $detail.jobtitle
      province = Normalize-Text $detail.province
      district = Normalize-Text $detail.district
      facility = Normalize-Text $detail.facility
      schedule_code = "MWF_STANDARD"
      is_active = "false"
      resolution_reason = "not_found_in_active_status_workbook"
      source_status = "unknown"
    }
  }
}

$cleanPath = Join-Path $OutputDirectory "workpulse_employee_import_clean.csv"
$resolutionPath = Join-Path $OutputDirectory "workpulse_employee_import_needs_resolution.csv"
$summaryPath = Join-Path $OutputDirectory "workpulse_employee_import_summary.txt"

$cleanRows | Export-Csv -NoTypeInformation -Encoding UTF8 $cleanPath
$resolutionRows | Export-Csv -NoTypeInformation -Encoding UTF8 $resolutionPath

$summary = @(
  "WorkPulse employee import summary",
  "Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))",
  "",
  "Active source rows: $($activeRows.Count)",
  "Detailed source rows: $($detailRows.Count)",
  "Clean import rows: $($cleanRows.Count)",
  "Rows needing resolution: $($resolutionRows.Count)",
  "",
  "Rules applied:",
  "- Active-status workbook is authoritative for active employees.",
  "- Employees missing required enrichment were excluded.",
  "- Blank, invalid, suspicious, and shared emails were excluded.",
  "- Supervisor assignments were not imported because they are not authoritative.",
  "- All clean employees use schedule_code MWF_STANDARD."
)
$summary | Set-Content -Encoding UTF8 $summaryPath

Write-Host "Clean rows: $($cleanRows.Count)"
Write-Host "Needs resolution: $($resolutionRows.Count)"
Write-Host "Wrote $cleanPath"
Write-Host "Wrote $resolutionPath"
Write-Host "Wrote $summaryPath"
