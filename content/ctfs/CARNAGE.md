---
title: "CARNAGE — Malware Traffic Analysis"
date: 2026-08-16
categories: ["CTFs"]
tags: ["ctf", "wireshark", "network-forensics", "malware", "incident-response", "packet-analysis"]
summary: "A full walkthrough of the THM CARNAGE packet-analysis challenge, tracing malicious downloads, C2 infrastructure, and post-infection behavior from a Windows endpoint PCAP."
featureimage: "img/ctf/CARNAGE/carnage-hero.png"
locked: false
---

![Screenshot](/img/ctf/CARNAGE/carnage-hero.png)

Apply your analytical skills to analyze the malicious network traffic using Wireshark.

### Set up your virtual environment
I fired up my Lab Machine below. Also used the provided VPN configurations to connect to the machine locally so I could do analysis from my host machine.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260816160623.png)

### Scenario
Eric Fischer from the Purchasing Department at Bartell Ltd has received an email from a known contact with a Word document attachment. Upon opening the document, he accidentally clicked on "Enable Content." The SOC Department immediately received an alert from the endpoint agent that Eric's workstation was making suspicious connections outbound. The pcap was retrieved from the network sensor and handed to you for analysis.

##### Task: Investigate the packet capture and uncover the malicious activities.

### Traffic Analysis
Step1: Load the file in the Analysis folder on the Desktop into Wireshark.

a. Host the provided artefact from the THM lab machine using python.

```bash
python -m http.server 8000
```

b. Use wget to download the files to the desired folder locally.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260813050813.png)

c. Launch Wireshark tool and upload the carnage.pcap file and start analysis.
The capture contained 70,873 packets.

### Answer the questions below

##### 1. What was the date and time for the first HTTP connection to the malicious IP?
###### (answer format: yyyy-mm-dd hh:mm:ss)

Since we have been told of HTTP connection: On Wireshark, apply the `http` filter. This way, we narrowed down the investigation to just 211 HTTP packets.
While examining the HTTP traffic, notice the very first HTTP GET request of a suspicious download:

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260816161651.png)

- Source: `10.9.23.102`
- Destination: `85.187.128.24`
- Host: `attirenepal.com`
- File: `documents.zip`

I used File → Export Objects → HTTP to confirm that `documents.zip` was transferred, and then inspected the corresponding HTTP request.
The request:

`GET /incidunt-consequatur/documents.zip HTTP/1.1`
`Host: attirenepal.com`

Then I proceeded to check the packet timestamp and confirmed that this was the first HTTP connection to the malicious IP. To retrieve the date and time of the first HTTP connection, I went down on Packet Details and expanded the Frame section. I also set Wireshark's time display to UTC Date and Time of Day.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815093332.png)

###### Answer: 2021-09-24 16:44:38

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224039.png)

##### 2. What is the name of the zip file that was downloaded?
While reviewing the HTTP requests, there was a suspicious GET request from the internal host `10.9.23.102` to a host domain `attirenepal.com`:

```http
GET /incidunt-consequatur/documents.zip HTTP/1.1
Host: attirenepal.com
```

To confirm the transferred file, I used File → Export Objects → HTTP.
The exported HTTP objects showed:

```text
Filename: documents.zip
Content-Type: application/octet-stream
Size: ~198 KB
```

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815094059.png)
![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260814055049.png)

**Answer: `documents.zip`**

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224212.png)

##### 3. What was the domain hosting the malicious zip file?
On inspecting the download HTTP request of the zip file from the victim host 10.9.23.102, the HTTP request header shows the Host field.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815094630.png)

###### Answer: `attirenepal.com`

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224251.png)

##### 4. Without downloading the file, what is the name of the file in the zip file?
With the HTTP GET request of the malicious download, I did find the ZIP's internal filename by inspecting the raw TCP stream and searching for the ZIP signature:

```text
PK
```

Follow → TCP Stream to inspect the raw transferred data. The `PK` signature indicates the beginning of a ZIP archive. It reveals a file ending in .xls.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815100531.png)

###### Answer: chart-1530076591.xls

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224330.png)

#### 5. What is the name of the webserver of the malicious IP from which the zip file was downloaded?
Thinking of this question, my first option was HTTP header responses. So, on Wireshark HTTP transaction for packet 2173 and Follow stream, I inspected the HTTP response header from the malicious IP.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815105532.png)

