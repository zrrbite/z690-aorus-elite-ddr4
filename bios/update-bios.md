# Updating the BIOS (Gigabyte Q-Flash)

Board: Z690 AORUS ELITE DDR4 rev 1.x. Current: **F5** (2021-12-17). Target: **F35** (downloaded), or **F35a** if the support page shows it as newer.

Downloaded image: `C:\dev\mobo\bios\mb_bios_z690-aorus-elite-ddr4_8aadl007_f35\Z690AORUSELITEDDR4.F35` (32 MiB, from `mb_bios_z690-aorus-elite-ddr4_8aadl007_f35.zip`). Not committed to this repo.

## Why bother

F5 is the launch-era BIOS. Between F5 and F35 Gigabyte shipped, among many others:

- F23: fix for blank POST display with GeForce RTX 30-series cards.
- F32: Intel CSME firmware update. Read its note: CSME updates are typically one-way, so a BIOS older than that cannot be flashed back afterwards.
- Microcode, memory compatibility and stability updates across the series.

Re-read the release notes on the support page before flashing and confirm nothing says "update to Fxx first". Gigabyte normally allows a direct jump.

## Before you flash

1. **BitLocker.** From an elevated PowerShell: `manage-bde -status C:`. If protection is On, have the recovery key to hand (Microsoft account > Devices > BitLocker recovery keys) or suspend it for one reboot: `manage-bde -protectors -disable C: -RebootCount 1`. A BIOS change alters the TPM measurements and Windows may ask for the key at the next boot.
2. **Write down current settings** that are not defaults. As of 2026-10-31 that is only boot order (980 PRO) and Initial Display Output. XMP is not enabled.
3. **Power.** Do not flash while the PSU is under suspicion or during a storm. The flash takes a few minutes; a power loss mid-write leaves the board unbootable (Q-Flash Plus is the recovery path, below).
4. **Second device.** Have this repo or a phone handy; the machine is off the network for a while.
5. **USB stick**, FAT32, otherwise empty. Copy `Z690AORUSELITEDDR4.F35` to its root. Nothing else is needed for Q-Flash.

## Flash with Q-Flash

1. Shut down. Plug the stick into a rear USB port, not a front-panel hub.
2. Power on and press **End** at the Gigabyte logo to enter Q-Flash directly, or press **Del** for setup and then **F8** for Q-Flash.
3. Choose **Update BIOS**, select the stick, select `Z690AORUSELITEDDR4.F35`, confirm.
4. Wait. The screen may go dark and the machine may restart more than once (CSME update). Do not touch power or reset until setup appears again or Windows boots.
5. Enter setup. **Load Optimized Defaults** (F7), then **Save & Exit** (F10).
6. Enter setup again and re-apply the recorded settings (boot order, Initial Display Output). Leave XMP off unless you decide to enable it; if you do, record it here.
7. Boot Windows. If BitLocker asks for the recovery key, enter it once. If you suspended protection, re-enable from an elevated prompt: `manage-bde -protectors -enable C:`.
8. Verify and record:

   ```powershell
   Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion, ReleaseDate
   ```

   Then update [../hardware/inventory.md](../hardware/inventory.md) and the log at the bottom of this file.

## If the board will not POST after a flash: Q-Flash Plus

This family supports Q-Flash Plus (flash from USB without a working BIOS). Check the manual for this board's exact steps. The usual Gigabyte procedure: rename the BIOS file to `GIGABYTE.bin`, put it alone on a FAT32 stick, plug it into the rear port marked for Q-Flash Plus, and with the system off but the PSU switched on press the Q-Flash Plus button. Wait for the LED to stop blinking (several minutes).

## Do not use

- GIGABYTE Control Center or @BIOS from inside Windows. It works, but a Windows-side flash has more ways to be interrupted than Q-Flash.
- A BIOS file for the **DDR5** Z690 AORUS ELITE or for rev 2.x. The file name must say `DDR4`.

## Log

| Date | From | To | Notes |
| --- | --- | --- | --- |
| 2021-12 | | F5 | As shipped / installed |
| | F5 | F35 | Pending. Step 3 of the GPU troubleshooting flow, after cold power cycle and reseat. |
