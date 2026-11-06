# Battle.net desktop app does not start: its files were zero-filled by the 2026-09-26 crash

**Status (2026-11-06 18:15):** repaired 2026-11-06 18:06 by rerunning Battle.net-Setup.exe (section "Repair"). Battle.net 2.53.8.17986 starts and runs.

## Symptom

Reported 2026-11-06 17:52: Battle.net does not start. Checked from the machine: no Battle.net, Agent or Blizzard process running; no Application Error (1000), Application Hang (1002) or Windows Error Reporting (1001) entry for it; the app's own logs in `%LOCALAPPDATA%\Battle.net\Logs` and `C:\ProgramData\Battle.net\Agent\Logs` end 2026-09-24 19:40. The launcher stub starts, fails to run the main executable and exits without writing anything. The GPU is not involved: card present, no GPU events since 2026-11-02.

## Root cause

The Battle.net self-update from 2.53.0.17840 to 2.53.1.17862 ran 2026-09-26 09:26:24 to 09:26:50 and the machine crashed within the next minute. Files the update had written in the seconds before the crash were never flushed to disk: NTFS had recorded their size, the data was still in the cache, so they read back as zeros.

Damaged, all written 2026-09-26, every byte 0x00:

| File | Size | Written |
| --- | --- | --- |
| `C:\Program Files (x86)\Battle.net\Battle.net.exe` | 992 464 B | 09:26:42.298 |
| `C:\Program Files (x86)\Battle.net\Battle.net.17862\Battle.net Helper.dll` | 4 245 200 B | 09:26:42.373 |
| 165 files `Battle.net.17862\bdk\BlizzardBrowser\CefWrapper\locales\*_FEMININE.pak`, `*_MASCULINE.pak`, `*_NEUTER.pak` | 18 B each | 09:26:46 to 09:26:47 |
| `C:\ProgramData\Battle.net\Agent\product.db` | 1 090 B | 09:26:50.206, the last file the update wrote |

Intact: `Battle.net Launcher.exe` 2.53.1.17862 and `Agent.exe` 2.41.0.9775 (both signed, Blizzard Entertainment), `battle.net.dll` (28 MB, written in the same second as the zeroed exe), `Battle.net.mpq`, the hidden `.product.db` and `Launcher.db`, and the two previous versioned folders `Battle.net.17840` and `Battle.net.17821` (363 files each). `temp_55378fa22eff4403dae46bf6f2453db5.exe` in the root is a valid, signed `Battle.net.exe` 2.53.0.17840 left behind by the 24 September update. The same 18-byte locale files in `Battle.net.17840` hold 3 non-zero bytes, so the zeros in 17862 are damage, not design. The `shmem` files under `.battle.net` are also all zero; those are shared-memory files and are zero by design.

What Windows says about the zeroed exe:

```
PS> Get-AuthenticodeSignature 'C:\Program Files (x86)\Battle.net\Battle.net.exe' | Select-Object Status, StatusMessage
UnknownError  The form specified for the subject is not one supported or known by the specified trust provider.
```

No version resource, no MZ header: `CreateProcess` refuses it, and the launcher stub has nothing to log with.

## Evidence for the crash

The System log and the reliability records on this machine only reach back to 2026-10-23, so the crash shows only in the WER archive (`C:\ProgramData\Microsoft\Windows\WER\ReportArchive`; folder names are readable without elevation, contents are not):

| Folder written | Report |
| --- | --- |
| 2026-09-26 09:27:07 | `Kernel_193_...`: LiveKernelEvent 0x193, dxgkrnl watchdog |
| 2026-09-26 09:28:14 | `Kernel_7e_...`: bugcheck 0x7E SYSTEM_THREAD_EXCEPTION_NOT_HANDLED, filed after the reboot |
| 2026-09-26 09:54:47 | `NonCritical_setup.exe_...` |

So: the update's last write at 09:26:50, a GPU live dump at 09:27:07, blue screen and reboot before 09:28:14. Both reports are part of the 59 in the crash history ([gpu-rtx3050-missing-2026-10.md](gpu-rtx3050-missing-2026-10.md)); the 0x7E is one of its three.

