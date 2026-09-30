# Domain contracts

## Purpose
- Own domain logic and storage behind Elixir contexts; keep future product extraction practical.

## Ownership
- `accounts.ex`, `accounts/`: shared identities and roles.
- `panel.ex`, `panel/`: catalog, bookmarks, credential storage and access logs; note delegates are compatibility APIs.
- `notebook.ex`, `notebook/`: encrypted Markdown notes.
- `private_feed.ex`, `private_feed/`: authenticated workspace feed, distinct from public static content.
- Root-owned here: application supervision, repository, vault and external NPM client.

## Local Contracts
- Domain contexts must not query another tool's tables. Portal-level orchestration may call public context APIs.
- Notebook owns note queries, including metadata search. Preserve the existing encrypted database format.
- Feed owner is separate from ordered publisher labels; topic labels are separate. Saving never sends network requests or publishes externally.
- Metadata queries exclude encrypted contents. Sensitive reads require portal authorization and auditing; these contexts are not public unauthenticated APIs.
- Tool credential foreign keys become null on credential deletion; deleting a tool does not delete its credential.
- Workspace tab access is not tenant or per-record isolation. Do not describe it as multi-tenant authorization.

## Work Guidance
- Use Ecto changesets for validation and migrations for schema changes.
- Prefer existing dependencies. Do not introduce cross-tool coupling for convenience.

## Verification
- `mix test test/e_any_panel/workspace_test.exs`
- `mix precommit` from `panel/` before completion when the runtime is available.

## Child DOX Index
- No further child contracts; this file owns all files and folders in this domain directory.
