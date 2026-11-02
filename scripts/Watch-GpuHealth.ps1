<#
.SYNOPSIS
  Live health watch for the RTX 3050. Samples the card every few seconds, appends a CSV log,
  and raises an alarm (console, beep, toast, alarms.log) when something crosses a line.

.DESCRIPTION
  Sources, all available without elevation:
    nvidia-smi      P-state, PCIe link gen/width, clocks, utilisation, temperature, fan,
                    throttle reasons, PCIe replay counter (every sample)
    PnP database    presence and problem code of the card, link speed/width as Windows sees it
                    (every -PnpEvery samples; this query is the slow one)
    Event logs      System: Display 4101 (TDR), nvlddmkm, WHEA-Logger, Kernel-PnP 400/410/420/430,
                    Kernel-Power 41/42/107/109. Application: Windows Error Reporting 1001
                    LiveKernelEvent. Only events written after the watch started.

  Alarms (once per episode, not every sample):
    - card absent from the bus or with a problem code (Code 45 = not detected at POST)
    - nvidia-smi stops answering while the device is present
    - PCIe link width below x8 at any time, or generation below Gen4 at >= -LoadThreshold % load
      (Gen1 at idle is normal power saving)
    - PCIe replay counter increases (link-level retries; was 0 through 2026-11-02)
    - temperature >= -TempAlarm
    - hardware slowdown, thermal slowdown or power-brake throttle reason
    - TDR, nvlddmkm entry, LiveKernelEvent, WHEA on the GPU path (bus 0 dev 1 = PEG10 root
      port, or bus 1 = the card), PnP event on the card or root port, unexpected shutdown
  Notices (logged, no sound): WHEA on other devices (the NIC root port 7ABA is known noise),
  sleep/resume/shutdown, card held at P0 while idle for two minutes (the 621.01 symptom).

  Logs go to %LOCALAPPDATA%\hardware-notes\gpu-watch\ by default: gpu-watch-YYYY-MM-DD.csv
  (one row per sample) and alarms.log (alarms and notices, full text). Not in the repo.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Watch-GpuHealth.ps1
  Runs until Ctrl+C. Windows PowerShell 5.1 is preferred: toasts need it. pwsh 7 works
  but falls back to msg.exe for the pop-up.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Watch-GpuHealth.ps1 -Once
  One sample, printed, no loop. Good for a quick look or a daily check.

.NOTES
  To start it at logon: create a shortcut in shell:startup with the target
    powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File C:\dev\hardware-notes\scripts\Watch-GpuHealth.ps1
  It cannot see a card that fails at POST (Windows is off then); it will report it absent
  at the next logon, and catch any runtime precursor while Windows is up.
#>
[CmdletBinding()]
param(
  [int]$IntervalSeconds = 5,
  [int]$PnpEvery = 6,
  [string]$LogDir = (Join-Path $env:LOCALAPPDATA 'hardware-notes\gpu-watch'),
  [int]$TempAlarm = 83,
  [int]$LoadThreshold = 30,
  [int]$MaxSamples = 0,
  [int]$ReplayDays = 0,
  [switch]$Once,
  [switch]$NoToast,
  [switch]$NoBeep
)

$ErrorActionPreference = 'Continue'
# Invariant culture: ':' in time formats and '.' as decimal separator whatever the user locale, so the CSV is stable.
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$deg = [string][char]0xB0
$DevicePattern   = 'PCI\VEN_10DE&DEV_2582*'   # RTX 3050 display function
$GpuPathPattern  = 'VEN_10DE|DEV_460D'        # the card, its audio function, the PEG10 root port
$HwThrottleMask  = 0x8 -bor 0x40 -bor 0x80    # HwSlowdown, HwThermalSlowdown, HwPowerBrake
$IdleP0Seconds   = 120

if ($Once) { $MaxSamples = 1 }
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$AlarmLog = Join-Path $LogDir 'alarms.log'

# ---------------------------------------------------------------- output helpers
function Get-CsvPath { Join-Path $LogDir ('gpu-watch-{0:yyyy-MM-dd}.csv' -f (Get-Date)) }

