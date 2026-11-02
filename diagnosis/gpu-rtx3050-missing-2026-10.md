# RTX 3050 gone from the PCIe bus (2026-10-30)

**Status (2026-11-02 16:22):** card back on the bus since 2026-11-01 17:37 (top slot, Gen4 x8). Driver rolled back from 621.01 to 617.42 at 20:03 after 621.01 caused desktop lag once the card drove the display; the first gaming session on 617.42 that evening and the first sleep/resume (2026-11-02, 16 h in S3) were clean. Cause of the 2026-10-30 absence not identified: the fault cleared with the slot change. Recurrence is possible; see the update under the hypothesis and the Log.
**Vendor report:** https://claude.ai/artifact/Vq7LVe2ABxcKtUVYbMFStL (Claude Doc; keep in sync with this note).

## Symptoms

1. No signal on the card's HDMI and DisplayPort outputs since the afternoon of 2026-10-30. Monitor moved to the motherboard output.
2. Task Manager > Performance shows only GPU 0 (Intel UHD 770). Device Manager has no NVIDIA display adapter.
3. The card is physically live: with the PC idle, one of its two fans spins up occasionally and stops again; the other has not been seen moving. The heatsink is noticeably hot to the touch.
4. Two "Unknown device" entries in Device Manager. Unrelated; see [../hardware/motherboard.md](../hardware/motherboard.md).

## Current best explanation (hypothesis, not proven)

The card powers up and runs its own firmware, but never trains a PCIe link, so the board firmware hides the CPU x16 root port and Windows sees nothing. The GPU chip burns boot-clock idle power with no driver to manage it, hence the hot heatsink and the fan-stop cycling. The link path is the suspect: slot contact, card edge connector, the board's top slot and CPU lanes, or the solder joints between the GPU chip and its board. Months of driver crashes and a possibly dead fan fit the solder-joint-fatigue pattern, but a loose card or a board fault are not excluded until the physical steps below are done.

It is **not** the NVIDIA 621.01 driver update of 2026-10-29. The card ran about 22 hours after that install, the failure is at firmware level (root port hidden at POST), and a driver cannot un-detect a PCIe device.

**Update 2026-11-01 17:38: the card trains again, in both slots.** Boot at 17:31 with the card in a PCIEX4 slot: present on bus 6 under a chipset root port, Gen3 x4, HDMI audio started. Boot at 17:37 with the card back in PCIEX16: present on bus 1 under PEG10, Gen4 x8. The existing 621.01 driver loaded without any install. `nvidia-smi` shortly after: P8 idle, 43.6 °C, fans stopped, link idling at Gen1 as designed. What this changes:

- The card's PCIe PHY is not dead, and neither are the top slot, the PEG port or the CPU lanes. Both halves of the card-or-board question answer "works today".
- The fault was in the link path and cleared with the slot change. Candidates: a contact fault on the card's fingers or in the top slot that two more insertions scrubbed away (the morning reseat did not, which argues against it but not strongly); or a firmware PCIe re-initialisation forced by saving changed setup values before the test. Which of these it was cannot be told from the logs.
- The solder-joint hypothesis is weakened, not gone. A cracked joint makes and breaks contact with temperature and handling, and six months of driver timeouts are still unexplained. If the timeouts stop now, the marginal link explains them. If they continue, the card is still failing.
- Plan: card stays in the top slot. No driver installs from NVIDIA App or Windows Update. Run `scripts/Get-GpuState.ps1` after each boot for a week: Code 45 again, or a link below Gen4 x8 under load, means the fault is back. Run `scripts/Get-CrashHistory.ps1 -Since 2026-11-01` weekly. The clean install happened the same evening: 617.42 via the NVIDIA installer's clean-install option, because 621.01 lagged on the desktop (see the Log and [../drivers/nvidia.md](../drivers/nvidia.md)); DDU stays in reserve. F35 is optional now. The vendor report stays open as a draft, not submitted while the card works.

## Evidence

### Device state (2026-10-31)

All three functions phantom, no removal timestamps, last seen at the 2026-10-29 driver-install re-enumeration.

```
=== NVIDIA GeForce RTX 3050  [PCI\VEN_10DE&DEV_2582&SUBSYS_41011458&REV_A1\4&AA66160&0&0008]  Status=Unknown Problem=CM_PROB_PHANTOM
  DEVPKEY_Device_LocationInfo                      PCI bus 1, device 0, function 0
  DEVPKEY_PciDevice_CurrentLinkSpeed               4        (PCIe Gen4)
  DEVPKEY_PciDevice_CurrentLinkWidth               8        (x8, the card's native width)
  DEVPKEY_PciDevice_MaxLinkSpeed                   4
  DEVPKEY_PciDevice_AERCapabilityPresent           True
  DEVPKEY_PciDevice_Correctable_Error_Mask         0
  DEVPKEY_PciDevice_Error_Reporting                7
  DEVPKEY_Device_LastArrivalDate                   10/29/2026 17:48:42
=== Intel(R) PEG10 - 460D  [PCI\VEN_8086&DEV_460D&SUBSYS_50001458&REV_02\3&11583659&0&08]  Status=Unknown Problem=CM_PROB_PHANTOM
  DEVPKEY_Device_LocationInfo                      PCI bus 0, device 1, function 0
  DEVPKEY_PciDevice_RootError_Reporting            7
  DEVPKEY_Device_LastArrivalDate                   10/29/2026 13:52:38
```

