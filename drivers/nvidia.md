# NVIDIA driver notes

## Versions seen on this machine

NVIDIA's release number is the last five digits of the Windows driver version: `32.0.16.2101` = 621.01.

| Installed | Version | How | Notes |
| --- | --- | --- | --- |
| 2026-07-08 | 610.74 (32.0.16.1074) | NVIDIA App; installer cached | Running at the 2026-09-05 display-fallback incident |
| 2026-10-23 04:43 | 610.88 (32.0.16.1088) | Windows Update, automatic (confirmed from the update history, see below) | Blue screen the same day |
| 2026-10-29 17:48 | 621.01 (32.0.16.2101) | NVIDIA App. "Setting clean install: 0", "Reboot not required", "Installation is successful." | Card vanished about 22 h later; not the cause (see diagnosis). Once the card was back and driving the display (2026-11-01), this version lagged on the desktop; see below |
| 2026-11-01 20:03 | 617.42 (32.0.16.1742, driver date 2026-09-30) | Standalone installer from NVIDIA's server, Custom > Perform a clean installation, NVIDIA App unticked. DDU not used. Boot 20:07 | Desktop lag gone. Card idles in P8/Gen1 on the desktop instead of cycling to P0. First gaming session the same evening ran clean (no GPU events, replay counter 0). Installer file location not recorded |

One orphaned driver-store folder (`nv_dispi.inf_amd64_6f3cfb7117944855`) has no inf; its version is unknown.

## Cached installers

| Version | Path |
| --- | --- |
| 621.01 | `C:\ProgramData\NVIDIA Corporation\NVIDIA App\UpdateFramework\ota-artifacts\grd\72fe7c90ac76afd30b09faa7612b5185\` |
| 610.74 | `C:\ProgramData\NVIDIA Corporation\Downloader\f59f572d876ef445bb343ae08ef1b8ec\610.74-desktop-win10-win11-64bit-international-dch-whql-g.exe` |
| 595.79 | `C:\Users\kjeld\Downloads\595.79-desktop-win10-win11-64bit-international-dch-whql.exe` |

Installer log: `C:\ProgramData\NVIDIA Corporation\NVIDIA App\Logs\LOG.setup.exe.log`.

## Windows Update does install this card's driver

Checked 2026-11-02 from the Windows Update history (`Microsoft.Update.Session`, 573 entries). Three NVIDIA display driver installs came through Windows Update, all with result Succeeded:

| Date | Windows Update title | Note |
| --- | --- | --- |
| 2026-06-21 17:30 | NVIDIA Display Driver Update (32.0.15.9186) | 591.86 |
| 2026-07-08 20:52 | NVIDIA - Display - 27.21.14.5671 | An old 2020-era package (456.71). Same evening as the 610.74 install by NVIDIA App, which presumably replaced it |
| 2026-10-23 04:43 | NVIDIA Display Driver Update (32.0.16.1088) | 610.88, installed overnight without anyone at the machine. Blue screen later that day |

So Windows Update can and does replace the NVIDIA driver here, unattended. It only installs a package newer than the one present, and NVIDIA publishes its WHQL releases to Windows Update some weeks after the release. 621.01 (2026-10-21) is newer than 617.42, so once it reaches Windows Update it will be offered or installed. The policy value in step 5 below stops drivers from arriving with quality updates; Settings > Windows Update > Advanced options > Optional updates still lists them for manual install.

## Known issues in 621.01

NVIDIA acknowledges a video-freeze and transient black-screen bug in 621.01; the suggested rollback is 617.42. Users also report stutter and "Prefer maximum performance" not holding. Different symptom from this card's disappearance: the display drops and comes back, the card stays on the bus.

**Seen here, 2026-11-01 18:00 to 20:03.** With the monitor on the card under 621.01: a visible hitch every few seconds when typing or dragging windows, mouse cursor smooth, none of it on the onboard output. CPU, disk and memory idle; no stall above 33 ms in a 40 s user-mode timing loop; no TDR, Display or `nvlddmkm` events; no WHEA on the GPU path; PCIe replay counter 0. The card cycled P8/Gen1 to P0/Gen4 every 2 to 4 s at 0 to 8 % load, and the driver's DPC core spiked to 11 % at each transition. "Prefer maximum performance" did not stop the cycling. Locking the clocks (`nvidia-smi -lgc 1792,1792`, `-lmc 7001,7001`, elevated) stopped the cycling but not the lag. Installing 617.42 with the installer's clean-install option removed the lag; on 617.42 the card stays in P8/Gen1 on the desktop. Conclusion: a 621.01 driver problem, not the card.

Download used: `https://us.download.nvidia.com/Windows/617.42/617.42-desktop-win10-win11-64bit-international-dch-whql.exe` (945 MB).

## Clean-install plan, once the card is back on the bus

Status 2026-11-01 20:10: step 4 done with 617.42 (installer clean install, no DDU, step 3 skipped). Steps 2 and 5 **not done yet**: the Windows Update driver block is not set, and NVIDIA App (still installed, 11.0.9) has not had automatic driver downloads turned off. Step 6 baseline: `Get-GpuState.ps1` shows the card at Gen4 x8, driver 32.0.16.1742. Checked 21:56 after the first gaming session: no Display, nvlddmkm or WHEA events since the 20:07 boot, replay counter 0. DDU stays in reserve if problems return.

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