function Write-AlarmLine([string]$Level, [string]$Text) {
  $line = '{0:yyyy-MM-dd HH:mm:ss}  {1,-6}  {2}' -f (Get-Date), $Level, $Text
  Add-Content -Path $AlarmLog -Value $line -Encoding UTF8
  if (-not $Once -and $MaxSamples -eq 0) { Write-Host '' }   # end the in-place status line first
  if ($Level -eq 'ALARM') { Write-Host $line -ForegroundColor Red } else { Write-Host $line -ForegroundColor Yellow }
}

function Show-Toast([string]$Title, [string]$Body) {
  if ($NoToast) { return }
  try {
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $esc = [System.Security.SecurityElement]::Escape($Body)
    $xmlText = "<toast scenario='urgent'><visual><binding template='ToastGeneric'><text>$([System.Security.SecurityElement]::Escape($Title))</text><text>$esc</text></binding></visual></toast>"
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($xmlText)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    return
  } catch { }
  try { Start-Process -FilePath 'msg.exe' -ArgumentList @('*', '/TIME:60', "$Title`r`n$Body") -WindowStyle Hidden } catch { }
}

function Raise-Alarm([string]$Text) {
  $script:AlarmCount++
  Write-AlarmLine 'ALARM' $Text
  if (-not $NoBeep) { try { 1..3 | ForEach-Object { [Console]::Beep(1200, 250); Start-Sleep -Milliseconds 100 } } catch { } }
  Show-Toast 'GPU watch: ALARM' $Text
}

function Raise-Notice([string]$Text) { Write-AlarmLine 'NOTICE' $Text }

# ---------------------------------------------------------------- data sources
function Get-SmiSample {
  $fields = 'pstate,pcie.link.gen.current,pcie.link.width.current,clocks.sm,clocks.mem,utilization.gpu,temperature.gpu,fan.speed,clocks_throttle_reasons.active'
  $raw = $null
  try { $raw = & nvidia-smi --query-gpu=$fields --format=csv,noheader,nounits 2>$null } catch { }
  if (-not $raw) { return $null }
  $line = @($raw)[0]
  $v = $line -split ',\s*' | ForEach-Object { $_.Trim() }
  if ($v.Count -lt 9) { return $null }
  $num = { param($s) $d = 0.0; if ([double]::TryParse($s, [ref]$d)) { $d } else { $null } }
  $thr = 0L
  if ($v[8] -match '^0x([0-9a-fA-F]+)$') { $thr = [Convert]::ToInt64($matches[1], 16) }
  [pscustomobject]@{
    PState = $v[0]; Gen = & $num $v[1]; Width = & $num $v[2]; Sm = & $num $v[3]; Mem = & $num $v[4]
    Util = & $num $v[5]; Temp = & $num $v[6]; Fan = & $num $v[7]; Throttle = $thr
  }
}

function Get-ReplayCounter {
  try {
    $m = & nvidia-smi -q 2>$null | Select-String -Pattern 'Replays Since Reset\s*:\s*(\d+)' | Select-Object -First 1
    if ($m) { return [int]$m.Matches[0].Groups[1].Value }
  } catch { }
  return $null
}

function Get-PnpState {
  $d = $null
  try { $d = Get-PnpDevice -ErrorAction Stop | Where-Object { $_.InstanceId -like $DevicePattern -and $_.Present } | Select-Object -First 1 } catch { }
  if (-not $d) {
    try { $d = Get-PnpDevice -ErrorAction Stop | Where-Object { $_.InstanceId -like $DevicePattern } | Select-Object -First 1 } catch { }
    if (-not $d) { return [pscustomobject]@{ Present = $false; Problem = 'NOT_IN_PNP_DB'; Status = ''; Gen = $null; Width = $null } }
  }
  $gen = $null; $width = $null
  try {
    $pr = Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_PciDevice_CurrentLinkSpeed', 'DEVPKEY_PciDevice_CurrentLinkWidth' -ErrorAction Stop
    $gen = ($pr | Where-Object KeyName -eq 'DEVPKEY_PciDevice_CurrentLinkSpeed').Data
    $width = ($pr | Where-Object KeyName -eq 'DEVPKEY_PciDevice_CurrentLinkWidth').Data
  } catch { }
  [pscustomobject]@{ Present = [bool]$d.Present; Problem = [string]$d.Problem; Status = [string]$d.Status; Gen = $gen; Width = $width }
}

