# Production Security Specification: Flutter & Supabase Architecture
**Role:** Principal Security Architect  
**Status:** Approved & Mandatory  
**Target:** MaxGym Full-Stack Architecture (Flutter Client + Supabase Backend/PostgreSQL)

---

## Executive Summary & Non-Negotiable Directives
This specification constitutes the binding security blueprint and audit checklist for MaxGym. Every directive across user registration, authentication, session management, authorization, encryption at-rest/in-transit, database hardening, and infrastructure operations must be strictly enforced. Deviations require an approved Architecture Decision Record (ADR) and explicit security review.

---

### Domain 1: Authentication & Credential Security

#### 1.1 Password Policies (Supabase Auth Configuration)
- **MANDATORY:**
  - Enforce minimum password length of **at least 10 characters** with required lowercase, uppercase, and numerical digits.
  - Enable **Leaked Password Protection** (HaveIBeenPwned integration) in Supabase Auth to block compromised passwords at signup and password resets.
  - Require **email confirmation** for all signups to prevent throwaway accounts, spam registrations, and account enumeration.
  - Enforce **rate limiting** at both the Supabase Auth tier (max 30 signups/hour/IP) and application tier against credential stuffing and brute-force attacks.
- **PROHIBITED:**
  - Never make authorization or access control decisions based on `user_metadata`. `user_metadata` is client-writable and forgeable.
- **VERIFICATION:**
  - Attempt signup with a password < 10 chars or common breached password (e.g. `P@ssword1234`) and verify rejection with generic error.
  - Confirm via Supabase dashboard/SQL that roles and privileges are read strictly from `app_metadata` or dedicated relational tables.

#### 1.2 Multi-Factor Authentication (MFA)
- **MANDATORY:**
  - Enforce **TOTP-based MFA** for all privileged administrative accounts (super-admin, gym owners, billing roles).
  - Provide optional TOTP MFA for general users/coaches with strong prompts for sensitive operations.
  - Require **explicit re-authentication** (`supabase.auth.reauthenticate()`) prior to sensitive lifecycle actions (password changes, primary email changes, MFA deactivation).
- **PROHIBITED:**
  - Never allow MFA bypass, fallback to unverified SMS without rate limits, or session elevation without TOTP verification.
- **VERIFICATION:**
  - Attempt password/email modification without re-authentication and verify server rejection with 401/403.

#### 1.3 Session & Token Management
- **MANDATORY:**
  - Configure **short-lived access tokens** (maximum 1 hour expiry) with **refresh token rotation** enabled.
  - Enforce refresh rate limits (max 150 refreshes/hour/user) to prevent token harvesting.
  - Enforce **server-side session invalidation** upon logout or credential alteration (`supabase.auth.signOut(scope: SignOutScope.global)`). Client-side cache clearing alone is non-compliant.
  - Schedule annual rotation of JWT signing keys. Edge Functions and backend services must dynamically verify tokens without hardcoded static secrets.
- **PROHIBITED:**
  - Never retain valid server sessions when a user is deactivated, suspended, or logged out.
- **VERIFICATION:**
  - Log out on Client A and attempt to make an API call using the pre-existing access/refresh token; verify immediate 401 Unauthorized rejection.

---

### Domain 2: Authorization & Row Level Security (RLS)

#### 2.1 RLS Enforcement (Zero-Tolerance)
- **MANDATORY:**
  - Enable **Row Level Security (RLS) on EVERY table** in exposed schemas (`public`, etc.) within the same migration creating the table.
  - Write **distinct, granular policies for each operation** (`SELECT`, `INSERT`, `UPDATE`, `DELETE`).
  - For all `UPDATE` policies, include both **`USING`** (row eligibility for update) and **`WITH CHECK`** (validity of new row values) to prevent privilege escalation.
- **PROHIBITED:**
  - Never deploy a single `FOR ALL` policy as an operational shortcut.
  - Never leave a table with `ENABLE ROW LEVEL SECURITY` omitted.
- **VERIFICATION:**
  - Run database audit query:
    ```sql
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' 
    AND tablename NOT IN (SELECT tablename FROM pg_tables t JOIN pg_class c ON c.relname = t.tablename WHERE c.relrowsecurity = true);
    ```
    Must return 0 rows.

