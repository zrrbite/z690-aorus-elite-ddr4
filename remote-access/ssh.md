# SSH into ZRRBITE-PC

Verified working 2026-10-31.

| Item | Value |
| --- | --- |
| Service | OpenSSH Server (`sshd`), Running, startup Automatic |
| Listening | 0.0.0.0:22 |
| LAN address | 192.168.111.4 (Ethernet, Private network profile) |
| Host key | `SHA256:LItlo8wuNYdvjbyFZ1i6Dtum63kN6HS8Q93mAlCPZF0` |
| User | `kjeld` (local administrator). Signed in with a Microsoft account, so **password auth uses the Microsoft account password**. |
| Auth methods offered | publickey, password, keyboard-interactive |
| Firewall rule | `OpenSSH-Server-In-TCP`, **Private profile only** |
| Sleep on AC | Never, so the machine stays reachable |
| Tailscale | Installed but **logged out** as of 2026-10-31. Log in to reach the machine from outside the LAN. |

From another machine:

```
ssh kjeld@192.168.111.4
```

## Public keys for an administrator go in a different file

Because `kjeld` is in Administrators, `sshd_config` on Windows redirects `AuthorizedKeysFile` for that group:

```
Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

So keys belong in `C:\ProgramData\ssh\administrators_authorized_keys`, **not** in `~/.ssh/authorized_keys`. The file exists with the correct ACL (SYSTEM and Administrators only). Add a key from an elevated PowerShell:

```powershell
Add-Content C:\ProgramData\ssh\administrators_authorized_keys "ssh-ed25519 AAAA... yourkey"
```

Do not loosen the ACL on that file; sshd refuses it if other users can read or write it.

## Optional

- Allow SSH on all network profiles (elevated): `Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Any`
- `sudo` is disabled on this machine; elevation needs a UAC prompt or an elevated terminal.

Config: `C:\ProgramData\ssh\sshd_config` (defaults; `Subsystem sftp sftp-server.exe` is enabled).
