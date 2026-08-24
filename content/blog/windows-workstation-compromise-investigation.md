---
title: "Windows Workstation Compromise Investigation Report"
date: 2026-03-02
categories: ["Blog"]
tags: ["incident-response", "windows-forensics", "malware-analysis", "persistence", "mimikatz", "threat-intelligence"]
summary: "Detailed incident response report of a Windows Server 2016 workstation compromise (March 2, 2019). Documents attack timeline, persistence mechanisms, indicators of compromise, and forensic evidence."
---

## Executive Summary

A workstation was actively compromised on **March 2, 2019**. An attacker gained administrative access to the system and installed multiple tools to:

- **Harvest user passwords** using Mimikatz
- **Establish persistent backdoor access** via scheduled tasks and firewall rules
- **Redirect network traffic** to their own Command & Control (C2) servers via DNS poisoning
- **Deploy a web shell** for ongoing remote code execution
- **Modify system security settings** to prevent detection

**Immediate action required:**

1. Reset all user passwords immediately (network-wide)
2. Remove malicious scheduled tasks and firewall rules
3. Clean malicious files from the system
4. Isolate workstation from network until remediation complete
5. **Recommended: Full system rebuild** (not incremental cleaning)

---

## Scope & Data Sources

### Investigation Scope
- Single Windows Server 2016 workstation
- Focused on user activity, persistence mechanisms, and attacker artifacts

### Data Sources & Limitations

| Source | Capabilities | Limitations |
|---|---|---|
| **Windows Event Viewer (Security logs)** | Login events (Event ID 4624), privilege escalation (Event ID 4672) | Only reveals what Windows logged; tampered logs hide earlier activity |
| **Command-line tools** (`net user`, `ipconfig /displaydns`) | User account metadata, DNS cache inspection | Shows current state only; historical data older than cache retention is lost |
| **Task Scheduler** | Scheduled tasks and associated scripts | Only shows active tasks; deleted tasks are unrecoverable without backup |
| **File System** | Web shells, malicious scripts in `C:\inetpub` and `C:\TMP` | Does not reveal deleted/exfiltrated files; timestamps may be spoofed |
| **Windows Defender Firewall** | Non-standard inbound rules | Does not show deleted/overwritten rules |
| **System Settings & Registry** | Windows version, system configuration | Full registry analysis not performed; attacker may have modified other keys |

---

## Timeline of Events

### 03/02/2019 – Initial Compromise (Time Unknown)
- Attacker gains initial access to workstation
- Exact time and attack vector not determined from available evidence
- Successful authentication or privilege escalation to Administrator level

### 03/02/2019 04:04:49 PM – Privilege Escalation
- Windows assigns special privileges to new logon (Event ID 4672)
- **Attacker establishes administrative access**

### 03/02/2019 04:55 PM (Daily) – Persistence Installation
- Attacker creates scheduled task: **"Clean File System"**
- Executes malicious cleanup script daily: `C:\TMP\nc.ps1`

### 03/02/2019 04:37 PM – Web Shell Deployment
- Attacker uploads malicious web shell to `C:\inetpub\wwwroot\b.jsp`
- Enables remote code execution via HTTP requests

### 03/02/2019 Onwards – Ongoing Attacker Activity
- Scheduled tasks execute daily to dump passwords and maintain backdoor access
- Attacker maintains persistent access via:
  - Scheduled tasks (cleanup + Mimikatz)
  - Firewall rules (port 1337)
  - Web shell (port 80/443 via IIS)
  - DNS poisoning (C2 redirection)

---

## Investigation & Analysis

### 1. User Login History Analysis

**Method:**
- Event Viewer → Windows Logs → Security
- Filter: Event ID 4624 (successful logons) + Logon Type 10 (RDP)

**Finding:**
- Last RDP user identified
- John's last login: **03/02/2019 5:48:32 PM**
- Jenny never logged in (password may have been created but unused)

