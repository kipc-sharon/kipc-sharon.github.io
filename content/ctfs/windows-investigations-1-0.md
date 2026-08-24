---
title: "Windows Investigations 1.0 — TryHackMe"
date: 2026-08-24
categories: ["CTFs"]
tags: ["thm", "windows", "forensics", "incident-response", "event-viewer", "mimikatz"]
summary: "Windows Server 2016 forensics lab — 16-question incident response challenge covering event logs, scheduled tasks, persistence mechanisms, and attacker infrastructure analysis."
featureimage: "windows-investigations.png"
---

## Challenge Overview

| Field | Details |
|---|---|
| **Platform** | TryHackMe |
| **Challenge** | Windows Investigations 1.0 |
| **User** | H3x1M1st (Sharon Kipsang) |
| **Focus** | Windows forensics, incident response, log analysis |
| **Link** | [Investigating Windows](https://tryhackme.com/room/investigatingwindows?utm_campaign=social_share&utm_medium=social&utm_content=share-completed-room&utm_source=copy&sharerId=659d2a88f6d7f1fdcd08c2d6) |

---

## Setup & Connections

### Using xfreerdp Client

![OpenVPN connection](/img/ctf/windows-investigations/Pasted%20image%2020260819043141.png)

Connected to the target Windows Server 2016 machine via OpenVPN and RDP for remote desktop access.

![RDP connection via xfreerdp](/img/ctf/windows-investigations/Pasted%20image%2020260819043242.png)

Established secure remote session for forensic investigation.

![Xfreerdp client session](/img/ctf/windows-investigations/Pasted%20image%2020260819043417.png)

---

## Investigation Questions & Findings

### 1. Windows Version and Year

**Methods:**
- `systeminfo` in Command Prompt
- Settings → About
- `winver` command

**Finding:**
```
Windows Server 2016
```

![Windows version via systeminfo](/img/ctf/windows-investigations/Pasted%20image%2020260819045415.png)

---

### 2. Last User Logged In

**Method 1: Active Sessions**
```bash
quser
```

**Method 2: Event Viewer Analysis**
- Windows Logs → Security
- Filter Event ID 4624 (successful logons)
- Look for Type 10 (RDP interactive logon)

![Event Viewer login analysis](/img/ctf/windows-investigations/Pasted%20image%2020260819051555.png)

**Finding:**
```
Administrator
```

---

### 3. John's Last Logon

**Method:**
```bash
net user John
```

![John user account details](/img/ctf/windows-investigations/Pasted%20image%2020260822180432.png)

**Finding:**
```
03/02/2019 5:48:32 PM
```

---

### 4. System Startup IP Connection

Observed terminal opening at startup showing connection to attacker infrastructure.

![Startup connection IP](/img/ctf/windows-investigations/Pasted%20image%2020260822211938.png)

**Finding:**
```
10.34.2.3
```

---

### 5. Administrative Accounts (Excluding Administrator)

**Method:**
```bash
net localgroup administrators
```

![Local Administrators group enumeration](/img/ctf/windows-investigations/Pasted%20image%2020260822202514.png)

**Finding (Alphabetical):**
```
Guest
Jenny
```

---

### 6. Malicious Scheduled Task Name

**Method 1: Event Viewer**
![Event Viewer scheduled task detection](/img/ctf/windows-investigations/Pasted%20image%2020260822205718.png)

**Method 2: PowerShell**
```powershell
Get-ScheduledTask
```

![PowerShell scheduled tasks](/img/ctf/windows-investigations/Pasted%20image%2020260822211048.png)

**Finding:**
```
Clean File System
```

---

### 7. Malicious Script File

**Method:**
- Task Scheduler → Actions tab for "Clean File System" task

![Task details showing script path](/img/ctf/windows-investigations/Pasted%20image%2020260822212424.png)

**Finding:**
```
nc.ps1
```

---

### 8. Port Listener

The `nc.ps1` Netcat payload configured with `-l 1348` flag.

![Netcat listener port detection](/img/ctf/windows-investigations/Pasted%20image%2020260823053912.png)

**Finding:**
```
1348
```

---

### 9. Jenny's Last Logon

**Method:**
```bash
net user Jenny
```

![Jenny account never logged in](/img/ctf/windows-investigations/Pasted%20image%2020260823052309.png)

**Finding:**
```
Never
```

---

### 10. Compromise Date

**Method:**
Check `C:\TMP` directory for malicious file timestamps.

![Malicious files directory listing](/img/ctf/windows-investigations/Pasted%20image%2020260824053223.png)

**Finding:**
```
03/02/2019
```

---

### 11. Privilege Escalation Timestamp

**Method:**
- Event Viewer → Security logs
- Filter Event ID 4672 (Special Privileges Assigned to Logon)

![Event ID 4672 privilege escalation](/img/ctf/windows-investigations/Pasted%20image%2020260824054737.png)

![Timestamp confirmation](/img/ctf/windows-investigations/Pasted%20image%2020260824054828.png)

**Finding:**
```
03/02/2019 04:04:49 PM
```

---

### 12. Password Dumping Tool

**Detection:**
- Scheduled task executing `mim.exe`
- Output file: `C:\TMP\mim-out.txt`

![Mimikatz execution detection](/img/ctf/windows-investigations/Pasted%20image%2020260824060114.png)

![Mimikatz output verification](/img/ctf/windows-investigations/Pasted%20image%2020260824061029.png)

**Finding:**
```
Mimikatz
```

---

### 13. Attacker C2 Server IP

**Method:**
```bash
ipconfig /displaydns
```

Inspect DNS cache for poisoned entries.

![C2 IP identification via DNS](/img/ctf/windows-investigations/Pasted%20image%2020260824062236.png)

![DNS poisoning entry](/img/ctf/windows-investigations/Pasted%20image%2020260824062254.png)

**Finding:**
```
76.32.97.132
```

---

### 14. Web Shell Extension

**Method:**
Navigate to `C:\inetpub\wwwroot` (IIS default web root)

![IIS web root files](/img/ctf/windows-investigations/Pasted%20image%2020260824183722.png)

**Finding:**
```
.jsp
```

---

### 15. Attacker-Opened Port

**Method:**
- Windows Defender Firewall → Inbound Rules
- Check for non-standard rules

![Firewall inbound rule inspection](/img/ctf/windows-investigations/Pasted%20image%2020260824181153.png)

![Port 1337 firewall rule](/img/ctf/windows-investigations/Pasted%20image%2020260824181605.png)

**Finding:**
```
1337
```

---

### 16. DNS Poisoning Target

**Method:**
DNS cache inspection showing spoofed entries.

![DNS poisoning google.com](/img/ctf/windows-investigations/Pasted%20image%2020260824062236.png)

Attacker redirected `google.com` to their C2 server IP.

**Finding:**
```
google.com
```

---

## Key Forensic Techniques

- **Event ID 4624**: Successful login events → user activity timeline
- **Event ID 4672**: Special privilege assignment → privilege escalation detection
- **Task Scheduler analysis**: Persistence mechanisms and automation
- **Firewall rules**: Attacker-opened ports and backdoor access
- **DNS cache**: C2 infrastructure and traffic redirection
- **File system forensics**: Malicious artifacts and scripts
- **Registry inspection**: System configuration changes

---

## Summary

This challenge demonstrates critical Windows forensic investigation skills:
- Multi-source log correlation for incident timeline
- Scheduled task abuse for persistence
- Mimikatz credential harvesting detection
- Firewall and DNS analysis for C2 infrastructure
- Rapid indicator identification for network hunting

**Challenge Status:** ✓ Completed (All 16 questions answered)