The HDMI audio function `PCI\VEN_10DE&DEV_2291` is phantom as well. The link was at full speed and width the last time the card was enumerated, with error reporting enabled and no PCIe errors ever logged against bus 1. It went from healthy to absent with no recorded degradation.

### Timeline

| When | Event | Source |
| --- | --- | --- |
| 2026-05-04 onward | WER archive holds 59 kernel reports: 53 live kernel events (25x 0x141 and 2x 0x117 GPU TDR, 11x 0x193 dxgkrnl watchdog, 2x 0x1CC, 1x 0x133, 12x 0x1A8/0x1B8 black-screen diagnostics) and 6 blue screens (3x 0x7E, 2x 0xA, 1x 0x50), faulting in `nvlddmkm` and `dxgmms2`. Windows was installed 2026-02-14, so the first eleven weeks were clean. | WER ReportArchive, `scripts/Get-CrashHistory.ps1` |
| 2026-07-08 | Driver 610.74 installed | driver store |
| 2026-09-05 | Display fell back to BasicDisplay after hibernate resume; fixed by cold restart; hibernation disabled | workstation-notes |
| 2026-10-23 15:35 | Blue screen 0x1000007E (access violation) in `nvlddmkm`, driver 610.88 (probably Windows Update) | Kernel-Power 41 |
| 2026-10-29 13:52 | Blue screen 0x50 PAGE_FAULT_IN_NONPAGED_AREA in `nvlddmkm`, 28 min after a normal restart | Kernel-Power 41 |
| 2026-10-29 17:48 | NVIDIA App installs 621.01. "Setting clean install: 0", no firmware step, "Installation is successful." Card re-enumerates 17:48:42 at Gen4 x8. | NVIDIA App LOG.setup.exe.log |
| 2026-10-30 15:30 | First corrected PCIe error on the **Realtek NIC** port, not the GPU. Repeats at each boot or resume since. | WHEA-Logger 17 |
| 2026-10-30 16:12 | Session unlock 16:12:15. Last recorded activity 16:12:22. | event log |
| 2026-10-30 16:41 | **Power button held** at 16:41:18 after a hang of about 29 min. Boot at 16:41:46: card absent. | Kernel-Power 41 PowerButtonTimestamp |
| 2026-10-30 16:43 | Power button held again at 16:43:13. Boot at 16:44:03: card absent. | Kernel-Power 41 |
| 2026-10-31 | Software diagnosis, SSH check, vendor report, this repo. Fan and heatsink observations. | |

### Shutdown causes decoded

The System log only reaches back to 2026-10-23 (20 MB, wrapped). Every abnormal shutdown in that window has a known cause. None has the "power vanished" signature (Bugcheck 0 with no power-button timestamp) that a failing PSU produces.

```
2026-10-23 15:35:24  Bugcheck=0x1000007E  PowerButton=-                    SleepInProgress=0
2026-10-29 13:52:40  Bugcheck=0x50        PowerButton=-                    SleepInProgress=0
2026-10-30 16:41:46  Bugcheck=0x0         PowerButton=2026-10-30 16:41:18  SleepInProgress=4
2026-10-30 16:44:03  Bugcheck=0x0         PowerButton=2026-10-30 16:43:13  SleepInProgress=4
```

### Hardware errors (WHEA)

Four corrected PCIe errors since 2026-10-30 15:30, all on chipset root port #3 (`DEV_7ABA`, bus 0 dev 28 fn 2), which carries the Realtek 2.5GbE controller on bus 5 (Gen2 x1). Receiver Error plus Bad TLP (`CorrectableErrorStatus=0x41`). Corrected, on a different link, probably benign. Noted because of the timing: if other devices start logging errors, suspect board or PSU rather than the card.

```
2026-10-30 15:30:02 Id=17 Bus=0x0 Device=0x1c Function=0x2 VendorID=0x8086 DeviceID=0x7aba CorrectableErrorStatus=0x41
2026-10-30 16:44:12 Id=17 (same)
2026-10-31 08:15:44 Id=17 (same)
2026-10-31 09:41:17 Id=17 (same)
```

### Power

