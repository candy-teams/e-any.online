# Repository selection

## Sources inspected

- [e-any-panel](https://github.com/ilkerkaanipcioglu/e-any-panel/tree/9a9792ff208fe75780d1672bfc28893121df957b): standalone Phoenix panel, default branch at `9a9792ff208fe75780d1672bfc28893121df957b`.
- [e-any.online](https://github.com/candy-teams/e-any.online/tree/ba4f4be): umbrella repository, remote default branch at `ba4f4be`, plus existing local changes.
- Read-only file comparison normalized line endings. This is a source review, not a successful deployment or runtime security audit.

## Selection

| Area | Decision | Evidence |
| --- | --- | --- |
| Product home | Continue in `candy-teams/e-any.online` | Portal, panel and static feed deployment boundaries already coexist here. |
| Nginx Proxy Manager tools | Keep the existing panel implementation | Standalone client's code is already present in the umbrella; copying it adds no capability. |
| Runtime and build | Keep Phoenix, LiveView, Finch and current container build | `mix.exs` and Dockerfile match the standalone baseline; no new framework is needed. |
| Vault and authorization | Keep umbrella improvements | Umbrella starts the Cloak vault and adds roles/tab permissions missing from the standalone user schema. |
| Notes | Keep `EAnyPanel.Notebook` | The standalone `Panel.Note` schema is an earlier copy of storage now owned by Notebook; do not create two owners for the same table. |
| Private feed | Keep the authenticated private-feed context | The standalone controller reads a different legacy feed, includes unchecked integer parsing, and is not routed into the private workspace. It is not a replacement for the private feed. |
| UI | Keep Bauhaus-oriented workspace | Umbrella has the current functional navigation, protected records and capture flows. Do not restore starter presentation. |
| External credentials | Add Infisical as a separate integration | Neither compared upstream baseline supplies this adapter. Keep provider concerns separate from Notebook/feed/tool business data. |
| Deployment | Preserve current deployment files and review before publishing | New umbrella auto-deploy script exists; remote publication must not be confused with a harmless source-only action. |

The useful standalone foundation is already incorporated. No unique standalone feature justified copying older modules back. Keep the standalone repository unchanged; future extraction should use the current contexts and explicit APIs, not maintain two diverging panels.

## Dependency selection

- Keep Finch as the HTTP integration client. Update its existing Mint dependency from 1.9.3 to 1.11.0, with HPAX 1.1.0, to address advisories reported by Hex while preparing verification.
- Update the existing test-only LazyHTML dependency from 0.1.12 to 0.1.13 for its reported security fix. No dependency or HTTP client is added.
