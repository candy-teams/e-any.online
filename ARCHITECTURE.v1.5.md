# e-any product boundaries

e-any is a shared workspace and application directory for personal, company, and hobby work. Internal tools should be able to become separate products. Today the built-in features share a Phoenix application and PostgreSQL database; they are not independently deployable applications yet.

## Current boundaries

| Boundary | Owns | Integration |
| --- | --- | --- |
| Portal shell | Navigation, session authentication, role checks, search orchestration | LiveView calls domain contexts; UI does not query tables |
| Accounts | Users, roles, tab permissions | Shared identity; viewer reads, manager edits permitted sections, admin manages |
| Catalog / vault | Tool URLs, tool metadata, bookmarks, encrypted credentials, access logs | Optional credential reference on a tool; no tool deployment or workflow execution |
| Notebook | Markdown text and encrypted note storage | `EAnyPanel.Notebook`; explicit UTF-8 .md import/export, 100 KB import limit |
| Private feed | Entries, owner identity, ordered publisher labels, topic tags | `EAnyPanel.PrivateFeed`; 30 entries per page; no automatic external publishing |
| External tools | Their own business data, workflows and execution | Activepieces/Windmill are URL registrations; deployment remains separate |

- Notebook keeps the existing `notes` table and Cloak encryption. Panel note functions delegate for compatibility; new callers use Notebook.
- Private feed uses `private_feed_entries`. It does not reuse the public legacy `posts` table or static `feed/` generator.
- Owner/publisher labels describe content attribution and distribution intent. They are not account ownership or tenant authorization.
- Current data is shared within one workspace by granted sections. Per-record permissions, tenant isolation, public registration, billing and independent releases are not implemented.
- Only the portal integrates the catalog with credential storage. Internal tool business logic must not depend on vault tables or portal sessions.

## Interaction design

- Everyday navigation: Akış, Bookmarklar, Kasa, Araçlar and Notlar; infrastructure screens live under Yönetim.
- Start screen provides compact directory rows; Ctrl/Cmd+K focuses metadata search.
- Bauhaus principle: layout, typography and controls serve tasks. Neutral surfaces, blue actions/selection, explicit status text, simple borders and visible focus replace starter branding, decorative gradients, hover movement and promotional cards.
- Validate on change, persist on explicit submit. Bookmark-to-feed opens a draft editor instead of publishing immediately.
- Tool templates never guess deployment URLs or credentials.
- Notes and credentials load content only after re-authentication and an explicit read/edit/export action. Lists and search use metadata.
- Vault access expires after five minutes, with a manual lock. Read/copy/export actions write access logs without contents. Markdown download is deliberately an unencrypted file chosen by the user.
- Raw Markdown is shown as escaped text; a rich editor/preview is not included yet.

## Extraction path

1. Keep each tool's schema and storage operations within its own context; avoid cross-domain joins and private function calls.
2. When exposing a tool to another client, define a versioned API with explicit identity, permissions and stable record IDs. The portal becomes another client of that API.
3. Replace shared identity and secret dependencies through explicit integrations before splitting deployment. Provide a documented export/import path for that tool's data.
4. Introduce tenant isolation and record-level authorization before offering a public multi-customer product.

## Planned browser extension and publishing

- Build the extension separately from the Phoenix UI. Use the same future API as authorized agents.
- Offline notes require local persistent storage, stable IDs, revisions, a retryable sync queue and explicit conflict handling. None is currently implemented.
- Social sharing requires connected accounts, scoped credentials, per-channel delivery status and duplicate prevention. Publisher labels alone do not trigger sharing.
- Activepieces/Windmill can execute publishing workflows after integration; e-any should record the result rather than imply delivery from a successful local save.


## Planned daily workspace

- Confirmed product scope: e-any is also the user's daily activity management system. This section describes planned behavior, not implemented features.
- Proposed home: Bugün (Today), with chosen priorities, today's tasks, quick capture and a daily Markdown note.
- Capture ideas, links and tasks into an inbox without requiring categorization. Link a task to an existing note, bookmark or tool instead of copying its content.
- Keep private daily activity (completed tasks and explicitly recorded work) separate from the content feed. Turning an activity or note into a feed post is explicit; external publishing is never an automatic consequence of recording daily work.
- Start with capture, completion, rescheduling and daily notes. Calendar synchronization, recurring routines and reminders are later integrations, not active automations.
- Daily activities should own their state in a separate domain context. Portal composition uses other tools' public interfaces; daily records must not embed credentials or decrypted note bodies.

## Planned cloud synchronization

- Support both Google Workspace/Drive and Microsoft 365/OneDrive through separate provider adapters. No cloud accounts or live synchronization are connected yet.
- Proposed activity model: stable work-log IDs, date, project, consultant, hours, work description and invoice state. Maintain rates separately; unit, currency and billing rules must be specified before calculating amounts.
- Prefer e-any as the activity source with explicit Excel/Sheets imports and report exports first. Bidirectional spreadsheet editing requires declared column mappings, stable row IDs and revision checks.
- Select folders and synchronization direction per connection; identify files by provider IDs, not paths. Track revisions and retries, prevent duplicate writes and expose conflicts instead of silently overwriting.
- Keep native Docs/Word/Sheets/Excel linked in their provider. Do not promise lossless cross-provider conversion or mirror all files automatically.
- Markdown synchronization is a later explicit per-folder option with an offline queue and conflict resolution. Existing encrypted notes must not silently become plaintext cloud files; vault secrets never sync as plaintext.
- Cloud file changes are signals to reconcile content, not row-level change events. Each record needs a declared source of truth when several clients can edit it.

## Approved Bitwarden direction (not connected)

- Keep the existing personal Bitwarden account separate. A new bot-only account on official Bitwarden Cloud will own or access selected automation credentials. Signup email and cloud region must come from the user; the user enters the master password directly in Bitwarden.
- e-any acts as an access directory and policy gateway. Persist provider/region/item references, never a second copy of external passwords. Existing local vault records remain unchanged until migration is separately verified; encrypted Notebook storage remains independent.
- Authenticate each agent at the gateway; derive its identity from authentication, not request-supplied labels. Default deny; grant reads and writes separately for explicit records or collections. A shared bot account alone does not isolate agents from one another.
- Use a dedicated CLI profile for the bot account. API-key login does not unlock a password vault; unlocking belongs to a trusted runtime outside the model. Never expose an unlocked CLI HTTP service to the public internet or untrusted local processes.
- Read/create/update operations must enforce scope before access and check organization/collection ownership. Creation fixes the authorized destination; updates must not move records or silently overwrite concurrent changes. Do not automatically retry ambiguous writes.
- Send a password only to an authorized execution component for the intended target; return operation status to the model. Redact secret values from request/response logs, telemetry, exceptions and audit records. Record actor, operation, item reference, time and outcome only.
- A vault-record update does not rotate the password at the target website. Website rotation is a separate workflow requiring a successful target-side change and subsequent vault update.
- Bitwarden Secrets Manager is a separate future option for machine API keys, not interchangeable with Password Manager accounts or collections.
- No account has been created, no credentials have been requested or transferred, and no agent endpoint or Bitwarden adapter is implemented yet. Connection work awaits signup details and trusted runtime provisioning.

References: [Password Manager CLI](https://bitwarden.com/help/cli/), [Password Manager APIs](https://bitwarden.com/help/bitwarden-apis/), [Secrets Manager machine accounts](https://bitwarden.com/help/machine-accounts/).