function Get-LatestRecordId([string]$Log) {
  try { return (Get-WinEvent -LogName $Log -MaxEvents 1 -ErrorAction Stop).RecordId } catch { return 0 }
}

function Get-EventDataMap($Event) {
  $map = @{}
  try { ([xml]$Event.ToXml()).Event.EventData.Data | ForEach-Object { if ($_.Name) { $map[$_.Name] = $_.'#text' } } } catch { }
  return $map
}

function Get-FirstLine([string]$Text) { if ($Text) { ($Text -split "`r?`n")[0].Trim() } else { '' } }

# Returns @{ Level; Text } or $null for events we do not care about.
function Classify-Event($e) {
  $p = $e.ProviderName; $id = $e.Id; $msg = $e.Message
  if ($p -eq 'Display' -and $id -eq 4101) { return @{ Level = 'ALARM'; Text = "TDR (Display 4101): $(Get-FirstLine $msg)" } }
  if ($p -eq 'nvlddmkm') { return @{ Level = 'ALARM'; Text = "nvlddmkm event $id`: $(Get-FirstLine $msg)" } }
  if ($p -eq 'Microsoft-Windows-WHEA-Logger') {
    $d = Get-EventDataMap $e
    $bus = $d['Bus']; $dev = $d['Device']; $fn = $d['Function']; $name = $d['PrimaryDeviceName']
    $where = "bus $bus dev $dev fn $fn ($name)"
    $onGpuPath = ($name -match $GpuPathPattern) -or ($bus -eq '0x1') -or ($bus -eq '0x0' -and $dev -eq '0x1')
    $kind = if ($id -eq 17) { 'corrected' } else { "uncorrected (id $id)" }
    if ($onGpuPath -or $id -ne 17) { return @{ Level = 'ALARM'; Text = "WHEA $kind error on the GPU path: $where, CorrectableErrorStatus $($d['CorrectableErrorStatus'])" } }
    return @{ Level = 'NOTICE'; Text = "WHEA corrected error elsewhere: $where (the NIC root port 7ABA is known noise)" }
  }
  if ($p -eq 'Microsoft-Windows-Kernel-PnP' -and $id -in 400, 410, 420, 430) {
    if ($msg -match $GpuPathPattern) { return @{ Level = 'ALARM'; Text = "PnP event $id on the GPU path: $(Get-FirstLine $msg)" } }
    return $null
  }
  if ($p -eq 'Microsoft-Windows-Kernel-Power') {
    switch ($id) {
      41  { return @{ Level = 'ALARM';  Text = 'Kernel-Power 41: the previous session ended without a clean shutdown' } }
      42  { return @{ Level = 'NOTICE'; Text = 'System entering sleep' } }
      107 { return @{ Level = 'NOTICE'; Text = 'System resumed from sleep' } }
      109 { return @{ Level = 'NOTICE'; Text = 'Clean shutdown or restart requested' } }
    }
    return $null
  }
  if ($p -eq 'Windows Error Reporting' -and $id -eq 1001 -and $msg -match 'LiveKernelEvent') {
    $code = if ($msg -match 'P1:\s*(\S+)') { $matches[1].ToLower() } else { '?' }
    $what = switch ($code) {
      '141' { 'GPU engine timeout (TDR)' }
      '117' { 'GPU TDR timeout' }
      '193' { 'dxgkrnl live dump' }
      '1a8' { 'black-screen dump (display reset hotkey pressed)' }
      '1b8' { 'black-screen blackbox dump' }
      '133' { 'DPC watchdog' }
      '1cc' { 'resource timeout' }
      default { 'kernel live dump' }
    }
    # WER logs each dump twice (first raw, then bucketed about 10 s later); the dump path dedupes them.
    $dump = if ($msg -match '(LiveKernelReports\\[^\r\n]+\.dmp)') { $matches[1] } else { '' }
    return @{ Level = 'ALARM'; Text = "LiveKernelEvent $code`: $what $dump".TrimEnd(); Key = "lke:$dump" }
  }
  return $null
}