###### Answer: LiteSpeed

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224542.png)

#### 6. What is the version of the webserver from the previous question?
This was pretty straightforward. From the same stream, the `X-Powered-By` identifies the application/runtime version, while the `Server` header identifies the webserver.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815114225.png)

###### Answer: PHP/7.2.34

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224626.png)

#### 7. Malicious files were downloaded to the victim host from multiple domains. What were the three domains involved with this activity?

Since I had seen a file download from the initial HTTP GET request, I proceeded to search for standard HTTP GET requests, but found nothing because modern malware encrypts payload delivery using HTTPS.
I then turned to DNS to identify the target domains, but still needed a way to prove that files were downloaded.
But during this question, I remembered that if a file download happened, it was not a single event, but lots of network conversations happen in between, and because of encryption from the hint on HTTPS traffic, I dropped down to the TCP layer and port 443 to prove actual data movement.
I also got a hint of the time filter between 19:45:11 and 19:45:30.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815153108.png)

I also filtered for `tls.handshake.type == 1` targeting the unencrypted Client Hello greeting packets sent before encryption started, instantly reducing 111 packets down to just 5 packets and exposing the malicious domains in plain text.

So the final filter looked like:

```text
tcp.port==443 && (frame.time >= "2021-09-24 19:45:11" && frame.time <= "2021-09-24 19:45:30") && tls.handshake.type == 1
```

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815143545.png)

###### Answer:
###### - `finejewels.com.au`
###### - `thietbiagt.com`
###### - `new.americold.com`

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224651.png)

#### 8. Which certificate authority issued the SSL certificate to the first domain from the previous question?
To find the certificate issuer for `finejewels`, using the packet that contains `finejewels.com.au` I went to right-click → Follow → TCP.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815155229.png)

###### Answer: GoDaddy

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224719.png)

#### 9. What are the two IP addresses of the Cobalt Strike servers? Use VirusTotal (the Community tab) to confirm if IPs are identified as Cobalt Strike C2 servers. (answer format: enter the IP addresses in sequential order)

The approach to this question was to find the common ports used by Cobalt Strike. Which is TCP port 50050 by default for connections between the client GUI and the central Linux Team Server. And for implant communication (listeners and beacons), it flexibly uses standard or custom ports—most commonly standard web ports like 80, 443, 8080, or non-standard ports (e.g., 7785, 14323) for HTTP/HTTPS/DNS traffic.

So applying the port filters:

```text
tcp.port == 80 || tcp.port == 8080 || tcp.port == 50050
```

Then navigate to Statistics → Conversations → TCP. Click Limit to display filter, then click the IPv4 tab, and sort based on packet count. Sorting by packet counts or byte streams reveals highly recurring communication loops between the infected internal host (10.9.23.102) and these external addresses belonging to the same /24 subnet block.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815185916.png)

Now, searching the two IPs on VT, and from the hint, on the community conversations we see that they are Cobalt Strike C2 servers.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815180313.png)
![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815185916.png)

###### Answer: 185.106.96.158, 185.125.204.174

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224751.png)

#### 10. What is the Host header for the first Cobalt Strike IP address from the previous question?

Since we have the IP, it was easy to think of filtering out and isolating HTTP traffic involving that specific IP.

```text
ip.addr == 185.106.96.158 && http
```

Using the first GET request packet:

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815192402.png)

Down in Packet Details and Hypertext Transfer Protocol, we find the Host header: `ocsp.verisign.com`.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815192858.png)

###### Answer: ocsp.verisign.com

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815224827.png)

#### 11. What is the domain name for the first IP address of the Cobalt Strike server? You may use VirusTotal to confirm if it's the Cobalt Strike server (check the Community tab).

Hearing of a domain name, I quickly thought of the DNS filter. It isolates the exact registration record where the computer mapped the IP address back to its human-readable website name.
Using the filter:

```text
dns.a == 185.106.96.158
```

One DNS packet was filtered out. Again, down in the Packet Details pane, the Domain Name System (response) → Queries or Answers displays the domain name.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815194710.png)
![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815193819.png)

###### Answer: survmeter.live

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815201809.png)

#### 12. What is the domain name of the second Cobalt Strike server IP? You may use VirusTotal to confirm if it's the Cobalt Strike server (check the Community tab).
This was interesting; it would have been just as easy as the previous question, but the hint was that this server communicates via encrypted HTTPS rather than unencrypted HTTP or plain DNS responses.

