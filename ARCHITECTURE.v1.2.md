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
- Start screen provides direct entry cards; Ctrl/Cmd+K focuses metadata search.
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