---

### 2. System Configuration & Access Analysis

**Method:**
```bash
net localgroup administrators
```

**Findings:**
- Standard `Administrator` account
- **Non-default admin accounts:** Guest, Jenny
- These accounts may have been created or exploited by attacker

---

### 3. Startup & Network Behavior Analysis

**Finding:**
- Terminal window opens automatically at startup
- Connects to IP address: **10.34.2.3**
- Indicates persistence mechanism or reverse shell configured at boot time

---

### 4. Scheduled Task Analysis

**Method:**
- Task Scheduler GUI inspection
- PowerShell: `Get-ScheduledTask`
- Command line: `schtasks`

**Findings:**

| Task Name | Executable | Execution | Purpose |
|---|---|---|---|
| **Clean File System** | `C:\TMP\nc.ps1` | Daily 4:55 PM | Netcat backdoor persistence; cleanup function masks tracks |
| **Mimikatz Execution** | `mim.exe` (Mimikatz) | Daily | Dumps plaintext/hash credentials; output to `C:\TMP\mim-out.txt` |

---

### 5. Password Dumping Tool Verification

**Method:**
```powershell
Get-Content C:\TMP\mim-out.txt
```

**Finding:**
- Mimikatz successfully dumped system passwords
- Attacker has access to all user credentials

---

### 6. Command & Control (C2) Infrastructure Analysis

**Method:**
```bash
ipconfig /displaydns
```

**Finding:**
- **DNS Poisoning Entry:** `www.google.com` → `76.32.97.132` (attacker IP)
- Tricks users/applications into connecting to attacker's C2 server
- Common technique for traffic redirection and credential theft

---

### 7. Web Shell & Remote Access Analysis

**Method:**
- Navigate to `C:\inetpub\wwwroot` (default IIS web root)

**Findings:**
- **Malicious web shell:** `C:\inetpub\wwwroot\b.jsp`
- Enables attacker to execute arbitrary code via HTTP requests
- Provides remote code execution independent of user login

---

### 8. Firewall Rule Analysis

**Method:**
- Windows Defender Firewall → Inbound Rules

**Findings:**
- **Suspicious high-priority rule:** Allow inbound TCP on port 1337
- No "Allow connection if secure" requirement → **unencrypted backdoor access**
- Attacker can connect interactively and execute commands

---

## Persistence Mechanisms

The attacker deployed **five independent persistence methods** to survive reboots and password changes:

### 1. Scheduled Task – Malicious Cleanup Script

| Aspect | Detail |
|---|---|
| **Detection** | Task Scheduler GUI |
| **Task Name** | Clean File System |
| **Executable** | `C:\TMP\nc.ps1` |
| **Schedule** | Daily at 4:55 PM |
| **Purpose** | Suspicious cleanup; may disable security tools or cover tracks |
| **Persistence** | Survives reboots; continues daily unless disabled |

### 2. Scheduled Task – Mimikatz Password Dumping

| Aspect | Detail |
|---|---|
| **Detection** | Task Scheduler + PowerShell verification |
| **Executable** | `mim.exe` (Mimikatz) |
| **Output** | `C:\TMP\mim-out.txt` |
| **Purpose** | Extract plaintext/hash credentials from memory |
| **Impact** | Attacker gains all user credentials; survives password resets |

### 3. Windows Defender Firewall Rule

| Aspect | Detail |
|---|---|
| **Detection** | Firewall → Inbound Rules |
| **Status** | High-priority allow rule |
| **Port** | 1337 (TCP) |
| **Security** | No encryption requirement |
| **Purpose** | Unencrypted backdoor for reverse shell access |
| **Impact** | Interactive command execution; survives reboots |

### 4. DNS Poisoning Entry