# Dedupes classified events that carry a Key (WER reports its dumps twice). Returns $true if seen before.
function Test-Seen($c) {
  if (-not $c.Key) { return $false }
  if ($script:SeenKeys.ContainsKey($c.Key)) { return $true }
  $script:SeenKeys[$c.Key] = 1
  return $false
}

function Get-NewEvents {
  $out = @()
  try {
    $ev = Get-WinEvent -LogName System -FilterXPath "*[System[EventRecordID > $($script:LastSys)]]" -ErrorAction Stop
    foreach ($e in ($ev | Sort-Object RecordId)) { $script:LastSys = [Math]::Max($script:LastSys, $e.RecordId); $out += $e }
  } catch { }
  try {
    $ev = Get-WinEvent -LogName Application -FilterXPath "*[System[Provider[@Name='Windows Error Reporting'] and EventID=1001 and EventRecordID > $($script:LastApp)]]" -ErrorAction Stop
    foreach ($e in ($ev | Sort-Object RecordId)) { $script:LastApp = [Math]::Max($script:LastApp, $e.RecordId); $out += $e }
  } catch { }
  return $out
}

# ---------------------------------------------------------------- replay mode
# -ReplayDays N: run the event classifier over the last N days of logs and print what it
# would have raised. Nothing is written. Boot-time PnP 400/410 on the card show as alarms
# here; in live mode they are not seen because the watch starts after logon.
$script:SeenKeys = @{}
if ($ReplayDays -gt 0) {
  $since = (Get-Date).AddDays(-$ReplayDays)
  $providers = 'Display', 'nvlddmkm', 'Microsoft-Windows-WHEA-Logger', 'Microsoft-Windows-Kernel-PnP', 'Microsoft-Windows-Kernel-Power'
  $events = @()
  try { $events += Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = $providers; StartTime = $since } -ErrorAction Stop } catch { }
  try { $events += Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Windows Error Reporting'; Id = 1001; StartTime = $since } -ErrorAction Stop } catch { }
  $alarms = 0; $notices = 0
  foreach ($e in ($events | Sort-Object TimeCreated)) {
    $c = Classify-Event $e
    if (-not $c -or (Test-Seen $c)) { continue }
    if ($c.Level -eq 'ALARM') { $alarms++; $colour = 'Red' } else { $notices++; $colour = 'Yellow' }
    Write-Host ('{0:yyyy-MM-dd HH:mm:ss}  {1,-6}  {2}' -f $e.TimeCreated, $c.Level, $c.Text) -ForegroundColor $colour
  }
  Write-Host ("replay of the last {0} day(s): {1} events read, {2} alarms, {3} notices" -f $ReplayDays, $events.Count, $alarms, $notices)
  exit 0
}

# ---------------------------------------------------------------- state
$script:AlarmCount = 0
$script:LastSys = Get-LatestRecordId 'System'
$script:LastApp = Get-LatestRecordId 'Application'
$st = @{
  SmiFailing = $false; TempHigh = $false; HwThrottle = $false; WidthLow = $false; GenLowUnderLoad = $false
  Replays = $null; Absent = $false; Problem = ''; P0Since = $null; P0Noticed = $false
}

# ---------------------------------------------------------------- header
$driver = ''
try { $driver = (& nvidia-smi --query-gpu=driver_version,name --format=csv,noheader 2>$null | Select-Object -First 1) } catch { }
Write-Host ("GPU watch  {0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $driver)
Write-Host ("  sample every {0} s, PnP every {1} samples, temp alarm {2} {3}C, link must be Gen4 x8 at >= {4} % load" -f $IntervalSeconds, $PnpEvery, $TempAlarm, $deg, $LoadThreshold)
try {
  $boot = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-General'; Id = 12 } -MaxEvents 1 -ErrorAction Stop
  $dirty = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $boot.TimeCreated.AddMinutes(-2) } -MaxEvents 1 -ErrorAction SilentlyContinue
  $ended = if ($dirty) { 'UNEXPECTEDLY (Kernel-Power 41)' } else { 'cleanly' }
  Write-Host ("  last boot {0:yyyy-MM-dd HH:mm:ss}; the session before it ended {1}" -f $boot.TimeCreated, $ended)
} catch { }
Write-Host ("  csv: {0}" -f (Get-CsvPath))
Write-Host ("  alarms: {0}" -f $AlarmLog)
Write-Host "  Ctrl+C stops it."
Write-AlarmLine 'NOTICE' ("watch started (driver {0})" -f $driver) | Out-Null

