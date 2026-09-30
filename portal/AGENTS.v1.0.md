# Portal

## Purpose
- Own the protected static service directory and its independent deployment.

## Ownership
- `index.html`: the single portal HTML source.
- `docker-compose.yml`, `nginx.conf`, `start.sh`: deployment and server-side access control.
- `test_portal.py`: source checks and optional Docker HTTP integration tests.
- Root `docker-compose.yml` includes this folder's Compose model.

## Local Contracts
- No client-side password verification, embedded hashes, or sessionStorage access gates.
- All HTML requests require nginx Basic authentication. The upstream proxy must serve HTTPS.
- Supply the htpasswd file outside the repo through PORTAL_HTPASSWD_FILE; never commit it.
- Keep HTML and configuration mounts read-only. Startup must not rewrite source files.
- Portal authentication protects this directory only; linked applications keep their own authentication. This is not shared Phoenix sign-in.
- Do not duplicate index.html at the repository root.

## Work Guidance
- Preserve existing service links unless the user requests a change.
- Use repository DOX and preserve versioned documentation snapshots.

## Verification
- `python portal/test_portal.py` from the repository root.
- `RUN_PORTAL_DOCKER_TESTS=1 python portal/test_portal.py` also validates Compose and nginx HTTP 401/200 behavior in a disposable container.
- Report skipped Docker tests explicitly when Docker is unavailable.

## Child DOX Index
- No child documents; all portal files are owned here.
