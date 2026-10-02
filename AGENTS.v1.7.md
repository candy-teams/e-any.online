# DOX framework

- DOX is a highly performant AGENTS.md hierarchy installed here.
- Agents must follow DOX instructions across all edits.

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees.
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md and every parent above it.

## Read Before Editing

1. Read the workspace and repository root AGENTS.md files.
2. Identify every target file and folder.
3. Walk from the repository root to each target; read every applicable AGENTS.md.
4. Follow indexed child documents whose scope contains the target.
5. Use the nearest document for local contracts and parents for shared rules.
6. Closer documents control local details; children may not weaken DOX.

- Re-read the applicable chain in the current session; do not rely on memory.
- User-authorized exception: development in this repository does not depend on the unavailable ENTERPRISE-ENGINEERING-PRINCIPLES.md file.

## Update After Editing

- Every meaningful change requires a DOX pass.
- Update the nearest owner for changes to scope, responsibilities, structure, contracts, workflows, inputs, outputs, permissions, constraints, side effects, artifacts, or durable user preferences.
- Update parents and children when ownership, inherited rules, or child indexes change.
- Remove stale or contradictory instructions. Small edits without contract changes may leave docs unchanged after review.

## Hierarchy

- Root owns project-wide instructions, product scope, preferences, and the top-level Child DOX Index.
- Children own domain-specific contracts and their own child indexes.
- Parents explain direct child scopes and retained ownership.

## Child Doc Shape

- Create a child at a durable boundary with its own purpose, rules, workflow, or quality standards.
- Default sections: Purpose, Ownership, Local Contracts, Work Guidance, Verification, Child DOX Index.
- Work Guidance reflects established standards; leave empty when none exist.
- Verification names existing checks; leave empty when none exist.

## Style

- Keep instructions concise, current, operational, and in direct bullets.
- Keep broad rules in parents and concrete details in children.
- Avoid duplicated rules, diary entries, and stale warnings.

## Closeout

1. Re-check changed paths against the DOX chain.
2. Update nearest owners and affected parents or children.
3. Refresh affected Child DOX Index entries.
4. Remove stale or contradictory text.
5. Run relevant existing verification.
6. Explain documents intentionally left unchanged.

## Candy Contracts

- Repository: https://github.com/candy-teams/e-any.online.git. Keep origin pointed here. Curated third-party source repositories remain pinned to their upstream.
- Never commit secrets, tokens, or raw credentials. Use environment variables or secret stores; never put them in AGENTS.md or source.
- Prefer platform, standard library, and existing dependencies. Choose the smallest working change.
- Leave a runnable check for non-trivial logic; use the existing test framework.
- Infrastructure inventory (hosts, Tailscale/internal addresses, ports, containers, databases, server paths) lives only in the panel database: an encrypted note and tool records. Never commit it to this repository. Credentials go into Kasa and are linked to the tool.

## User Preferences

- Keep e-any.online simple to use across mobile, PC, browsers, and eventually authorized AI agents.
- Follow the user's Bauhaus principle: every interface element must support a task, orientation, readability, accessibility or state. Remove decoration without a purpose; no Phoenix starter branding, ornamental gradients, floating cards or repeated promotional headings. Notion/Rainbow are inspiration only.
- Prioritize fast capture, search, readable content and mobile touch targets; keep infrastructure management secondary.
- Markdown is for note-taking. Current notes remain encrypted in storage with explicit .md import/export; rich editing and offline file synchronization are future capabilities.
- Every internal tool must remain extractable into an independently branded product. Keep domain storage and logic behind contexts; tools must not query each other's tables. Shared portal identity and secrets are platform integrations, not tool-owned business logic.
- A future separate browser extension will support offline Markdown editing, bookmark capture, and social sharing through versioned APIs. Do not imply these features exist before implementation and verification.
- Preserve the Elixir/Phoenix foundation and improve the existing portal.
- Product scope: daily activity management, bookmarks, encrypted notes and credentials, a private content feed, and company/hobby tools.
- e-any should also be the user's daily activity system. Plan a Today-centered home; daily planning, tasks and journal features are not implemented yet.
- Plan synchronization with both Google Workspace/Drive and Microsoft 365/OneDrive through separable provider integrations. This is not implemented or connected.
- Daily activity planning includes project/consultant work logs, hours and invoice tracking; rate units and billing rules remain unspecified. Keep private customer/rate values out of source and documentation.
- Tools include Activepieces and Windmill; register their actual URLs and link credentials from the vault rather than duplicating passwords.
- The private feed includes writing, news, blogs, video/music links, and saved bookmarks. First identity tag is the content owner; later identities are publishers. Keep topic tags separate.
- Planned publishing targets only selected sites/accounts. Agent APIs and automated publishing remain future work until implemented and tested.

## Child DOX Index

- [panel/AGENTS.md](panel/AGENTS.md): Phoenix application, authentication, encrypted records, tools, tests, and panel assets.
- [portal/AGENTS.md](portal/AGENTS.md): static service directory, independent Compose deployment, server-side portal authentication and checks.
- Root-owned: README.md, ARCHITECTURE.md, versioned documentation snapshots, .gitignore and the Compose include entry point; feed/ public static feed generator; blog/ inactive legacy copy. The static feed is distinct from the authenticated private feed.

- Versioned `*.v1.*.md` files are historical snapshots, not active DOX contracts. Preserve them when revising canonical documents.
