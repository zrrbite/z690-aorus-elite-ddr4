<#
.SYNOPSIS
  Board, BIOS, CPU, RAM, disks, video, NICs. Paste the output into hardware/inventory.md.
.NOTES
  Secure Boot, BitLocker and TPM need an elevated prompt; reported as 'needs elevation' otherwise.
  Serial numbers and MAC addresses are deliberately not printed.
#>
$bb  = Get-CimInstance Win32_BaseBoard
$bi  = Get-CimInstance Win32_BIOS
$cpu = Get-CimInstance Win32_Processor
$os  = Get-CimInstance Win32_OperatingSystem
$cs  = Get-CimInstance Win32_ComputerSystem
"BOARD: $($bb.Manufacturer) | $($bb.Product) | rev $($bb.Version)"
"BIOS: $($bi.SMBIOSBIOSVersion) | $($bi.ReleaseDate.ToString('yyyy-MM-dd')) | $($bi.Manufacturer)"
"CPU: $($cpu.Name.Trim()) | cores=$($cpu.NumberOfCores) threads=$($cpu.NumberOfLogicalProcessors)"
"OS: $($os.Caption) | $($os.Version) | installed $($os.InstallDate.ToString('yyyy-MM-dd'))"
"RAM total: {0:N1} GB" -f ($cs.TotalPhysicalMemory/1GB)
Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
  "  DIMM $($_.DeviceLocator): $($_.Manufacturer) $($_.PartNumber.Trim()) {0:N0} GB @ $($_.ConfiguredClockSpeed) MT/s" -f ($_.Capacity/1GB)
}
Get-CimInstance Win32_DiskDrive | ForEach-Object { "DISK: $($_.Model) {0:N0} GB" -f ($_.Size/1GB) }
Get-CimInstance Win32_VideoController | ForEach-Object { "VIDEO: $($_.Name) | driver $($_.DriverVersion) | $($_.Status)" }
Get-CimInstance Win32_NetworkAdapter -Filter "PhysicalAdapter=True" | ForEach-Object { "NIC: $($_.Name)" }
try { "SecureBoot: $(Confirm-SecureBootUEFI -ErrorAction Stop)" } catch { "SecureBoot: needs elevation" }
try { "BitLocker C: $((Get-BitLockerVolume -MountPoint C: -ErrorAction Stop).ProtectionStatus)" } catch { "BitLocker C: needs elevation" }
try { $tpm = Get-Tpm -ErrorAction Stop; "TPM: present=$($tpm.TpmPresent) ready=$($tpm.TpmReady)" } catch { "TPM: needs elevation" }