- Card requirement: PCIe slot (75 W) plus one 8-pin lead (150 W); rated 130 W. NVIDIA recommends a 550 W system supply. PSU model: **unknown, read the label.**
- Fan activity and heat prove the 12 V input is live. A missing 8-pin alone does not make an NVIDIA card disappear; the card still enumerates from slot power and the driver reports the missing connector with the fans at full speed.
- Board rail voltages can be read with HWMonitor; the card's own lead only with a multimeter or PSU tester (see motherboard.md).

## Ruled out

| Hypothesis | Verdict |
| --- | --- |
| 621.01 driver broke the card | Ruled out. Card ran 22 h after install; failure is at POST, before any driver loads. 621.01 does have an NVIDIA-acknowledged transient black-screen bug (rollback target 617.42), which is a different symptom. |
| Installer flashed GPU firmware | Ruled out. Installer log shows no firmware or GOP step. |
| Card has no power | Ruled out by fan spin and hot heatsink. |
| PSU dropping out | No evidence in the log window; both 10-30 shutdowns were manual power-button holds. Not fully excluded, the window is 8 days. |
| Windows disabled the device | Ruled out. Phantom (Code 45), not disabled (Code 22); the root port is phantom too, which Windows cannot do. |
| Monitor or cable | Not the cause; onboard output works on the same monitor and the card is absent from the bus regardless of cable. |

## Procedure

In this order; each step is cheap and informative before the next. Record results in the log below.

- [x] 1. **Cold power cycle.** Shut down from Windows (hibernation and Fast Startup are off since 2026-09-05, confirmed with `powercfg /a` on 2026-10-31, so this is a true shutdown). PSU switch off. Hold the power button 20 s to drain standby charge. Wait two minutes. Power on and **watch the GPU fans at the moment of power-on**: both spin briefly (firmware boots) / one never moves (dead fan) / both at full speed constantly (firmware did not boot) / neither (no power). Check Task Manager for GPU 1.
- [x] 2. **Reseat.** PSU off, touch case metal, let the card cool. Bracket screw out, slot latch pressed, card straight out. Inspect edge contacts, slot, and the back of the board around the GPU for discolouration; 8-pin pins at both ends for heat marks. Photograph anything odd. Reseat until the latch clicks. Replug the 8-pin at both ends; use a spare PCIe cable from the same PSU if available. If the PSU is modular, confirm the cable is the PSU's own (foreign modular cables can have a different PSU-side pinout and kill a card). Read the PSU label. Power on, watch fans, check Task Manager. If still absent, feel the heatsink after ten minutes: warm = same state as before; cold = card no longer powering up at all.
- [x] 3. **BIOS settings (no case opening).** Skipped: step 4 was done first and the card returned (2026-11-01). Kept for reference. Enter setup (Del at POST). Look for the card anywhere in setup (Settings > IO Ports and the system information page). Set the top slot link speed to Gen3, save, boot, run `scripts/Get-GpuState.ps1`. If still absent, try Gen1 once: a marginal PCIe PHY sometimes trains only at the lowest rate. Then Load Optimized Defaults (F7), Initial Display Output = IGFX, F10, boot, check again.
- [x] 4. **Card or board.** Done 2026-11-01: the card appeared in a lower slot (bus 6, Gen3 x4) at 17:31 and, moved back, in the top slot (bus 1, Gen4 x8) at 17:37. Neither the card nor the top slot is dead; the fault was a cleared link-path fault of unknown cause. Original plan: move the card to a lower x16-length slot (chipset, x4 electrical) and boot. Card appears there: the card is fine and the CPU PEG port, top slot or CPU lanes are the problem; flash F35 per [../bios/update-bios.md](../bios/update-bios.md) (F23 carried an RTX 30 POST fix) and retest the top slot. Card absent there too: the card does not train PCIe at all; confirm in another PC if one is available, then the vendor report stands.
- [ ] 5. **If the card returns:** active since 2026-11-01 17:38. Do not let Windows Update or NVIDIA App install anything. Run `scripts/Get-GpuState.ps1` after each boot for a week and `scripts/Get-CrashHistory.ps1 -Since 2026-11-01` weekly. Driver rolled back to 617.42 on 2026-11-01 20:03 (installer clean install; DDU in reserve), see [../drivers/nvidia.md](../drivers/nvidia.md). Watch for the crash pattern returning.
- [ ] 6. **If it does not, or if it vanishes again:** the vendor report stands. Fill in PSU, serial, purchase details and the results above, and submit. On hold while the card works.

## Log

