# hardware-notes

Hardware and firmware notes for the desktop **ZRRBITE-PC**: what is in the box, how the
motherboard behaves, how to update its BIOS, and the hardware-level diagnoses that have been
worked through. The OS-level counterpart is the sibling repo
[`workstation-notes`](../workstation-notes) (display fallback, power settings);
[`machine-diag`](../machine-diag) holds the general slowness diagnostic.

## Contents

| Area | File |
| --- | --- |
| Hardware inventory | [hardware/inventory.md](hardware/inventory.md) |
| Motherboard: Gigabyte Z690 AORUS ELITE DDR4 | [hardware/motherboard.md](hardware/motherboard.md) |
| BIOS update procedure (Q-Flash) | [bios/update-bios.md](bios/update-bios.md) |
| GPU failure, Oct 2026: RTX 3050 gone from the PCIe bus | [diagnosis/gpu-rtx3050-missing-2026-10.md](diagnosis/gpu-rtx3050-missing-2026-10.md) |
| NVIDIA driver notes and clean-install plan | [drivers/nvidia.md](drivers/nvidia.md) |
| Remote access (SSH) | [remote-access/ssh.md](remote-access/ssh.md) |

## Scripts

| Script | Purpose |
| --- | --- |
| [`scripts/Get-GpuState.ps1`](scripts/Get-GpuState.ps1) | Presence, problem code, last arrival and PCIe link state of the RTX 3050, its audio function and the CPU x16 root port. Includes phantom devices. Run first whenever the card misbehaves. |
| [`scripts/Get-CrashHistory.ps1`](scripts/Get-CrashHistory.ps1) | Unexpected shutdowns decoded (blue screen vs power button vs power loss), WHEA hardware errors, and the Windows Error Reporting history of GPU live kernel events and blue screens. |
| [`scripts/Get-HardwareInventory.ps1`](scripts/Get-HardwareInventory.ps1) | Board, BIOS, CPU, RAM, disks, video. Paste into hardware/inventory.md after a change. |

## Conventions

Same as workstation-notes:

- Each note leads with symptoms, then root cause (or the current best hypothesis, labelled as such), then the evidence.
- Record the ruled-out hypotheses too.
- Paste real command output rather than paraphrasing it. Exact timestamps and device IDs are what make an old note usable.
- Dates are ISO (YYYY-MM-DD), times are local. Serial numbers and MAC addresses stay out of the repo.
- BIOS images and installers are not committed. The downloaded F35 lives in `C:\dev\mobo\bios\`.

## External

- Vendor report for the GPU failure (Claude Doc): https://claude.ai/artifact/Vq7LVe2ABxcKtUVYbMFStL
- Gigabyte support page: https://www.gigabyte.com/Motherboard/Z690-AORUS-ELITE-DDR4-rev-1x/support
