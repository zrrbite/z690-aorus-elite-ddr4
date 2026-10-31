<#
.SYNOPSIS
  Crash and hardware-error history relevant to GPU diagnosis.
  1. Kernel-Power 41 (unexpected shutdown) decoded: blue screen vs power-button hold vs power loss.
  2. WHEA-Logger hardware errors with PCIe bus/device/function.
  3. Windows Error Reporting archive: LiveKernelEvent (GPU TDR etc.) and BlueScreen reports.
.PARAMETER Since
  Start of the window. Default 180 days ago. The System log on this machine wraps after about
  a week (20 MB), so section 3 (WER) is the long-term memory.
.NOTES
  Non-elevated: section 3 falls back to folder names and creation times (code is in the name).
  Elevated: section 3 also reads each Report.wer for exact event time and all parameters.
#>
param([datetime]$Since = (Get-Date).AddDays(-180))

"## 1. Unexpected shutdowns (Kernel-Power 41) since $($Since.ToString('yyyy-MM-dd'))"
$log = Get-WinEvent -ListLog System
$oldest = (Get-WinEvent -LogName System -Oldest -MaxEvents 1).TimeCreated
"System log reaches back to $($oldest.ToString('yyyy-MM-dd HH:mm'))  ($([math]::Round($log.FileSize/1MB)) MB of $([math]::Round($log.MaximumSizeInBytes/1MB)) MB)"
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=41; StartTime=$Since} -ErrorAction SilentlyContinue |
  Sort-Object TimeCreated | ForEach-Object {
    $x = [xml]$_.ToXml(); $h = @{}
    $x.Event.EventData.Data | ForEach-Object { $h[$_.Name] = $_.'#text' }
    $bug = [int64]$h.BugcheckCode
    $pb  = [int64]$h.PowerButtonTimestamp
    $cause = if ($bug -ne 0) { 'blue screen 0x{0:X}' -f $bug }
             elseif ($pb -gt 0) { 'power button held at ' + [DateTime]::FromFileTime($pb).ToString('yyyy-MM-dd HH:mm:ss') }
             else { 'POWER LOST or hard hang (no bugcheck, no button)' }
    "{0:yyyy-MM-dd HH:mm:ss}  {1}   SleepInProgress={2}" -f $_.TimeCreated, $cause, $h.SleepInProgress
  }

""
"## 2. Hardware errors (WHEA-Logger) since $($Since.ToString('yyyy-MM-dd'))"
$whea = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$Since} -ErrorAction SilentlyContinue)
"Count: $($whea.Count)   (Id 17 = corrected PCIe, 18/19 = uncorrected or fatal PCIe, 20 = corrected machine check, 46/47 = memory)"
$whea | Sort-Object TimeCreated | ForEach-Object {
  $x = [xml]$_.ToXml()
  $d = ($x.Event.EventData.Data |
        Where-Object { $_.Name -match '^(Bus|Device|Function|VendorID|DeviceID|CorrectableErrorStatus|UncorrectableErrorStatus|PrimaryDeviceName)$' } |
        ForEach-Object { "$($_.Name)=$($_.'#text')" }) -join ' '
  "{0:yyyy-MM-dd HH:mm:ss} Id={1} {2}" -f $_.TimeCreated, $_.Id, $d
}

""
"## 3. Windows Error Reporting kernel events since $($Since.ToString('yyyy-MM-dd')) (long-term history)"
$roots = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
$rows = Get-ChildItem $roots -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^Kernel_|LiveKernelEvent|BlueScreen' } |
  ForEach-Object {
    $row = [ordered]@{ When = $_.CreationTime; Type = 'folder'; P1 = ''; P2 = ''; P3 = ''; P4 = ''; Folder = $_.Name }
    if ($_.Name -match '^Kernel_([0-9A-Fa-f]+)_') { $row.P1 = $Matches[1] }
    try {
      $t = Get-Content (Join-Path $_.FullName 'Report.wer') -ErrorAction Stop
      $get = { param($k) ($t | Where-Object { $_ -like "$k=*" } | Select-Object -First 1) -replace ('^' + [regex]::Escape($k) + '='), '' }
      $ft = & $get 'EventTime'
      if ($ft) { $row.When = [DateTime]::FromFileTime([int64]$ft) }
      $row.Type = & $get 'EventType'
      $row.P1 = & $get 'Sig[0].Value'; $row.P2 = & $get 'Sig[1].Value'
      $row.P3 = & $get 'Sig[2].Value'; $row.P4 = & $get 'Sig[3].Value'
    } catch { }
    [pscustomobject]$row
  } | Where-Object { $_.When -ge $Since } | Sort-Object When -Descending
"Count: $(@($rows).Count)   (Type 'folder' = Report.wer not readable without elevation; P1 taken from the folder name)"
$rows | Format-Table -AutoSize When, Type, P1, P2, P3, P4
"P1 for live kernel events: 141/117 = GPU TDR (driver hung, device reset), 133 = DPC watchdog, 193 = dxgkrnl watchdog, 1CC = resource timeout, 1A8/1B8 = black-screen diagnostics."
"Blue screens: P1 = bugcheck code; later parameters and the folder name show the faulting module (nvlddmkm, dxgmms2)."
