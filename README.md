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
| Battle.net will not start, Nov 2026: its files zero-filled by the 2026-09-26 crash | [diagnosis/battlenet-zero-filled-2026-09-26.md](diagnosis/battlenet-zero-filled-2026-09-26.md) |
| NVIDIA driver notes and clean-install plan | [drivers/nvidia.md](drivers/nvidia.md) |
| Remote access (SSH) | [remote-access/ssh.md](remote-access/ssh.md) |
| Slides: the GPU failure and the BIOS update as a Beamer deck | [slides/01-rtx3050-failure.pdf](slides/01-rtx3050-failure.pdf) |

## Scripts

| Script | Purpose |
| --- | --- |
| [`scripts/Get-GpuState.ps1`](scripts/Get-GpuState.ps1) | Presence, problem code, last arrival and PCIe link state of the RTX 3050, its audio function and the CPU x16 root port. Includes phantom devices. Run first whenever the card misbehaves. |
| [`scripts/Get-CrashHistory.ps1`](scripts/Get-CrashHistory.ps1) | Unexpected shutdowns decoded (blue screen vs power button vs power loss), WHEA hardware errors, and the Windows Error Reporting history of GPU live kernel events and blue screens. |
| [`scripts/Watch-GpuHealth.ps1`](scripts/Watch-GpuHealth.ps1) | Live health watch for the RTX 3050: samples nvidia-smi and the PnP state every few seconds, watches the event logs, logs to CSV under `%LOCALAPPDATA%\hardware-notes\gpu-watch\`, and raises an alarm (beep, toast, `alarms.log`) on Code 45, a link below Gen4 x8 under load, replay-counter increases, TDRs, WHEA on the GPU path and LiveKernelEvents. `-Once` for a single sample, `-ReplayDays N` to run the classifier over past logs. |
| [`scripts/Get-HardwareInventory.ps1`](scripts/Get-HardwareInventory.ps1) | Board, BIOS, CPU, RAM, disks, video. Paste into hardware/inventory.md after a change. |

## Slides

One Beamer deck summarising the GPU failure, the evidence, the remaining tests and the BIOS
update: [RTX 3050: gone from the PCIe bus](slides/01-rtx3050-failure.pdf). Source in
[`slides/`](slides/); `make` there rebuilds it with [Tectonic](https://tectonic-typesetting.github.io/),
same setup as sourdough-science. The deck is derived from the notes; where they disagree, the note wins.

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
