# Hardware inventory

Collected 2026-10-31 with `scripts/Get-HardwareInventory.ps1` (non-elevated).

| Component | Detail |
| --- | --- |
| Case / PSU | **Unknown.** Read the PSU label (brand, model, wattage, 12 V rating) and fill in. |
| Motherboard | Gigabyte Z690 AORUS ELITE DDR4, rev 1.x (SMBIOS reports "Default string" for revision) |
| BIOS | **F5**, 2021-12-17, American Megatrends. F35 downloaded, not yet flashed. |
| CPU | Intel Core i7-12700K, 12 cores / 20 threads (8P + 4E) |
| iGPU | Intel UHD Graphics 770, driver 32.0.101.6129. Currently driving the monitor. |
| dGPU | Gigabyte GeForce RTX 3050 8 GB, PCI `10DE:2582`, subsystem `1458:4101`, one 8-pin PCIe power lead. **Not detected since 2026-10-30.** |
| RAM | 2 x 16 GB G.Skill F4-4000C18-16GVK (a DDR4-4000 CL18 kit), running at 2666 MT/s, i.e. JEDEC default. XMP is not enabled. |
| Storage | Samsung 970 EVO Plus 500 GB NVMe; Samsung 980 PRO 1 TB NVMe |
| Network | Realtek RTL8125 2.5GbE onboard, PCIe bus 5 under chipset root port #3. Virtual adapters: Tailscale, OpenVPN TAP x2, GlobalProtect. |
| Monitor | Lenovo P34w-20, 3440x1440 ultrawide (from workstation-notes) |
| OS | Windows 11 Pro for Workstations, build 10.0.26200, installed 2026-02-14 |
| Power states | S3 standby only. Hibernation and Fast Startup disabled 2026-09-05 (`powercfg /a`, confirmed 2026-10-31), so "Shut down" is a true power-off. |

Raw output, 2026-10-31:

```
BOARD: Gigabyte Technology Co., Ltd. | Z690 AORUS ELITE DDR4 | rev Default string
BIOS: F5 | 2021-12-17 | American Megatrends International, LLC.
CPU: 12th Gen Intel(R) Core(TM) i7-12700K | cores=12 threads=20
OS: Microsoft Windows 11 Pro for Workstations | 10.0.26200 | installed 2026-02-14
RAM total: 31,8 GB
  DIMM Controller0-ChannelA-DIMM1: G Skill Intl F4-4000C18-16GVK 16 GB @ 2666 MT/s (rated 2667)
  DIMM Controller1-ChannelA-DIMM1: G Skill Intl F4-4000C18-16GVK 16 GB @ 2666 MT/s (rated 2667)
DISK: Samsung SSD 970 EVO Plus 500GB 466 GB SCSI
DISK: Samsung SSD 980 PRO 1TB 932 GB SCSI
VIDEO: Intel(R) UHD Graphics 770 | driver 32.0.101.6129 | OK
```

Notes:

- The RTX 3050 does not appear in `Win32_VideoController` at all while it is off the bus. Use `scripts/Get-GpuState.ps1`, which includes phantom devices.
- TPM, BitLocker and Secure Boot state need an elevated prompt: `manage-bde -status C:`, `Confirm-SecureBootUEFI`, `Get-Tpm`. Check BitLocker before any BIOS flash (see [../bios/update-bios.md](../bios/update-bios.md)).