| Date | Action | Result |
| --- | --- | --- |
| 2026-10-30 | Monitor moved to onboard HDMI | Desktop on UHD 770 |
| 2026-10-31 | Software diagnosis (device state, WER history, logs, installer log). SSH verified. Vendor report written. | Card phantom at firmware level; see Evidence |
| 2026-10-31 | Observed: one fan cycles on and off while idle, other fan not seen moving; heatsink hot | Card has power, firmware runs, no link |
| 2026-11-01 | Steps 1 and 2 done together: Windows shutdown 08:48, PSU off, power button held, card out, 8-pin unplugged and replugged at the card, card reseated. Inspection of edge contacts, slot, board around the GPU and 8-pin pins: nothing abnormal. PSU label not yet recorded. | Booted 08:57 and again 08:59 (both clean shutdowns, no Kernel-Power 41). Card, HDMI audio and PEG10 root port still CM_PROB_PHANTOM; LastArrivalDate unchanged at 2026-10-29 17:48. WHEA 17 corrected error on NIC root port 7ABA again at each boot and at the 08:21 S3 resume; nothing on the PEG port. |
| 2026-11-01 | Observed at power-on: both GPU fans spin for a few seconds, then stop | Normal VBIOS fan self-test followed by fan-stop. 12 V reaches the card and its firmware boots; the PCIe link still does not train. Slot contact, cable seating and card power are now unlikely causes. Remaining: card PCIe PHY or BGA joints, or board PEG port / CPU lanes. |
| 2026-11-01 17:24 | Clean shutdown (Kernel-Power 109). Card moved to a lower PCIEX4 slot (chipset, x4 electrical). | Boot 17:31: card present on bus 6 under a chipset root port, Gen3 x4; HDMI audio function started; driver 621.01 loaded with no install; Task Manager shows GPU 1. First trained link since 2026-10-30. WHEA 17 on the NIC root port 7ABA at boot, as always; nothing on the GPU path. |
| 2026-11-01 17:33 | Clean shutdown. Card moved back to PCIEX16 (top slot). | Boot 17:37: card present on bus 1 under PEG10, Gen4 x8, root port no longer phantom. `nvidia-smi` shortly after: P8, 43.6 °C, fans 0 % (fan-stop), link idling at Gen1 x8, 508 MiB in use. A display (LEN63F2) was configured on the card at 17:38:21. The bus-6 instances from the lower-slot boot remain in Device Manager as phantom entries; harmless. Cause of the 2026-10-30 failure not identified. |
| 2026-11-01 ~18:00 | Monitor cable moved from the onboard port to the card (driver 621.01). | Desktop lag: a visible hitch every few seconds when typing or dragging windows, mouse cursor smooth. Not present on the onboard output. CPU 3 to 8 %, disk and memory idle, no stall above 33 ms in a 40 s user-mode timing loop, no repeating events, no TDR, no Display or nvlddmkm events, no WHEA on the GPU path, PCIe replay counter 0. The card cycled P8/Gen1 to P0/Gen4 every 2 to 4 s at 0 to 8 % load, and the driver's DPC core (core 8) spiked to 11 % at transitions. "Prefer maximum performance" did not hold (a reported 621.01 bug). Clocks locked with `nvidia-smi -lgc 1792,1792` and `-lmc 7001,7001`: lag unchanged, so the switching was not the cause. |
| 2026-11-01 20:03 | Driver downgraded 621.01 to 617.42 with the NVIDIA installer, Custom > Perform a clean installation, NVIDIA App unticked. Clean shutdown 20:06, boot 20:07. | Lag gone. Card present on bus 1, Gen4 x8, driver 32.0.16.1742, HDMI audio present. On the desktop the card now stays in P8/Gen1 at 4 to 32 % utilisation instead of cycling to P0. No WHEA, Display or nvlddmkm events at this boot. Still to do: Windows Update driver block (not set), NVIDIA App automatic driver download off. |
| 2026-11-01 evening | First gaming session since the card returned, on 617.42 with the card driving the display. Reported as going well. | Checked 21:56: no Display, nvlddmkm, WHEA, Kernel-Power 41 or bugcheck events since the 20:07 boot; no new LiveKernelReports or minidumps; PCIe replay counter 0; driver store holds only 617.42. After the session the card is back in P8/Gen1 at 45 °C. First sustained load since 2026-10-30, clean. |
| 2026-11-02 00:14 to 16:20 | First sleep (S3) with the card on 617.42 and driving the display: suspend 00:14:05, resume 16:20:45 (16 h in S3, firmware resume 3.2 s). Display came back on the card. | Checked 16:22: card present on bus 1, Gen4 x8, driver 32.0.16.1742, HDMI audio present, no re-enumeration (LastArrivalDate still 20:07:11), replay counter 0, P8 at 28 °C. The only event at resume is the usual WHEA 17 corrected error on the NIC root port 7ABA (bus 0 dev 0x1c fn 2), seen at every boot and resume; nothing on the GPU path. No Display, nvlddmkm or Kernel-PnP events. |
