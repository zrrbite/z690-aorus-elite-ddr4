# Gigabyte Z690 AORUS ELITE DDR4 (rev 1.x)

Support page: https://www.gigabyte.com/Motherboard/Z690-AORUS-ELITE-DDR4-rev-1x/support

Installed BIOS: **F5** (2021-12-17). Latest seen on the support page as of 2026-10-31: **F35 / F35a** (2026). F35 is downloaded to `C:\dev\mobo\bios\` (file `Z690AORUSELITEDDR4.F35`, 32 MiB). Procedure: [../bios/update-bios.md](../bios/update-bios.md).

## Expansion slots and what is in them

| Slot | Wired to | Occupant | Windows view |
| --- | --- | --- | --- |
| PCIEX16 (top, reinforced) | CPU, PCIe 5.0 x16 | Gigabyte RTX 3050 8 GB (an x8 card) | Root port `PCI\VEN_8086&DEV_460D` "Intel PEG10" at bus 0 dev 1 fn 0; card at bus 1 dev 0 fn 0 |
| PCIEX4_1, PCIEX4_2 (x16-length, lower) | Chipset (Z690), PCIe 3.0 x4 electrical | empty | Chipset root ports `PCI\VEN_8086&DEV_7AB8..7ABF` at bus 0 dev 28 |
| M2A_CPU | CPU, PCIe 4.0 x4 | one of the two NVMe drives | |
| M2M_SB, M2Q_SB, M2P_SB | Chipset, PCIe 4.0 x4 (M2M_SB also takes SATA M.2) | one of the two NVMe drives | |
| SATA | Chipset, 3 ports | empty | |

Slot names and electrical widths from Gigabyte's specification sheet for rev. 1.x (2026-11-01). The spec lists no bandwidth sharing between the PCIEX4 slots and the M.2 sockets; the only installation notices concern M.2 versus SATA (manual section 2-7). Which M.2 socket holds which drive is not recorded yet.

**Putting the RTX 3050 in a PCIEX4 slot** (the card-or-board test): the card is x16-length and x8 electrical, so it fits, and PCIe negotiates the link down to x4 at Gen3. That is about a quarter of its usual bandwidth, fine for a detection test and even for light use. The card would appear under one of the 7AB8..7ABF chipset root ports, on a new bus number, as a new device instance. Set Initial Display Output to Auto or IGFX first so POST stays visible whatever happens.

## Firmware behaviour worth knowing

- **A CPU x16 slot that does not train a link is hidden entirely.** When no card trains on the PEG port at POST, the BIOS does not expose the root port to the OS. In Windows this shows as the root port *and* the card *and* the card's HDMI audio function all reporting `CM_PROB_PHANTOM` (Code 45, "not connected"). That triple phantom is the signature of "card not detected at POST", which no Windows driver can cause. First seen 2026-10-30.
- The iGPU (UHD 770) stays usable for output while a discrete card is installed only if **Internal Graphics** is not disabled in setup. Leave it on Auto or Enabled while a discrete card is being debugged; it is the fallback display.
- **Initial Display Output** (Settings > IO Ports on this family) chooses which adapter the firmware uses for POST. "PCIe 1 Slot" = top slot card, "IGFX" = onboard. Set to Auto or IGFX while the card is missing so POST stays visible.
- The top slot has a **link speed** setting (Auto / Gen1..Gen5 on this family). Forcing Gen3 is a cheap test for a marginal card link.
- **Load Optimized Defaults** (F7 in setup) resets all of the above and XMP. XMP is currently **not** enabled (RAM runs at 2666), so there is nothing to restore there.

## Which downloads on the support page matter

The support page lists dozens of items. For this machine, in priority order:

| Item | Why | Status |
| --- | --- | --- |
| BIOS (F35 / F35a) | Fixes since F5 include blank POST display with RTX 30-series (F23), CSME firmware update (F32), plus many microcode, memory and stability fixes. | Downloaded, not flashed |
| Chipset > Intel Chipset Software (INF) | Device naming and power management for PCH devices. | Unknown |
| Chipset > Intel Serial IO | Driver for `ACPI\INTC1056` (Serial IO GPIO). Clears one of the two "Unknown device" entries and the dependent Resource Hub proxy error. | Not installed |
| LAN > Realtek 2.5GbE | Only if the inbox driver misbehaves. | Inbox driver in use |
| Audio > Realtek HD | Only if audio misbehaves. | |
| Utility > GIGABYTE Control Center | Fan curves, RGB, Windows-side BIOS update (prefer Q-Flash). | Installed, 23.05.25.01 |

Everything else (Norton, APP Center utilities, standalone RGB Fusion, EasyTune) is optional and can be ignored.

## Unknown devices in Device Manager

Two entries have been "Unknown device" since the 2026-02-14 Windows install. Neither is related to the GPU.

| Instance | What it is | Fix |
| --- | --- | --- |
| `ACPI\INTC1056` | Intel Serial IO GPIO Host Controller | Install Gigabyte "Intel Serial IO" chipset driver |
| `ACPI\INTC1070` | Intel HID Event Filter | Harmless. Optional driver comes with the Intel chipset / Serial IO packages |

## Sensors and power

The board's ITE sensor chip is readable by **CPUID HWMonitor 1.48** (installed, `C:\Program Files\CPUID\HWMonitor\HWMonitor.exe`) and GIGABYTE Control Center. It exposes +12 V, +5 V, +3.3 V and Vcore as seen at the board, not at any particular lead. ATX tolerance is 5 %:

| Rail | Acceptable |
| --- | --- |
| 12 V | 11.4 to 12.6 V |
| 5 V | 4.75 to 5.25 V |
| 3.3 V | 3.14 to 3.47 V |

The PSU has no USB monitoring interface (checked 2026-10-31: no Corsair, NZXT or Thermaltake USB devices present), so its model and per-lead output are not visible from software. A lead can be checked with a multimeter on DC volts at the back of the connector while running (black probe on chassis, red on each crimp, one pin at a time), or with a plug-in PSU tester. Static readings do not show sag under GPU load.
