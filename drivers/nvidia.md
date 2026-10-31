# NVIDIA driver notes

## Versions seen on this machine

NVIDIA's release number is the last five digits of the Windows driver version: `32.0.16.2101` = 621.01.

| Installed | Version | How | Notes |
| --- | --- | --- | --- |
| 2026-07-08 | 610.74 (32.0.16.1074) | NVIDIA App; installer cached | Running at the 2026-09-05 display-fallback incident |
| 2026-10-23 | 610.88 (32.0.16.1088) | Probably Windows Update | Blue screen the same day |
| 2026-10-29 17:48 | 621.01 (32.0.16.2101) | NVIDIA App. "Setting clean install: 0", "Reboot not required", "Installation is successful." | Card vanished about 22 h later; not the cause (see diagnosis) |

One orphaned driver-store folder (`nv_dispi.inf_amd64_6f3cfb7117944855`) has no inf; its version is unknown.

## Cached installers

| Version | Path |
| --- | --- |
| 621.01 | `C:\ProgramData\NVIDIA Corporation\NVIDIA App\UpdateFramework\ota-artifacts\grd\72fe7c90ac76afd30b09faa7612b5185\` |
| 610.74 | `C:\ProgramData\NVIDIA Corporation\Downloader\f59f572d876ef445bb343ae08ef1b8ec\610.74-desktop-win10-win11-64bit-international-dch-whql-g.exe` |
| 595.79 | `C:\Users\kjeld\Downloads\595.79-desktop-win10-win11-64bit-international-dch-whql.exe` |

Installer log: `C:\ProgramData\NVIDIA Corporation\NVIDIA App\Logs\LOG.setup.exe.log`.

## Known issue in 621.01

NVIDIA acknowledges a transient black-screen bug in 621.01; the suggested rollback is 617.42. Different symptom from this card's failure: the display drops and comes back, the card stays on the bus.

## Clean-install plan, once the card is back on the bus

Do this before the card receives any other driver. The crash history spans at least four driver packages, so a clean slate removes one variable before deciding the card is faulty.

1. Download 617.42 (or use the cached 610.74, the longest-running version here) and Display Driver Uninstaller (DDU) from its official site.
2. Block Windows Update driver installs first (step 5) so it cannot race the install.
3. Boot to Safe Mode, run DDU: Clean and restart, NVIDIA only. Leave the Intel driver alone.
4. Install the chosen NVIDIA package with **Custom > Perform a clean installation**. Decline NVIDIA App auto-update for now.
5. Keep Windows Update from replacing it. Elevated:

   ```powershell
   New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Force | Out-Null
   Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name ExcludeWUDriversInQualityUpdate -Value 1 -Type DWord
   ```

6. Run `scripts/Get-GpuState.ps1` and `scripts/Get-CrashHistory.ps1`, record the baseline here, and watch for live kernel events over the following weeks.
