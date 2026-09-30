# Portal deployment

The root deployment entry point and startup validation adapt the useful deployment changes reviewed at upstream commit `c5e127021a6ffb2f4a0ae6684f9ceca90a3f0a93`. This is a selective adaptation, not a merge of upstream history. The duplicate root HTML, embedded password verifier and committed `.env` were not imported.

## Requirements

- Docker and Docker Compose 2.20.3 or newer for the root `include` entry point. [Docker include documentation](https://docs.docker.com/compose/how-tos/multiple-compose-files/include/).
- Existing external Docker network `proxy-network` and an HTTPS reverse proxy forwarding to `e-any-portal:80`.
- A non-empty htpasswd file outside this repository. Provision it using `htpasswd` with a supported hash such as Apache MD5 (`htpasswd -m -c /secure/path/portal.htpasswd USERNAME` prompts for a password; omit `-c` when updating an existing file).

The previously committed portal verifier is public. Use a new password for this deployment. Removing the verifier in a later commit does not remove it from Git history.

## Start

Set `PORTAL_HTPASSWD_FILE` to the absolute path of the provisioned file. Example in PowerShell:

```powershell
$env:PORTAL_HTPASSWD_FILE = 'C:\secure\portal.htpasswd'
docker compose config --quiet
docker compose up -d
```

Run from the repository root to use its entry point, or use `docker compose -f portal/docker-compose.yml` directly. The included Compose model resolves HTML/config paths relative to `portal/`.

The variable is a file path, not a password. Compose mounts the file as `/run/secrets/portal_htpasswd`. Startup rejects a missing or empty file. Mounts do not modify the original HTML, so source changes and credential rotation do not depend on placeholder replacement. After replacing the credential file, recreate the portal container to remount it.

Nginx authenticates requests before returning the directory. The browser shows its native HTTP authentication prompt. Portal credentials are separate from Phoenix panel accounts; linked services still require their own permissions. There is no custom logout flow or single sign-on in this static directory.

## Verification

```powershell
python portal/test_portal.py
$env:RUN_PORTAL_DOCKER_TESTS = '1'
python portal/test_portal.py
```

The integration checks use a temporary container and disposable credentials. They verify both Compose entry points, unauthenticated/incorrect-password rejection, authorized HTML retrieval, cache headers, and preservation of the source file. They do not deploy or contact the live site.
