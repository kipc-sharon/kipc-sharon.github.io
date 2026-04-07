---
title: "Havoc C2 Infrastructure Setup — Hands-On Lab"
date: 2026-01-07
categories: ["Red Team"]
tags: ["c2", "havoc", "adversary-simulation", "payload", "post-exploitation"]
summary: "Step-by-step walkthrough of setting up full Havoc C2 infrastructure — Teamserver, Client GUI, Listener, Demon payload generation, and delivery."
---

## Report Info

| Field | Detail |
|-------|--------|
| **Operator** | Sharon Kipsang |
| **Date** | January 7, 2026 |
| **Framework** | Havoc C2 |
| **Lab Environment** | Kali Linux (Attacker) → Windows VM (Target) |
| **Objective** | Set up a full C2 infrastructure — Teamserver, Client, Listener, Payload, and Delivery |

---

## Overview

Havoc is a modern, open-source **Command and Control (C2) framework** designed for red team operations. It provides a clean operator interface, flexible listener management, and a powerful agent called **Demon** that supports evasion techniques like indirect syscalls and sleep obfuscation.

In this lab, I walk through setting up the full Havoc C2 pipeline from scratch — from connecting the Client GUI to the Teamserver, to generating a payload and delivering it to a target machine.

> **What is C2?** A Command and Control framework gives an attacker a centralised dashboard to manage compromised machines (agents). The attacker sends commands; the agents execute them and report back. Think of it as a reverse shell on steroids — with encryption, persistence, and operational management built in.

---

## Tools Used

- Havoc C2
- Kali Linux
- Windows VM (Target)
- Python3 HTTP Server

---

## Step 01 — Havoc Client GUI: Connecting to the Teamserver

In Havoc, the **Teamserver** (the engine) and the **Client** (the steering wheel) are separate components. The Client GUI is your login portal to the base of operations.

![Havoc Client GUI — Login Portal](/img/red-team/havoc-client-gui.png)

### The Connection Dialog Fields

- **Name:** A nickname for your connection (e.g. `Local-Havoc`). This is only for your reference.
- **Host:** Since the server runs on the same machine, enter `127.0.0.1`. For a remote VPS, use the VPS IP.
- **Port:** The default Havoc Teamserver port is **40056**.
- **User:** The username defined in your `havoc.yaotl` configuration file.
- **Password:** The password from the same config file.

![Connection Dialog — Fields](/img/red-team/havoc-connection-dialog.png)

![Connection Dialog — Filled](/img/red-team/havoc-connection-filled.png)

![Connected to Teamserver](/img/red-team/havoc-connected.png)

> **Key Takeaway:** The Teamserver and Client are decoupled — you can run the Teamserver on a VPS and connect multiple operators from different locations. This mirrors real-world red team infrastructure.

---

## Step 02 — Creating a Listener

A **Listener** is what waits for incoming agent connections. When a payload executes on a target, it calls back to this listener.

**Steps:**
1. In the top menu, click **View → Listeners**
2. Click **Add** to create a new listener
3. Configure:
   - **Name:** `http-listener`
   - **Payload:** HTTPS
   - **Host (Bind):** Your Kali IP (`ip a` to find it)
   - **Port:** `443` or `80`
4. Click **Save**

![Listener Configuration](/img/red-team/havoc-listener-config.png)

![Listener Active](/img/red-team/havoc-listener-active.png)

> **Why HTTPS?** C2 traffic over HTTPS blends in with normal web browsing. Firewalls are less likely to flag encrypted traffic on port 443.

---

## Step 03 — Generating the Payload (Demon Agent)

The **Demon** is Havoc's agent — the binary that runs on the target and calls back to your listener.

**Steps:**
1. Go to **Attack → Payload**

![Attack → Payload Menu](/img/red-team/havoc-payload-menu.png)

2. Configure:
   - **Listener:** `http-listener`
   - **Format:** Windows Exe (or Shellcode for stealth)
   - **Architecture:** x64
   - **Sleep:** `5s` with `20%` jitter
   - **Indirect Syscalls:** Enable

3. Click **Generate**

![Demon Payload Configuration](/img/red-team/havoc-demon-config.png)

![Payload Generated](/img/red-team/havoc-payload-generated.png)

**MITRE ATT&CK Mapping:**
- **T1587.001** — Develop Capabilities: Malware
- **T1573.002** — Encrypted Channel: Asymmetric Cryptography
- **T1029** — Scheduled Transfer (sleep + jitter)

---

## Step 04 — Payload Delivery via Python HTTP Server

With the payload generated, serve it from Kali to the Windows target:

```bash
python3 -m http.server 80
```

Then on the Windows target, browse to `http://<kali-ip>/demon.exe`, download and execute.

![Python HTTP Server — Payload Delivery](/img/red-team/havoc-python-delivery.png)

> **Note:** In real engagements, delivery uses phishing, malicious documents, or USB drops. This lab uses a direct HTTP download to focus on the C2 pipeline itself.

---

## Conclusion

| Phase | Action | Component |
|-------|--------|-----------|
| **Infrastructure** | Start Teamserver, connect Client | Teamserver + Client GUI |
| **Comms** | Create HTTPS listener on port 443 | Listener |
| **Weaponisation** | Generate Demon agent with evasion | Payload |
| **Delivery** | Python HTTP server | Delivery mechanism |

**What's Next:** With C2 infrastructure operational, the next steps are post-exploitation — credential dumping, lateral movement, and persistence. Covered in future writeups.
