---
title: "Windows Investigations 1.0 — TryHackMe"
date: 2026-08-24
categories: ["CTFs"]
tags: ["thm", "windows", "forensics", "incident-response", "event-viewer", "mimikatz"]
summary: "Windows Server 2016 forensics lab — 16-question incident response challenge covering event logs, scheduled tasks, persistence mechanisms, and attacker infrastructure analysis."
---

**Name :** Sharon Kipsang
**THM Name:**  H3x1M1st
**Link :** https://tryhackme.com/room/investigatingwindows?utm_campaign=social_share&utm_medium=social&utm_content=share-completed-room&utm_source=copy&sharerId=659d2a88f6d7f1fdcd08c2d6

#### **Connections set-up**
#### Using xfreerdp client
a. Dowwnload the openvpn config files
![](/img/ctf/windows-investigations/Pasted%20image%2020260819043141.png)
Connections using the openvpn
![](/img/ctf/windows-investigations/Pasted%20image%2020260819043242.png)
Xfreerdp client connections
![](/img/ctf/windows-investigations/Pasted%20image%2020260819043417.png)
### Answer the questions below

#### 1. Whats the version and year of the windows machine?
Using cmd
```
1. Run cmd -> systeminfo
   Other options
2. Go the normal way: **Settings -> About**
3. Run winver
```
![](/img/ctf/windows-investigations/Pasted%20image%2020260819045415.png)
$$
Answer:Windows Server 2016
$$
#### 2. Which user logged in last?
**a. Using Command Prompt (Active Sessions)**
- Run `cmd`, and press
- Type `quser` (or `query user`) and hit **Enter**.
Displays currently active and disconnected user sessions with their logon times. 
![](/img/ctf/windows-investigations/Pasted%20image%2020260819051555.png)
**b. Using Event Viewer (Logon History)**
- Run `eventvwr.msc`,
- Go to **Windows Logs** -> **Security**.
- On the right side **Filter Current Log** on the right panel.
- Enter Event ID `4624` (successful logons) and look at the top recent entries for interactive logon types.
This method was deta**iled enough. Looking through windows event IDs and types. For instance** event ID 4624  for a successful logon and **Type 10** fpr a  virtual access using RDP for our case.
#### ![](/img/ctf/windows-investigations/Pasted%20image%2020260819063434.png)
									$Answer: Administrator$
									
#### 3.  When did John log onto the system last?
#### Answer format: MM/DD/YYYY H:MM:SS AM/PM
Simply used the `net user` command a built-in Windows command-line utility used by administrators to add, remove, modify, or display information about local and domain user accounts.
On `cmd` `net user John`

![](/img/ctf/windows-investigations/Pasted%20image%2020260822180432.png)
									$Answer : 03/02/2019 5:48:32 PM$
#### 4. What IP does the system connect to when it first starts?  
I took time looking for this answer, yet one time while starting the target machine, I saw this cmd spaw and was curious to try this IP. And this was the answer.
![](/img/ctf/windows-investigations/Pasted%20image%2020260822211938.png)
									**$Answer : 10.34.2.3$**
#### 5. What two accounts had administrative privileges (other than the Administrator user)?
	#### Answer format: List them in alphabetical order.
Used the `net localgroup administrators` windows built-in too used to view, add, or remove accounts from the local Administrators group
![](/img/ctf/windows-investigations/Pasted%20image%2020260822202514.png)
									**$Answer: Guest, Jenny$**
#### 6. Whats the name of the scheduled task that is malicious.  

**Using Event Viewer**
![](/img/ctf/windows-investigations/Pasted%20image%2020260822205718.png)
**Using power-shell to get scheduled tasks**
![](/img/ctf/windows-investigations/Pasted%20image%2020260822211048.png)
On cmd: 
Command `schtasks`
![](/img/ctf/windows-investigations/Pasted%20image%2020260822213011.png)
									$Answer: Clean File System$
#### 7. What file was the task trying to run daily?  
On **Task Scheduler** the earlier found **Clean File System**, on the **Actions** tab

![](/img/ctf/windows-investigations/Pasted%20image%2020260822212424.png)
									**$Answer : nc.ps1$**
#### 8. What port did this file listen locally for?  
Based on the Details tab on the file path and name, the script runs a Netcat payload and is set to listen on port 1348. The `-l 1348` argument explicitly tells the program to **listen** for incoming connections on that specific port number.
![](/img/ctf/windows-investigations/Pasted%20image%2020260823053912.png)
$$
Answer: 1348
$$
#### 9. When did Jenny last logon?  
Command : `net user Jenny`
![](/img/ctf/windows-investigations/Pasted%20image%2020260823052309.png)
$$
Answer : Never
$$
#### 10. At what date did the compromise take place?

#### Answer format: MM/DD/YYYY

We earlier on saw a malicious file we found earlier on `C:\TMP`, so went on to check what other tasks/files were on that folder.
As seen below most tasks were created on that same day, 3/2/2019![](/img/ctf/windows-investigations/Pasted%20image%2020260824053223.png)
									$Answer: 03/02/2019$
#### 11. During the compromise, at what time did Windows first assign special privileges to a new logon?
#### Answer format: MM/DD/YYYY HH:MM:SS AM/PM
From the hint from the room, we are to do a filter of the event ID 4672 between a custom range time as demonstrated below

![](/img/ctf/windows-investigations/Pasted%20image%2020260824054737.png)
![](/img/ctf/windows-investigations/Pasted%20image%2020260824054828.png)
										$Asnwer : 03/02/2019  04:04:49 PM$

#### 12. What tool was used to get Windows passwords?  
![](/img/ctf/windows-investigations/Pasted%20image%2020260824060114.png)

![](/img/ctf/windows-investigations/Pasted%20image%2020260824061029.png)
									$Answer : Mimikatz$
#### 13. What was the attackers external control and command servers IP?  

![](/img/ctf/windows-investigations/Pasted%20image%2020260824062236.png)
									$Answer : 76.32.97.132$
#### 14. What was the extension name of the shell uploaded via the servers website?  
I found this question challenging. I couldn't think of a web application/server running anywhere. But the following information revealed an IIS server running. For Windows, the primary file directory for the default website in IIS is typically located at `C:\inetpub\wwwroot.` This is the root folder where web content for the default website is stored.
Therefore on navigating on he C drive, inetpub folder we find the wwwrot folder which has the file extensions.
![](/img/ctf/windows-investigations/Pasted%20image%2020260824183722.png)
									$Answer : .jsp$
#### 15. What was the last port the attacker opened?  
To find the last port the attacker opened on a Windows machine, we check the Windows **Defender Firewall with Advanced Security** logs. Whenever a program opens a port to listen for connections, the Windows Firewall logs a specific event.

![](/img/ctf/windows-investigations/Pasted%20image%2020260824181153.png)
Then open **Inbound Rules,** which allows outside connections was suspicious. Upon navigating to it Proocols and Ports we found the answer.
![](/img/ctf/windows-investigations/Pasted%20image%2020260824181605.png)
										$Answer : 1337$
#### 16.Check for DNS poisoning, what site was targeted?
From the previous found target IP we also got to establish the site to be google.com
![](/img/ctf/windows-investigations/Pasted%20image%2020260824062254.png)
										$Answer : google.com$

![](/img/ctf/windows-investigations/Pasted%20image%2020260824203718.png)

![](/img/ctf/windows-investigations/Pasted%20image%2020260824203742.png)