# ---------------------------------------------------------------- loop
$n = 0
$pnp = $null
try {
  while ($true) {
    $n++
    $note = @()
    $now = Get-Date
    $s = Get-SmiSample
    $replays = Get-ReplayCounter
    if ($n -eq 1 -or ($n % $PnpEvery) -eq 0) { $pnp = Get-PnpState }

    # --- presence and problem code
    if ($pnp) {
      $absent = (-not $pnp.Present) -or ($pnp.Problem -ne 'CM_PROB_NONE' -and $pnp.Problem -ne '')
      if ($absent -and -not $st.Absent) { Raise-Alarm "card absent or in a problem state: present=$($pnp.Present) problem=$($pnp.Problem) status=$($pnp.Status)"; $note += 'absent' }
      elseif (-not $absent -and $st.Absent) { Raise-Notice 'card present again with no problem code' }
      $st.Absent = $absent
    }

    # --- nvidia-smi answering?
    if (-not $s) {
      if (-not $st.SmiFailing) { Raise-Alarm 'nvidia-smi returned nothing: driver not responding, or the device is gone'; $note += 'smi-fail' }
      $st.SmiFailing = $true
    } else {
      if ($st.SmiFailing) { Raise-Notice 'nvidia-smi answering again' }
      $st.SmiFailing = $false

      # --- temperature
      if ($null -ne $s.Temp) {
        if ($s.Temp -ge $TempAlarm -and -not $st.TempHigh) { Raise-Alarm ("temperature {0} {1}C (alarm at {2})" -f $s.Temp, $deg, $TempAlarm); $st.TempHigh = $true; $note += 'temp' }
        elseif ($s.Temp -lt ($TempAlarm - 5) -and $st.TempHigh) { Raise-Notice ("temperature back to {0} {1}C" -f $s.Temp, $deg); $st.TempHigh = $false }
      }

      # --- hardware throttle reasons
      $hw = ($s.Throttle -band $HwThrottleMask) -ne 0
      if ($hw -and -not $st.HwThrottle) { Raise-Alarm ('hardware throttle active: reasons 0x{0:x} (0x8 slowdown, 0x40 thermal, 0x80 power brake)' -f $s.Throttle); $note += 'throttle' }
      elseif (-not $hw -and $st.HwThrottle) { Raise-Notice 'hardware throttle cleared' }
      $st.HwThrottle = $hw

      # --- link width and generation
      if ($null -ne $s.Width) {
        $low = $s.Width -lt 8
        if ($low -and -not $st.WidthLow) { Raise-Alarm "PCIe link width x$($s.Width) (card is x8)"; $note += 'width' }
        elseif (-not $low -and $st.WidthLow) { Raise-Notice "PCIe link width back to x$($s.Width)" }
        $st.WidthLow = $low
      }
      if ($null -ne $s.Gen -and $null -ne $s.Util) {
        $genLow = ($s.Util -ge $LoadThreshold) -and ($s.Gen -lt 4)
        if ($genLow -and -not $st.GenLowUnderLoad) { Raise-Alarm "PCIe Gen$($s.Gen) at $($s.Util) % load (expected Gen4)"; $note += 'gen' }
        elseif ($st.GenLowUnderLoad -and $s.Gen -ge 4) { Raise-Notice "PCIe back at Gen$($s.Gen)" }
        if ($genLow) { $st.GenLowUnderLoad = $true } elseif ($s.Gen -ge 4) { $st.GenLowUnderLoad = $false }
      }

      # --- P0 while idle (the 621.01 symptom)
      if ($s.PState -eq 'P0' -and $null -ne $s.Util -and $s.Util -lt 5) {
        if (-not $st.P0Since) { $st.P0Since = $now }
        elseif (-not $st.P0Noticed -and ($now - $st.P0Since).TotalSeconds -ge $IdleP0Seconds) { Raise-Notice "card held at P0 for $IdleP0Seconds s at under 5 % load"; $st.P0Noticed = $true }
      } else { $st.P0Since = $null; $st.P0Noticed = $false }
    }

    # --- replay counter
    if ($null -ne $replays) {
      if ($null -ne $st.Replays -and $replays -gt $st.Replays) { Raise-Alarm "PCIe replay counter $($st.Replays) -> $replays (link retries)"; $note += 'replays' }
      elseif ($null -ne $st.Replays -and $replays -lt $st.Replays) { Raise-Notice "PCIe replay counter reset ($($st.Replays) -> $replays): device reset or driver reload" }
      $st.Replays = $replays
    }

    # --- event logs
    foreach ($e in (Get-NewEvents)) {
      $c = Classify-Event $e
      if (-not $c -or (Test-Seen $c)) { continue }
      $txt = ('{0:HH:mm:ss} {1}' -f $e.TimeCreated, $c.Text)
      if ($c.Level -eq 'ALARM') { Raise-Alarm $txt; $note += "evt$($e.Id)" } else { Raise-Notice $txt }
    }

    # --- CSV row
    $row = [pscustomobject]@{
      time = $now.ToString('yyyy-MM-dd HH:mm:ss')
      present = if ($pnp) { $pnp.Present } else { '' }
      problem = if ($pnp) { $pnp.Problem } else { '' }
      pnpGen = if ($pnp) { $pnp.Gen } else { '' }
      pnpWidth = if ($pnp) { $pnp.Width } else { '' }
      pstate = if ($s) { $s.PState } else { '' }
      gen = if ($s) { $s.Gen } else { '' }
      width = if ($s) { $s.Width } else { '' }
      smMHz = if ($s) { $s.Sm } else { '' }
      memMHz = if ($s) { $s.Mem } else { '' }
      utilPct = if ($s) { $s.Util } else { '' }
      tempC = if ($s) { $s.Temp } else { '' }
      fanPct = if ($s) { $s.Fan } else { '' }
      throttle = if ($s) { '0x{0:x}' -f $s.Throttle } else { '' }
      replays = $replays
      note = ($note -join ' ')
    }
    try { $row | Export-Csv -Path (Get-CsvPath) -Append -NoTypeInformation -Encoding UTF8 } catch { }

    # --- status line
    if ($s) {
      $status = '{0:HH:mm:ss}  {1}  Gen{2} x{3}  {4}/{5} MHz  {6,3} %  {7} {8}C  replays {9}  alarms {10}   ' -f $now, $s.PState, $s.Gen, $s.Width, $s.Sm, $s.Mem, $s.Util, $s.Temp, $deg, $replays, $script:AlarmCount
    } else {
      $status = '{0:HH:mm:ss}  nvidia-smi: no answer  present={1} problem={2}  alarms {3}   ' -f $now, $(if ($pnp) { $pnp.Present } else { '?' }), $(if ($pnp) { $pnp.Problem } else { '?' }), $script:AlarmCount
    }
    if ($Once -or $MaxSamples -gt 0) { Write-Host $status } else { Write-Host ("`r" + $status) -NoNewline }

    if ($MaxSamples -gt 0 -and $n -ge $MaxSamples) { break }
    $elapsed = ((Get-Date) - $now).TotalMilliseconds
    $wait = [Math]::Max(200, $IntervalSeconds * 1000 - $elapsed)
    Start-Sleep -Milliseconds ([int]$wait)
  }
} finally {
  Write-Host ''
  Write-AlarmLine 'NOTICE' ("watch stopped after {0} samples, {1} alarms" -f $n, $script:AlarmCount) | Out-Null
  Write-Host ("Log: {0}" -f (Get-CsvPath))
}
