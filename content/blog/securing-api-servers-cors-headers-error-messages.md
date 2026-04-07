---
title: "Securing API Servers: What CORS, Headers, and Error Messages Reveal About API Security"
date: 2026-01-30
categories: ["Blog"]
tags: ["api-security", "cors", "security-headers", "error-messages", "recon"]
summary: "A hands-on review of the Swagger Petstore API uncovering five server-level misconfigurations — none in the business logic, all hiding in plain sight."
externalUrl: "https://medium.com/@missbyte/securing-api-servers-what-cors-headers-and-error-messages-reveal-about-api-security-23a5b02f3268"
---

> *Originally published on [Medium](https://medium.com/@missbyte/securing-api-servers-what-cors-headers-and-error-messages-reveal-about-api-security-23a5b02f3268)*

---

When developers think about API security, they often focus on authentication tokens and input validation. But there's an invisible layer that's equally critical: server-level configuration. The headers an API returns, how it handles errors, and its CORS policy can either protect users or quietly expose them to attack.

In this article — my first ever — I explore what a simple security review of the Swagger Petstore API revealed about common misconfigurations, and what teams can do to avoid them.

---

## Lab Setup

To perform hands-on API security testing, I created a local lab environment using the **Swagger Petstore API**.

| Component | Detail |
|-----------|--------|
| **API Target** | Swagger Petstore (OpenAPI sample project) — cloned from GitHub |
| **Deployment** | Docker |
| **Traffic Interception** | Postman routed through Burp Suite Proxy — captured, analysed, and replayed HTTP requests |

---

## B. Why Server-Level Configuration Matters

> Your API's business logic might be flawless, but if the server wrapping it is misconfigured, attackers don't need to break your code — they simply exploit the gaps around it.

Server-level settings determine:

- **Who can call your API** — CORS policy
- **How browsers treat your responses** — security headers
- **What attackers learn when things fail** — error messages

These configurations are often set once and forgotten, inherited from boilerplate, or left at framework defaults. That's exactly what attackers count on.

---

## C. CORS — The Gatekeeper Nobody Configured

**CORS (Cross-Origin Resource Sharing)** determines which websites can make requests to your API from a user's browser. It's your first line of defense against cross-site data theft.

### What I Found

| Header | Value | Risk |
|--------|-------|------|
| `Access-Control-Allow-Origin` | `*` | ⚠️ High — any website can call this API |
| `Access-Control-Allow-Methods` | `GET, POST, DELETE, PUT` | All methods open to cross-origin requests |
| `Access-Control-Allow-Headers` | `Content-Type, api_key, Authorization` | Credentials allowed from any origin |

The wildcard `*` means no restrictions — any website, including malicious ones, can call this API from a visitor's browser. If a user has an active session or cached credentials, an attacker's site can read responses, create records, or delete data on their behalf.

### The Common Mistake

Teams set `Access-Control-Allow-Origin: *` during development for convenience, then ship it to production unchanged. It "works," so no one revisits it.

### The Fix

Explicitly whitelist trusted origins:

```http
Access-Control-Allow-Origin: https://myapp.com
```

If you need multiple origins, validate the `Origin` header against an allowlist and reflect it dynamically — never use wildcards in production APIs handling sensitive data.

---

## D. Security Headers — The Missing Armor

Security headers instruct browsers how to handle your API responses. Without them, you're relying on browser defaults which favor compatibility over security.

The Petstore API was **missing every major security header**:

| Header | Purpose |
|--------|---------|
| `X-Content-Type-Options` | Prevents MIME-sniffing attacks |
| `X-Frame-Options` | Prevents clickjacking |
| `Strict-Transport-Security` | Protects against SSL stripping / downgrade attacks |
| `Content-Security-Policy` | Prevents script injection |

It did include one header that **shouldn't be there**:

```http
Server: Jetty(9.4.9.v20180320)
```

This tells attackers exactly what software version to target. A quick CVE search reveals known vulnerabilities for this exact release.

### The Fix

Add these headers at the server or reverse proxy level:

```http
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
Server: API
```

---

## E. Error Messages — When Your API Talks Too Much

Error messages exist to help clients understand what went wrong. But when they reveal internal details, they become a **reconnaissance tool** for attackers.

### Invalid pet ID on `/pet/abc`

```json
{
  "code": 400,
  "message": "Input error: couldn't convert `abc` to type `class java.lang.Long`"
}
```

### Malformed JSON body

```json
{
  "code": 400,
  "message": "Input error: unable to convert input to io.swagger.petstore.model.Pet"
}
```

From two simple bad requests, an attacker now knows:

- The backend runs **Java**
- Expected parameter types — `Long`
- Internal package structure — `io.swagger.petstore.model`
- The API uses **Swagger-generated models**

This information shapes targeted attacks — SQL injection payloads, deserialization exploits, or CVE lookups for the identified stack.

### The Fix

Catch exceptions at the API boundary and return generic messages:

```json
{ "error": "Invalid pet ID format" }
{ "error": "Invalid request body" }
```

Log the details server-side. Never expose them to clients.

---

## The Most Critical Finding

I performed an **unauthenticated destructive action** on `/pet/:petId`. A `DELETE /pet/10` request succeeded without any credentials, returning `200 OK`.

Combined with the wildcard CORS policy, any malicious website could silently delete resources on behalf of any user visiting their page.

**Fix:** Enforce authentication on all state-changing endpoints. Return `401 Unauthorized` when credentials are missing.

---

## Quick Checklist for Teams

- **CORS** — Replace `*` with an explicit origin whitelist
- **Headers** — Add `X-Content-Type-Options`, `X-Frame-Options`, `HSTS`, `CSP`
- **Server header** — Remove version info, return `Server: API`
- **Errors** — Return generic messages, log details internally
- **Auth** — Enforce credentials on `POST`, `PUT`, `DELETE` endpoints

---

## Final Thought

A single API review revealed five security gaps — none in the business logic, all in server configuration. Secure code means nothing if it's wrapped in an insecure server. These configurations take minutes to fix but protect against attacks that bypass your application entirely. Reviewing them before deployment is not optional.
