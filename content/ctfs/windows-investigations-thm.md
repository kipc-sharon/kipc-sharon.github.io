---
title: "Windows Investigations 1.0 — TryHackMe"
date: 2026-08-11
categories: ["CTFs"]
tags: ["thm", "windows", "forensics", "incident-response", "event-viewer", "mimikatz", "persistence"]
summary: "Windows Server 2016 incident response lab — analyze compromised workstation, identify persistence mechanisms (scheduled tasks, firewall rules, web shell), track attacker C2 infrastructure, and document findings."
---

## Challenge Overview

| Field | Details |
|---|---|
| Platform | TryHackMe |
| Challenge | Windows Investigations 1.0 |
| User | H3x1M1st (Sharon Kipsang) |
| Focus | Windows forensics, incident response, log analysis |
| Challenge Link | [TryHackMe: Investigating Windows](https://tryhackme.com/room/investigatingwindows?utm_campaign=social_share&utm_medium=social&utm_content=share-completed-room&utm_source=copy&sharerId=659d2a88f6d7f1fdcd08c2d6) |

---

## Setup: Remote Access

Established remote desktop connection to Windows Server 2016 target using:

```bash
# Download OpenVPN config
# Connect via OpenVPN
openvpn config.ovpn

# RDP client connection
xfreerdp /u:username /p:password /v:target-ip
```

---

## Investigation Questions & Findings

### 1. Windows Version and Year

**Methods:**
- Command Prompt: `systeminfo`
- Settings > About
- Run `winver`

**Finding:**
```
Windows Server 2016
```

---

### 2. Last User Logged In

**Method 1: Active Sessions (Command Prompt)**
```bash
quser
# or
query user
```
Displays currently active and disconnected sessions with logon times.

**Method 2: Event Viewer (Logon History)**
- Run `eventvwr.msc`
- Navigate to **Windows Logs → Security**
- Filter by **Event ID 4624** (successful logons)
- Look for **Type 10** entries (RDP interactive logons)

**Finding:**
```
Administrator
```

---

### 3. When Did John Last Log On?

**Method:**
```bash
net user John
```

**Finding:**
```
03/02/2019 5:48:32 PM
```

---

### 4. IP Address at System Startup

Observed a command prompt opening during target startup showing a connection to:

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

Lists all accounts in the local Administrators group.

**Finding (Alphabetical Order):**
```
Guest
Jenny
```

---

### 6. Malicious Scheduled Task Name

**Method 1: Event Viewer**
- Windows Logs → Security
- Look for suspicious task creation events

**Method 2: PowerShell**
```powershell
Get-ScheduledTask
```

**Method 3: Command Line**
```bash
schtasks
```

**Finding:**
```
Clean File System
```

---

### 7. File Executed by Malicious Task

**Method:**
- Open Task Scheduler
- Select **Clean File System** task
- Check **Actions** tab for the executable path

**Finding:**
```
nc.ps1
```

---

### 8. Port Listening on Local Machine

**Analysis:**
The `nc.ps1` script (Netcat payload) is configured with the `-l 1348` argument, explicitly instructing it to listen for incoming connections on:

**Finding:**
```
1348
```

---

### 9. Last Logon for User Jenny

**Method:**
```bash
net user Jenny
```

**Finding:**
```
Never
```

---

### 10. Compromise Date

**Method:**
- Navigate to `C:\TMP` directory
- Examine file creation timestamps

Most malicious files and tasks were created on the same date:

**Finding (MM/DD/YYYY):**
```
03/02/2019
```

---

### 11. Time Windows Assigned Special Privileges

**Method:**
- Event Viewer → Windows Logs → Security
- Filter for **Event ID 4672** (Special Privileges Assigned to Logon)
- Apply custom date/time range around compromise date

**Finding (MM/DD/YYYY HH:MM:SS AM/PM):**
```
03/02/2019 04:04:49 PM
```

---

### 12. Tool Used to Dump Passwords

**Method:**
- Check `C:\TMP` for executables
- Examine scheduled task details and output files

**Finding:**
```
Mimikatz
```

---

### 13. Attacker's Command & Control Server IP

**Method:**
```bash
ipconfig /displaydns
```

Inspect local DNS cache for suspicious entries.

**Finding:**
```
76.32.97.132
```

---

### 14. Web Shell Extension

**Analysis:**
Windows IIS default web root is `C:\inetpub\wwwroot`

**Method:**
- Navigate to `C:\inetpub\wwwroot`
- Identify malicious file extensions

**Finding:**
```
.jsp
```

---

### 15. Last Port Opened by Attacker

**Method:**
- Open Windows Defender Firewall with Advanced Security
- Check **Inbound Rules** → **Protocols and Ports**
- Look for non-standard rules

**Finding:**
```
1337
```

---

### 16. DNS Poisoning Target Site

**Method:**
```bash
ipconfig /displaydns
```

Check DNS cache for spoofed entries resolving to attacker IP `76.32.97.132`.

**Finding:**
```
google.com
```

(Attacker redirected google.com to their C2 server via DNS poisoning)

---

## Key Takeaways

- **Event ID 4624**: Successful logons → identify user activity and RDP sessions
- **Event ID 4672**: Special privilege assignments → track privilege escalation
- **Task Scheduler**: Reveals persistence mechanisms and malicious automation
- **DNS Cache Analysis**: Detects DNS poisoning and C2 communication redirection
- **Firewall Rules**: Identifies attacker-opened ports and backdoor access
- **Mimikatz Indicators**: Password dumping tool execution and credential harvesting

This challenge demonstrates the importance of:
- Centralized logging and log retention
- Real-time monitoring for suspicious process execution (Mimikatz, netsh, schtasks)
- Prompt detection and response to firewall rule changes
- Isolating compromised systems immediately

---

**Challenge Completed:** ✓
