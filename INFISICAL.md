# Infisical integration

## Status and boundaries

- Panel entry: Kasa > Infisical (`/admin/infisical`). Lists names, reveals one value, creates records and updates existing values in one configured project/environment/folder.
- Code is implemented; live cloud provisioning and integration verification are pending. No account, project or machine identity is created by this application.
- Existing encrypted local vault records remain intact. Nothing is automatically imported, deleted or copied to Infisical.
- Infisical holds external secrets. PostgreSQL stores only panel audit metadata: actor, operation, validated key name, timestamps and outcome. Secret names themselves should not contain credentials.
- The panel identity has shared workspace permissions. This is not per-user Infisical identity delegation or tenant isolation.
- `infisical proxy start` is a caching reverse proxy for the Infisical API. It is not a target-site credential injection gateway. A permitted API read returns a plaintext value to its caller.

## Panel setup

1. Create/select the Infisical project, environment and folder. Give a dedicated panel machine identity list/read and, if desired, create/edit permissions only there. Do not grant delete or project administration.
2. Run the official Infisical proxy against the chosen cloud region. Use a trusted TLS certificate and restrict network access to the panel and authorized agent runtimes.
3. Provision a short-lived access token for the panel identity into a protected file outside this repository. An external identity/token manager must refresh it before expiry. The panel rereads the file for each request; it does not store a client secret or renew tokens itself.
4. Set these runtime variables. All five are required; missing/invalid settings disable the adapter.

| Variable | Value |
| --- | --- |
| `EANY_INFISICAL_PROXY_URL` | HTTPS origin of the proxy, without an API path |
| `EANY_INFISICAL_PROJECT_ID` | Infisical project ID |
| `EANY_INFISICAL_ENVIRONMENT` | Environment slug |
| `EANY_INFISICAL_SECRET_PATH` | Authorized folder path, beginning with `/` |
| `EANY_INFISICAL_TOKEN_FILE` | Absolute path inside the panel runtime to the token file |

5. Mount the token directory read-only into the panel container using a deployment override stored outside Git. Mounting a directory allows atomic token-file replacement to remain visible inside the container. Keep restrictive host permissions and container user access. The base Compose file forwards configuration but intentionally contains no host secret paths or mounts.
6. Apply migrations (`mix ecto.migrate` in development; `EAnyPanel.Release.migrate/0` in a release). Restart the panel, open Kasa > Infisical and unlock using the panel password. Configuration presence alone does not mean a successful connection.

Proxy command template (variables come from deployment configuration; none are credentials):

```sh
infisical proxy start \
  --domain="$INFISICAL_CLOUD_URL" \
  --listen-address="$INFISICAL_LISTEN_ADDRESS" \
  --tls-enabled=true \
  --tls-cert-file="$INFISICAL_TLS_CERT_FILE" \
  --tls-key-file="$INFISICAL_TLS_KEY_FILE"
```

- Plain HTTP is accepted by the panel only for literal loopback addresses during local development. Container loopback refers to that same container, not the host or another service.
- Never disable TLS verification to make a proxy certificate work. Install the appropriate trusted CA in the runtime when needed.
- The referenced proxy implementation uses optimistic caching. Cached values and permissions can lag upstream changes, especially during outages. Set refresh/token-check intervals according to the deployment's revocation requirements, test revocation, and do not treat the cache as immediate revocation enforcement.

## Human access

- Existing `secrets` tab permission is required on mount and rechecked for every event and every five seconds while connected.
- Unlock is password verified, rate limited and expires after five minutes. A role/password/tab change clears the unlocked state. Values disappear after 60 seconds or manual hide/lock while connected; a disconnected browser can retain already delivered content.
- List calls request metadata only and strip unexpected response fields. No values are preloaded into the list or search.
- Viewer reads; manager/admin can explicitly create/update. Updating overwrites the named value; concurrent-edit detection and website-side password rotation are not implemented.
- Every allowed provider operation records an attempt before the request and an outcome afterwards. An audit failure blocks returning a value. An unfinished write attempt requires reconciliation; it is never retried automatically.
- No delete, bulk export, browser-stored token, public credential API or automatic local-vault migration is included.

## Agent access

- Give every agent its own Infisical machine identity and project/environment/folder grants. Separate read-only runtimes from credential-writing workflows. Do not reuse the panel identity or a human session.
- Provision each agent's access token through its trusted runtime/secret store as `INFISICAL_TOKEN`. Refresh outside model prompts. Set `INFISICAL_DOMAIN` to the proxy origin. No personal Bitwarden account is involved.
- Use the native CLI to inject values into an approved process, without printing a secrets list into the model's transcript:

```sh
infisical run --projectId="$INFISICAL_PROJECT_ID" \
  --env="$INFISICAL_ENVIRONMENT" --path="$INFISICAL_SECRET_PATH" \
  -- /path/to/approved-tool
```

- The process can read injected environment variables. This is not protection against a compromised process; avoid passing arbitrary model-written programs to a privileged runtime.
- Authorized create/update workflows can use the official v4 API with their own identity. Project/folder/action restrictions must be enforced in Infisical, not trusted to model arguments. Return status to the model; redact payloads, tokens and sensitive tool output.
- Agent operations are audited by Infisical; the local `infisical_audits` table covers panel operations only. No e-any agent API is exposed by this change.

## Verification

```sh
mix test test/e_any_panel/infisical_test.exs test/e_any_panel_web/infisical_live_test.exs
mix precommit
```

- Tests use fake transport/tokens and a disposable PostgreSQL database, never a cloud secret store.
- Windows requires the native build tools needed by the existing Argon2 dependency, including `nmake`. Without these, full application tests and `mix precommit` cannot run; source compilation with dependency checks disabled is not a substitute.
- Before production activation, verify list/read/create/update in a disposable folder, denied cross-folder access, read-only identities, token expiry/rotation, revocation/cache behavior and audit persistence. Check the API behind the selected proxy version supports v4.

## Sources

- [CLI proxy implementation](https://github.com/Infisical/cli/blob/5f130f1d4da2d21b91d2fbfc273f0835dd417d75/packages/cmd/proxy.go), inspected at commit `5f130f1d4da2d21b91d2fbfc273f0835dd417d75`.
- [List secrets](https://infisical.com/docs/api-reference/endpoints/secrets/list), [read secret](https://infisical.com/docs/api-reference/endpoints/secrets/read), [create secret](https://infisical.com/docs/api-reference/endpoints/secrets/create), [update secret](https://infisical.com/docs/api-reference/endpoints/secrets/update).
- The requested CLI reference URL was inaccessible to the research client; proxy behavior was checked against the official CLI source instead.