## Ruled out

- **Disk fault.** C: is the Samsung 980 PRO 1 TB (NVMe), HealthStatus Healthy. No Ntfs, disk or stornvme warnings or errors since the logs begin on 2026-10-23; the only volmgr entries (161, 162: dump file creation) belong to the 2026-10-29 crash.
- **Wider damage.** Of 243 files written 2026-09-26 09:20 to 09:30 under `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData` and `C:\Users\kjeld\AppData`, 171 start with zeros and every one of them is under Battle.net. Nothing else was being written at that moment.
- **Something blocking the executables.** No Image File Execution Options entries for Battle.net.exe, Battle.net Launcher.exe or Agent.exe; no compatibility layers; the Start Menu shortcut points at the existing launcher stub; no Defender detections today.
- **A Battle.net crash today.** The Crashpad report at 17:50:19 on 2026-11-06 is from the Microsoft Edge installer (setup.exe 157.0.4341.42, EdgeInstallerError 0x21f), not Battle.net.

## Fix

No Blizzard game is installed through Battle.net on this machine (Diablo II: Resurrected is the Steam edition), so only the desktop app itself is affected.

1. Download Battle.net-Setup.exe from https://www.blizzard.com/apps/battle.net/desktop and run it. This is an in-place repair, not an uninstall: it rewrites the app files and keeps the settings in `%APPDATA%\Battle.net`.
2. Verify:

   ```powershell
   Get-AuthenticodeSignature 'C:\Program Files (x86)\Battle.net\Battle.net.exe' | Select-Object Status
   ```

   Expected `Valid`.

Fallback without a download, elevated: copy `temp_55378fa22eff4403dae46bf6f2453db5.exe` over `Battle.net.exe`. The app then runs 2.53.0.17840 from the intact `Battle.net.17840` folder and updates itself, which rewrites the 17862 files. The zeroed Agent `product.db` may still need the installer to recover, so the installer is the first choice.

## Repair, 2026-11-06 18:05 to 18:06

Done from this session at the owner's request. `Battle.net-Setup.exe` fetched from `https://downloader.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe` (resolves to `.../download/installer/win/1.0.69/Battle.net-Setup.exe`): 4 700 880 bytes, version 2.0.0.4232, SHA-256 `F4643A2086C0CECB1AB68CC601BF38C1A0A6F7EF5914AD03375CC9449385BEC6`, Authenticode Valid, signer Blizzard Entertainment, Inc. (DigiCert Trusted G4 code signing). Launched 18:05:33; UAC approved by the owner 18:05:34; elevated setup 18:05:37; Agent 18:05:47; bootstrapper finished 18:06:13; Battle.net started 18:06:13 with its main window up. The install itself took under a minute.

| Item | Before | After |
| --- | --- | --- |
| `Battle.net.exe` | 992 464 B of zeros | 2.53.8.17986, 995 536 B, signature Valid, written 18:05:56 |
| Versioned folder | `Battle.net.17862`: Helper.dll and 165 locale paks zeroed | `Battle.net.17986`, written 18:06:09, Helper.dll and every pak intact (0 zero-headed) |
| Agent | 2.41.0.9775, `product.db` zeroed | 2.41.2.9852 in `Agent.9852`, `product.db` rewritten 18:06:28 (708 B) |

Left behind, unused: `Battle.net.17862` with its zeroed files. The installer removed `Battle.net.17840`, `Battle.net.17821` and the `temp_...exe` copy. No Application Error or WER events after the start; the app log holds one JavaScript exception from the shop webview and CEF "Unsupported codec by MfAudioDecoder" lines, both cosmetic. The setup log also reports that it repaired folder and file permissions under `C:\ProgramData\Blizzard Entertainment\Battle.net\Cache`. Note that the logs under `C:\ProgramData\Battle.net\Setup` are in UTC.

## Lesson

A crash zero-fills whatever was being written in the seconds before it. After each unexpected shutdown it is worth listing the files written in the minute before the crash and checking their first bytes; a zero head on an .exe, .dll or database file means that program has to be reinstalled. Worth folding into `scripts/Get-CrashHistory.ps1`.
