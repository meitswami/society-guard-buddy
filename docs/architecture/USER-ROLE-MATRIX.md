# User Role Matrix — Kutumbika V2

Access by role. Admin module access is further restricted by `society_roles.permissions` (RBAC).

---

## Platform roles

| Capability | Guard | Resident | Admin | Super Admin |
|------------|:-----:|:--------:|:-----:|:-----------:|
| Select society | Yes | Yes | Yes | Optional |
| Visitor / delivery entry | Yes | Approve only | View reports | — |
| Vehicle / blacklist / directory | Yes | Own vehicles | Manage | — |
| Maintenance pay / view | — | Yes | Verify + manage | — |
| Finance ledger / period report | — | Receive PDF | Yes (if `finance`) | — |
| Meetings (admin edit) | — | Read published | Yes (if `meetings`) | — |
| Polls / elections vote | — | Yes | Create + close | — |
| Events & food | — | Contribute / view splits | Yes (if `events`) | — |
| Committee roster | — | View (if exposed) | Yes (if `committee`) | — |
| Notifications send | — | Receive | Yes (if `notifications`) | — |
| Emergency alert broadcast | Yes | Yes | Receive | — |
| Audit logs / self-audit | — | — | Yes (if `audit`) | — |
| Geofence setup | — | — | Yes (if `geofence_rw`) | — |
| Society settings / branding | — | Profile | Yes (if `settings`) | All societies |
| RBAC role edit | — | — | DB / superadmin only | Yes |
| Backup export | — | — | — | Yes |
| Society signup provisioning | — | — | — | Yes (via PhonePe callback) |

---

## Admin RBAC permission flags

Defined in `src/lib/adminPermissions.ts`. Each flag gates an admin tab or module.

| Permission key | Admin tab / module |
|----------------|-------------------|
| `residents_rw` | Residents |
| `guards_rw` | Guards |
| `geofence_rw` | Geofence |
| `finance` | Finance |
| `donations` | Donations |
| `events` | Events & food |
| `splits` | Legacy — treated as alias for `events` |
| `meetings` | Meetings |
| `committee` | Committee |
| `polls` | Polls & elections |
| `notifications` | Notify |
| `parking` | Parking |
| `visitor`, `delivery`, `vehicle`, `blacklist`, `directory`, `quick` | Guard ops (admin view) |
| `report` | REPORTS |
| `logs` | Guard shift logs |
| `audit` | Audit |
| `settings` | Settings |
| `password` | Password reset tools |
| `biometric` | Biometric setup |

**Legacy admins** without `role_id` receive full access. **New custom roles** from superadmin start locked down (`NEW_CUSTOM_ROLE_PERMISSIONS`) except `finance: true` and `directory: true`.

---

## Authentication methods

| Role | Primary auth | Optional |
|------|-------------|----------|
| Guard | Guard ID + password | WebAuthn, OTP (phone) |
| Resident | Phone + password | WebAuthn, Firebase SMS OTP |
| Admin | Admin ID + password | WebAuthn |
| Super admin | Username + password | TOTP MFA, WebAuthn, email recovery |

---

## Sensitive actions

| Action | Extra verification |
|--------|-------------------|
| Admin resident data changes | `SensitiveAdminVerifyModal` (biometric/password) |
| Guard login outside geofence | Blocked at login |
| Guard shift outside geofence | Logged to `audit_logs` (not blocked) |
| Superadmin login | TOTP when enabled |
| Finance delete / bulk operations | SweetAlert2 confirm (UI); no server-side re-auth |

---

## Audit visibility by role

| Audit feature | Admin (`audit`) | Other roles |
|---------------|-----------------|-------------|
| Security audit logs | Yes | No |
| Duplicate maintenance alarms | Yes | No |
| Self-audit engine | Yes | No |
| Manual audit tracer | Yes | No |
| Governance guide | Yes | Public summary on `/about` |

---

## Future (PRODUCT-V2)

- **V2.1:** Society-admin in-app role editor; read/write split per module
- **V2.1:** Server-side RLS aligned to role permissions
- **V2.2+:** Guard voice flows (same data tables, new UI path)

---

*See [OVERVIEW.md](./OVERVIEW.md) for architecture context.*
