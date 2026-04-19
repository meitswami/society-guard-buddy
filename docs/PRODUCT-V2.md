# Kutumbika / Society Guard Buddy — V2 Roadmap (PRODUCT-V2)

This document captures a **planned V2** direction: deeper **RBAC**, **guard-centric accessibility**, and **voice / AI-assisted workflows**. It is a living product spec—not a commitment to ship order or dates until prioritized with stakeholders.

---

## 1. Vision (V2 in one paragraph)

**V2** should make the platform **safer and faster at the gate** for societies where guards may have **limited literacy or digital comfort**, while giving **society admins** clear control over **who sees and changes what** in the admin panel. Technology should **reduce cognitive load** (voice prompts, large touch targets, minimal typing) and optionally use **AI** to structure visitor/delivery/service flows **without replacing** human judgment or audit trails.

---

## 2. Pillar A — RBAC & role management (society-level)

### 2.1 Problem today (baseline)

- Office-bearers (President, Secretary, Treasurer, etc.) log in as **`admins`** with **Admin ID + password**; visibility is driven by **`society_roles.permissions`** (JSON booleans).
- Gating is largely **per top-level admin tab**, not per sub-screen or per CRUD action.
- **Society admins** do not yet have a first-class **in-app UI** to edit permission matrices for custom roles (much of this is oriented toward superadmin / DB).

### 2.2 V2 goals

| Goal | Description |
|------|-------------|
| **Society-admin role editor** | UI to create/edit roles (e.g. President, Secretary) and toggle **module access** without touching the database. |
| **Layered permissions** | **Phase A:** tab-level + read/write flags where it matters (e.g. residents, finance). **Phase B:** optional **per-action** matrix (Create / Read / Update / Delete) for high-risk modules. |
| **Safe defaults** | New roles start **locked down**; explicit grants required. |
| **Audit** | Log who changed role permissions and when (ties into existing audit concepts). |
| **Server-side alignment** | Where feasible, align UI gates with **RLS / policies** or guarded RPCs so permissions are not “UI-only.” |

### 2.3 Technical notes (for engineering)

- Extend or version **`society_roles.permissions`** schema (migration + backward compatibility via `mergeRolePermissions`-style merge).
- Centralize checks: **`can(admin, 'finance', 'write')`** helper used by routes and critical buttons.
- **Tour / onboarding** should respect reduced permissions (already partially tied to tabs).

**Effort:** medium–large; natural **V2.0–V2.1** milestone depending on Phase A vs B.

---

## 3. Pillar B — Guards: literacy-friendly + voice + AI flow assistant

### 3.1 Principles

- **Optional voice-first path** alongside existing forms (never force AI for compliance-critical societies).
- **Large buttons**, **icons**, **local language** audio prompts, **minimal free-text** (tap choices first).
- **Every AI-assisted capture** must show a **human-readable summary** before submit, with **Edit** and **Cancel**.
- **Audit trail**: store structured fields + optional audio/transcript reference; retain who confirmed the entry.

### 3.2 “Talking voice AI agent” (concept)

A **guided gate flow** that:

1. **Detects intent** (visitor / delivery / cab / service staff / vendor) via tap or short voice phrase.
2. **Asks the next missing field** in **spoken + on-screen** form (flat, purpose, OTP, photo, ID if required by society policy).
3. **Confirms** with the guard before creating the **same records** the app already uses (visitors, delivery, passes, etc.)—no parallel “shadow database.”

**Technology directions (pick per privacy/budget):**

| Approach | Pros | Cons |
|----------|------|------|
| **On-device / browser STT + TTS** + rule-based dialogue | Lower latency, less PII to third parties | More engineering for languages/dialects |
| **Cloud STT/TTS + LLM** for slot-filling | Faster to prototype rich dialogs | PII, cost, compliance, offline |
| **Hybrid** | Rules for compliance fields; LLM only for paraphrase/summary | Best balance if reviewed carefully |

### 3.3 Concrete V2 features (guard app)

- **Voice capture mode** for names/plates when typing is hard; still allow **manual correction**.
- **Preset phrases** in **local languages** (“Flat number?”, “Purpose?”, “OTP?”) with **one-tap replay**.
- **Photo-first** flows (face / number plate) with optional **OCR assist** for vehicle numbers (society-configurable).
- **Offline queue** (stretch): queue entries when network drops; sync with conflict handling.

**Effort:** large; split into **V2.2 voice shell** (TTS/STT + wizard) then **V2.3 AI slot-fill** (policy-bound).

---

## 4. Pillar C — Other high-value V2 integrations (suggested)

These are **optional** backlog items that fit “evolving tech” without all being AI.

| Theme | Idea | Why V2 |
|--------|------|--------|
| **AI assist (admin)** | Smart summaries of **complaints / feedback tickets**, duplicate-issue detection, suggested replies (human approves). | Reduces superadmin/support time. |
| **AI assist (resident)** | Multilingual **FAQ** over society notices and rules (grounded in published content). | Accessibility + clarity. |
| **WhatsApp / SMS** | Outbound OTP and visitor alerts where societies already live. | Adoption in India-heavy workflows. |
| **Hardware** | QR at gate, NFC badges, ANPR camera integration (partners). | Throughput at peak hours. |
| **Analytics** | Peak visitor times, guard response times, repeat vendors. | Committee reporting. |
| **Compliance pack** | Data retention settings, export/delete requests, consent logs. | Societies and RWA legal comfort. |

---

## 5. Suggested phasing (indicative)

| Milestone | Focus | Outcome |
|-----------|--------|---------|
| **V2.0** | Society-admin **role & permission editor** (tab-level + key `*_rw` flags) + audit for permission changes | Delegation without superadmin for every toggle |
| **V2.1** | Deeper **action-level** permissions for 1–2 high-risk modules (e.g. finance, residents) + server alignment | Lower risk of over-permissioned roles |
| **V2.2** | **Guard voice wizard** (TTS + STT + structured steps) for visitor/delivery/service | Faster gate, literacy-friendly |
| **V2.3** | **Policy-bound AI** (slot filling, summaries) + optional OCR | Smarter flows with guard-in-the-loop |

Phasing can change based on **privacy decisions**, **pilot society** feedback, and **infra** (on-device vs cloud).

---

## 6. Risks & non-goals

**Risks**

- **Over-trusting AI** at the gate → wrong flat / wrong purpose. Mitigation: **confirm screen**, **audio playback**, **edit**, **full audit**.
- **PII & recordings** → need **retention policy**, **consent signage**, **secure storage**, and **jurisdiction-aware** vendor choice.
- **Dialect / noise** → STT errors; mitigate with **tap-first** and **numeric keypad** for flats.

**Non-goals (unless explicitly added later)**

- Fully autonomous gate decisions without a guard.
- Replacing legal visitor logs with unstructured chat only.

---

## 7. How to use this doc

- **Product:** Prioritize milestones, define pilot society, define “must work offline” vs not.  
- **Engineering:** Break Pillar A into migrations + UI + `can()` helper; break Pillar B into spike (STT/TTS POC) then integration with existing visitor/delivery tables.  
- **Compliance / committee:** Review voice recording, third-party AI, and retention **before** enabling cloud LLMs.

---

*Document version: 1.0 — internal V2 planning (`docs/PRODUCT-V2.md`).*