| Aspect | Detail |
|---|---|
| **Detection** | `ipconfig /displaydns` |
| **Fake Domain** | `www.google.com` |
| **Resolves To** | `76.32.97.132` (C2 IP) |
| **Storage** | Local DNS cache |
| **Purpose** | Redirect traffic to C2 server; credential theft; malware delivery |
| **Persistence** | Limited (survives until cache clears, typically at reboot) |

### 5. Web Shell Deployment

| Aspect | Detail |
|---|---|
| **Detection** | File system inspection of `C:\inetpub\wwwroot` |
| **Location** | `C:\inetpub\wwwroot\b.jsp` |
| **Type** | JSP web shell |
| **Purpose** | Remote code execution via HTTP requests |
| **Impact** | Independent of user login; survives reboots if IIS running |

---

## Indicators of Compromise (IOCs)

| IOC Type | Value | Where Found | Recommended Action |
|---|---|---|---|
| **IP Address** | 10.34.2.3 | `C:\TMP\p.exe` | Block IP; further analysis |
| **Scheduled Tasks** | 1. Clean File System (`C:\TMP\nc.ps1`) 2. Mimikatz Execution (`C:\TMP\mim.exe`) | Task Scheduler | Retain for forensic analysis |
| **Port** | 1348 | Local listener (nc.ps1) | Kill task; block inbound traffic |
| **Executable** | `mim.exe` | `C:\TMP\` | Delete/retain for analysis |
| **Output File** | `C:\TMP\mim-out.txt` | File System | Delete/retain for analysis |
| **Firewall Rule** | Allow Inbound on port 1337 | Windows Defender Firewall | Delete rule |
| **DNS Entry** | `www.google.com` pointing to C2 IP | Hosts file/DNS cache | Flush DNS cache; clean hosts file |
| **Web Shell** | `.jsp` file | `C:\inetpub\wwwroot\b.jsp` | Delete; investigate |
| **C2 IP** | 76.32.97.132 | DNS poisoning entry | Block at firewall; investigate logs |
| **Admin Accounts** | Guest, Jenny | Local Administrators group | Disable if unused |

---

## Dead Ends & Ruled Out Hypotheses

### ❌ Legitimate System Maintenance?
- **Ruled out:** Scheduled tasks and firewall rules confirmed as malicious through:
  - Comparison with standard Windows configurations
  - Observation of suspicious command execution patterns
  - Presence of known attack tools (Mimikatz)

### ❌ Accidental Misconfiguration?
- **Ruled out:** The specific combination of password dumping, DNS poisoning, web shell, and scheduled backdoor tasks indicates **deliberate, coordinated attacker activity**, not accidental configuration

### ⚠️ Credential Usage Attribution?
- **Note:** Mimikatz evidence shows credential-access activity but does not prove which credentials were successfully used afterward
- Assume all extracted credentials as **compromised**

---

## Containment & Recommendations

### Immediate Actions (First 24 Hours)

1. **Isolate workstation from network immediately**
   - Disconnect Ethernet cable or disable wireless adapter
   - Prevent attacker from maintaining active access

2. **Reset passwords network-wide**
   - All user accounts that accessed this workstation
   - Local Administrator password on the workstation
   - Attacker extracted passwords via Mimikatz

3. **Remove malicious artifacts**
   - Disable/delete scheduled tasks: "Clean File System" and Mimikatz execution tasks
   - Delete firewall rule allowing inbound port 1337
   - Delete malicious files in `C:\inetpub\wwwroot` (especially web shell)
   - Remove DNS poisoning entries

4. **Perform malware scan**
   - Full antivirus and malware scan of the system

---

### Short-Term Actions (1-7 Days)

1. **Audit other workstations**
   - Search network systems for presence of IOCs listed above
   - Check for signs of lateral movement

2. **Review security logs**
   - Firewall logs for connections to C2 server IP (76.32.97.132)
   - Windows security logs for suspicious process execution

3. **Check for lateral movement**
   - Review login logs on other systems
   - Identify if accounts from this workstation accessed other machines

---

### Long-Term Changes (2-4 Weeks)

1. **Implement Endpoint Detection & Response (EDR)**
   - Detect suspicious process execution (Mimikatz, netsh, PowerShell abuse)
   - Alert on scheduled task creation and firewall rule modifications
   - Real-time behavioral analysis

2. **Deploy application whitelisting**
   - Block execution of known attack tools (Mimikatz, Netcat, etc.)
   - Process blocking rules to prevent credential dumping

3. **Enable Windows Event Log forwarding**
   - Centralized SIEM for logs beyond local retention limits
   - Retain security events for 6-12 months minimum

4. **Enforce multi-factor authentication (MFA)**
   - All user accounts (reduces impact of compromised passwords)

5. **Restrict administrative privileges**
   - Remove unnecessary users from local Administrators group
   - Audit and disable unnecessary admin accounts

---

## Detection Logic – What Should Have Alerted

### ⚠️ Three Detection Opportunities Were Missed:

#### 1. Mimikatz Execution Detection
- Monitor for process named `mim.exe` or `mimikatz.exe`
- This tool is **almost exclusively used by attackers** → immediate alert

**Detection Logic:**
```
Event ID 4688 (Process Creation) 
WHERE image name contains 'mim' or 'mimikatz' 
→ ALERT (Critical)
```

#### 2. Firewall Rule Modification Detection
- Monitor for Windows Firewall rule creation/modification via PowerShell
- Normal users do not create firewall rules

**Detection Logic:**
```
Process execution: netsh.exe 
WITH arguments containing 'advfirewall' and 'add' 
→ ALERT (High)