Therefore applying the HTTPS target filter:

```text
ip.addr == 185.125.204.174 && tls.handshake.type == 1
```

This filtered out TLS handshake packets for the IP. With the SNI (Server Name Indication) TLS extension, we can still see the domain name.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815195416.png)

###### Answer: securitybusinpuff.com

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815201745.png)

#### 13. What is the domain name of the post-infection traffic?
This one required a little research, and I learned a new term: heartbeat traffic. The question tests the ability to identify C2 and heartbeat traffic, which happens after malware execution and is used to periodically confirm that the connection still exists and to facilitate exfiltration.

So, most initial malware check-ins and data exfiltrations utilize HTTP POST requests because POST is designed to upload data from the victim back to a server.
Using the HTTP method filter:

```text
http.request.method == "POST"
```

With packet inspection under Hypertext Transfer Protocol, the name of the Host field is identified.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815204208.png)

###### Answer: maldivehost.net

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815205057.png)

#### 14. What are the first eleven characters that the victim host sends out to the malicious domain involved in the post-infection traffic?

While identifying these characters initially proved challenging, the breakthrough came from understanding the strict chronological order of network protocols. Because an HTTP POST request is transmitted from top to bottom in a sequence like:
- The Request Line: `POST /zLIisQRWZI9/...` (sent first)
- The Headers: `Host: maldivehost.net...` (sent second)
- The Data Body: `Dw8YBxsEGmYF...` (sent third)

Therefore the very first eleven characters the victim host sends out is at the beginning of the conversation: `zLIisQRWZI9`.

Using the previous POST request, the first packet:

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815211740.png)

###### Answer: zLIisQRWZI9

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815211921.png)

#### 15. What was the length for the first packet sent out to the C2 server?
This was pretty straightforward. From the very first HTTP POST request, checking the Length table:

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815212154.png)

###### Answer: 281

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815212231.png)

#### 16. What was the Server header for the malicious domain from the previous question?
This was also straightforward. Using the HTTP response:

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815212438.png)

###### Answer: Apache/2.4.49 (cPanel) OpenSSL/1.1.1l mod_bwlimited/1.4

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815212524.png)

#### 17. The malware used an API to check for the IP address of the victim’s machine. What was the date and time when the DNS query for the IP check domain occurred? (answer format: yyyy-mm-dd hh:mm:ss UTC)
On this question, I completely unlocked a new finding on the ability to identify and analyze malware profiling behavior. When an infection happens, malware always attempts to check the victim host's public IP address to verify its external location, bypass internal testing sandboxes, or map out geo-targeting data. It often abuses legitimate, public IP-lookup services to achieve this. The malware simply acts like a normal user opening a web browser and visiting a free, legitimate site like `ipify.org` or `icanhazip.com`, which simply spits back the public IP address.

So, using the filter below to find the exact moment the malware asked for where the IP-checking website was located:

```text
Filter: dns && frame contains "api"
```

Look for the resulting DNS query checking the domain `api.ipify.org`. Select the packet and expand Frame in the packet details pane to see the UTC arrival time.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815220346.png)

###### Answer: 2021-09-24 17:00:04

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815221236.png)

#### 18. What was the domain in the DNS query from the previous question?
From the filters above, the established domain in the DNS query is: `api.ipify.org`

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815221133.png)

###### Answer: `api.ipify.org`

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815221521.png)

#### 19. Looks like there was some malicious spam (malspam) activity going on. What was the first MAIL FROM address observed in the traffic?

While doing research on this question, I understood it as testing the ability to pivot from web C2 tracking to email security analysis and protocol parsing. This is done by attackers by abusing the victim's local processing power to transmit malicious spam and widen their footprint. A standard email protocol, SMTP, handles this scenario via explicit commands inside the application layer.
To capture the email sender data and cut directly to the sender definitions, add a content rule to the search filter:

```text
frame contains "MAIL FROM"
```

This narrowed the responses to only 11 packets, but I selected the very first packet with the `MAIL FROM` line.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815223251.png)

Answer: `farshin@mailfa.com`

#### 20. How many packets were observed for the SMTP traffic?
Simply did an SMTP filter.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815223553.png)

The count is at the bottom.

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815223659.png)

###### Answer: 1439

![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815223801.png)
![Screenshot](/img/ctf/CARNAGE/Pasted%20image%2020260815223851.png)