#### 2.2 RLS Performance & Correctness
- **MANDATORY:**
  - **Index every column** referenced in RLS policy predicates (notably `coach_id`, `athlete_id`, `user_id`).
  - Encapsulate auth calls in subqueries: use `(SELECT auth.uid())` instead of bare `auth.uid()` to trigger PostgreSQL `initPlan` single-evaluation optimization.
  - Explicitly specify the target role using the **`TO` clause** (e.g., `TO authenticated`, `TO anon`).
- **PROHIBITED:**
  - Avoid deprecated `auth.role()` calls which pose privilege leakage risks under anonymous sign-in configurations.
- **VERIFICATION:**
  - Execute `EXPLAIN ANALYZE` on policy-guarded queries; confirm indexed index scans and `InitPlan` execution instead of per-row `SubPlan` sequential scans.

#### 2.3 View & Function Security
- **MANDATORY:**
  - Construct all user-facing views with **`WITH (security_invoker = true)`** (PostgreSQL 15+) so views execute under the querying client's RLS constraints.
  - Audit all **`SECURITY DEFINER`** functions. Strictly define explicit search paths: `SET search_path = public, pg_temp` to neutralize CWE-426 search path hijacking.
  - Implement explicit caller authorization checks inside all `SECURITY DEFINER` function bodies before performing privileged operations.
- **PROHIBITED:**
  - Never create views with default `security_definer` semantics that silently bypass underlying table RLS.
- **VERIFICATION:**
  - Inspect `pg_proc` for `prosecdef = true` and assert `proconfig` includes `search_path`.

---

### Domain 3: Data Protection (At Rest & In Transit)

#### 3.1 Secrets & API Key Management
- **MANDATORY:**
  - Expose only the **publishable (`anon`) key** in the Flutter client code and mobile binaries.
  - Couple the `anon` key strictly with hardened RLS and explicit RPC grants.
- **PROHIBITED:**
  - **NEVER expose `service_role` keys** in client source code, app binaries, Git history, or client-accessible environment files.
- **VERIFICATION:**
  - Run automated Git secret scanning tools (`trufflehog`, `gitleaks`) on every commit and CI/CD pull request.

#### 3.2 Flutter Client-Side Storage Hardening
- **MANDATORY:**
  - Store all session tokens, cryptographic keys, and sensitive biometric/PII data exclusively via **`flutter_secure_storage`** backed by **iOS Keychain (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)** and **Android Keystore (EncryptedSharedPreferences / MasterKey AES-256-GCM)**.
  - For local offline caching beyond secure storage, ensure database columns containing sensitive credentials use hardware-derived AES-256 encryption.
- **PROHIBITED:**
  - Never store session tokens, passwords, or PII in plaintext `shared_preferences` or unencrypted local file stores.
- **VERIFICATION:**
  - Dump sandbox storage of test app on physical/emulated devices and verify absence of plaintext tokens or credentials.

#### 3.3 Network Transport Security (TLS)
- **MANDATORY:**
  - Enforce **HTTPS / TLS 1.3** across all network endpoints.
  - Retain strict X.509 certificate validation in Dart client network clients.
  - Implement certificate pinning for high-risk, high-security endpoints.
- **PROHIBITED:**
  - Never permit `badCertificateCallback = (cert, host, port) => true` in Dart HTTP clients under any condition.
- **VERIFICATION:**
  - Intercept network traffic using MITM proxy (Burp Suite / Charles); verify client aborts connection when untrusted CA is injected.

#### 3.4 Database & Storage Encryption
- **MANDATORY:**
  - Enforce SSL on all direct PostgreSQL database connections (`sslmode=require` / `verify-full`).
  - Restrict port 5432 database access using Supabase Network Restrictions (IP allowlists).
- **PROHIBITED:**
  - Never expose direct database ports (5432) to unrestricted public CIDR `0.0.0.0/0`.
- **VERIFICATION:**
  - Attempt unencrypted connection to PostgreSQL port; assert handshake failure.

---

### Domain 4: Server & Infrastructure Hardening

#### 4.1 Edge Functions & Microservices
- **MANDATORY:**
  - Every Edge Function must parse and validate the incoming `Authorization` header and verify JWT authenticity before business logic execution.
  - Inject external API secrets strictly via Supabase Vault / Edge Function Secrets.
  - Restrict CORS headers to allowlisted origins (`https://maxgym.privatepath.ir`).
