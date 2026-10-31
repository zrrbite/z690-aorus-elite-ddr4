<#
.SYNOPSIS
  Presence, problem code, arrival/removal times and PCIe link state of the RTX 3050,
  its HDMI audio function and the CPU x16 root port. Includes phantom (not-present) devices.
.NOTES
  Non-elevated is fine. CM_PROB_PHANTOM (Code 45) on the root port as well as the card means
  the card was not detected at POST; no Windows driver can cause that.
#>
$patterns = @(
  @{ Name = 'RTX 3050 (display)';        Match = '^PCI\VEN_10DE&DEV_2582' },
  @{ Name = 'RTX 3050 (HDMI audio)';     Match = '^PCI\VEN_10DE&DEV_2291' },
  @{ Name = 'CPU x16 root port (PEG10)'; Match = '^PCI\VEN_8086&DEV_460D' }
)
$keys = 'DEVPKEY_Device_LocationInfo', 'DEVPKEY_Device_LastArrivalDate', 'DEVPKEY_Device_LastRemovalDate',
        'DEVPKEY_PciDevice_CurrentLinkSpeed', 'DEVPKEY_PciDevice_CurrentLinkWidth',
        'DEVPKEY_PciDevice_MaxLinkSpeed', 'DEVPKEY_PciDevice_MaxLinkWidth'

$all = Get-PnpDevice -ErrorAction SilentlyContinue
foreach ($p in $patterns) {
  $devs = @($all | Where-Object { $_.InstanceId -match $p.Match })
  if ($devs.Count -eq 0) { "=== $($p.Name): NOT IN THE PNP DATABASE AT ALL"; continue }
  foreach ($d in $devs) {
    $present = if ($d.Present) { 'present' } else { 'absent' }
    "=== $($p.Name): $($d.FriendlyName)"
    "    InstanceId : $($d.InstanceId)"
    "    Status     : $($d.Status)   Problem: $($d.Problem)   ($present)"
    Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName $keys -ErrorAction SilentlyContinue |
      Where-Object { $null -ne $_.Data } |
      ForEach-Object { "    {0,-20} {1}" -f ($_.KeyName -replace '^DEVPKEY_(PciDevice_|Device_)', ''), ($_.Data -join ',') }
  }
}
""
"Link speed: 1=Gen1 2.5GT/s, 2=Gen2 5GT/s, 3=Gen3 8GT/s, 4=Gen4 16GT/s, 5=Gen5 32GT/s. The RTX 3050 is natively x8."
"Adapters Windows can currently use (what Task Manager shows):"
Get-CimInstance Win32_VideoController | ForEach-Object { "    $($_.Name) | driver $($_.DriverVersion) | $($_.Status)" }