PowerShell script containing 'New-NetFirewallRule' 
→ ALERT (High)
```

#### 3. Scheduled Task Creation Detection
- Monitor for creation of new scheduled tasks outside standard administrative processes

**Detection Logic:**
```
Event ID 4698 (Scheduled Task Created) 
OR 4702 (Scheduled Task Updated)
WITH unusual task names or commands 
→ ALERT (Medium)
```

---

## Recommendation: Full System Rebuild

**Do not attempt to clean this system.**

### Why Incremental Remediation Is Insufficient:

1. **Multiple persistence mechanisms**
   - Attacker deployed at least 5 independent methods (scheduled tasks, firewall rules, web shell, DNS poisoning, startup mechanism)
   - Removing one or two does not guarantee all are eliminated

2. **Unknown initial access vector**
   - We do not know how the attacker initially compromised the system
   - Without understanding entry point, no guarantee that removing visible artifacts prevents re-compromise

3. **Registry and boot-level modifications**
   - Detailed registry inspection not performed
   - Attacker may have installed rootkits, boot sector modifications, or registry-based persistence (difficult to remove safely)

4. **Supply chain risk**
   - Web shell and scripts may be signed/packed to evade detection
   - Cleaning leaves risk of dormant malware

5. **Cost-benefit analysis**
   - Full rebuild cost: **2-4 hours** (OS installation, patching, app installation, configuration)
   - **Negligible** compared to risk of incomplete remediation and re-compromise

### Rebuild Procedure:

1. Fresh Windows Server 2016 installation
2. Apply all OS patches (latest as of rebuild date)
3. Reinstall only necessary business applications
4. Restore user data from backup **dated before March 2, 2019**
5. Restore user passwords from secure identity management system
6. **Do NOT restore** any configuration files, scripts, or executables from the compromised system

---

## Forensic Summary

**Compromise Confirmed:** ✓ Multiple lines of evidence  
**Attacker Skill Level:** Moderate (used known tools, standard techniques)  
**Dwell Time:** Unknown; discovered after compromise  
**Data Exfiltration:** Not confirmed in logs; assume credentials compromised  
**Lateral Movement:** Not confirmed; audit other systems  

---

**Report Generated:** August 11, 2026  
**Investigation Completed By:** Sharon Kipsang, Security Analyst