- **PROHIBITED:**
  - Never trust client-provided claims without cryptographically verifying the JWT signature.
- **VERIFICATION:**
  - Send request without `Authorization` header or with expired token; confirm immediate 401 HTTP response.

#### 4.2 Database Connection Hardening & Principle of Least Privilege
- **MANDATORY:**
  - Route all serverless and Edge Function database connections through connection pooling (**Supavisor**).
  - Explicitly revoke default broad privileges on schema `public` from roles `anon` and `authenticated`, granting only required operations.
- **PROHIBITED:**
  - Never grant `ALL PRIVILEGES` on schema `public` to `anon` or `authenticated`.
- **VERIFICATION:**
  - Review table and function grants in `information_schema.role_table_grants` and `information_schema.routine_privileges`.

#### 4.3 Monitoring, Telemetry & Disaster Recovery
- **MANDATORY:**
  - Enable **Point-in-Time Recovery (PITR)** on production databases.
  - Ingest security events, auth failures, and rate limit triggers into automated telemetry (`app_logs`).
  - Execute Supabase Security Advisor checks regularly across CI/CD and deployment gates.
- **PROHIBITED:**
  - Never deploy schema migrations without accompanying rollbacks and pgTAP security verification tests.
- **VERIFICATION:**
  - Perform scheduled disaster recovery drills and verify Supabase Security Advisor returns zero high/critical severity findings.

---

### Domain 5: Registration & Onboarding Security

#### 5.1 Account Enumeration Prevention
- **MANDATORY:**
  - Return standardized, generic feedback on all authentication failures (e.g., *"اطلاعات ورود نامعتبر است"* / *"Invalid credentials"*).
  - Prevent response timing or error message variations from leaking account existence.
  - Verify email ownership via confirmation links before elevating new accounts to active status.
- **PROHIBITED:**
  - Never return specific error messages such as *"کاربری با این ایمیل یافت نشد"* / *"User does not exist"*.
- **VERIFICATION:**
  - Send login requests for existing email vs non-existent email with wrong passwords; verify identical HTTP status codes and error payloads.

#### 5.2 OAuth & Third-Party Integration Security
- **MANDATORY:**
  - Disable all unused OAuth identity providers in Supabase Auth.
  - Strictly allowlist redirect URIs (`https://maxgym.privatepath.ir/auth/callback`, mobile custom scheme).
  - Enforce PKCE (Proof Key for Code Exchange) and cryptographically random `state` parameters on all authorization flows.
- **PROHIBITED:**
  - Never permit wildcard (`*`) redirect URIs in OAuth configuration.
- **VERIFICATION:**
  - Attempt OAuth callback redirect to un-allowlisted domain; verify server rejection.

#### 5.3 Magic Link Security
- **MANDATORY:**
  - Restrict magic link token validity to **maximum 1 hour**.
  - Validate redirect destinations server-side to neutralize open-redirect vulnerabilities.
- **PROHIBITED:**
  - Never generate reusable or long-lived magic link tokens.
- **VERIFICATION:**
  - Attempt login with magic link token after 61 minutes; verify token expiration.

---

## 🚨 Red Flags / Breach Indicators Checklist

If any of the following conditions are observed, immediately trigger Incident Response:
1. **Public table missing RLS:** Any table in schema `public` with `relrowsecurity = false`.
2. **Exposed Service Role Key:** Presence of `service_role` secret in client source, environment variables, or client network telemetry.
3. **Disabled Certificate Validation:** Any presence of `badCertificateCallback = (...) => true` in Dart network clients.
4. **Plaintext Credential Storage:** Any authentication tokens, hashes, or PINs stored in `shared_preferences` or unencrypted files.
5. **Wildcard Database Network Access:** Supabase port 5432 open to `0.0.0.0/0` without IP allowlisting.
6. **Search Path Hijacking Vulnerability:** Any `SECURITY DEFINER` function lacking `SET search_path = public, pg_temp`.
7. **Spike in Auth Failures:** Sustained 5x increase in 401/403 responses indicating credential stuffing or token enumeration attacks.
