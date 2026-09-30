# e-any.online altyapı envanteri

Tüm sistemler ve erişim yolları. Parolalar, token'lar ve API anahtarları burada değil, panelde **Kasa** bölümünde tutulur ve ilgili araca Kasa kaydı olarak bağlanır.

- Sunucu: Linux VM, Ubuntu, 2x NVMe
- Servisler: `/mnt/data/stacks/*` altında Docker Compose
- Reverse proxy + TLS: `core-nginx` (Nginx Proxy Manager), port 80/81/443
- Panel kataloğu: tarayıcıdan açılan arayüzler `panel/priv/repo/seeds/infrastructure_tools.exs` ile **Araçlar** listesine eklenir. Bu dosya ile katalog senkron tutulur.

## Public domainler

| Domain | Hedef container | Görev | Durum |
| --- | --- | --- | --- |
| `e-any.online` | nginx (`e-any-portal`) | Portal landing, link kartları | Canlı |
| `panel.e-any.online` | `e-any-panel` (4000) | Bookmark / araç / kasa / not (LiveView) | Canlı |
| `agentsmesh.e-any.online` | yok | Router kaydı var, container yok | Kırık |

Sadece portal kartı olan, henüz bir container'a bağlanmamış domainler:
`ai.e-any.online`, `deepseek.agentandbot.com`, `n8n.e-any.online`, `windmill.e-any.online`, `kadro.agentandbot.com`, `cv.agentandbot.com`, `agentandbot.com`, `status.e-any.online`, `9router.e-any.online`, `desktop.e-any.online`, `blog.e-any.online`, `feed.e-any.online`, `money.e-any.online`, `agent.e-any.online`, `en.e-any.online`, `agentlight.e-any.online`.

## Tailscale-only (VPN)

Adres: `100.98.86.15`. Sadece Tailscale ağındaki cihazlardan erişilir.

| Port | Container | Görev | Panelde |
| --- | --- | --- | --- |
| 5175 | `agent-zero` | Otonom AI ajan (düz metin port, arayüz değil) | Hayır |
| 8090 | `agent-zero` UI | Ajan arayüzü | Araç |
| 8081 | `admin-dozzle` | Docker log görüntüleyici | Araç |
| 6768 | `orca-ide` | Web IDE | Araç |
| 9000 | `admin-portainer` | Docker yönetimi | Araç |
| 19999 | `admin-netdata` | Sunucu izleme | Araç |
| 8089 | `condor` WebUI | Trading bot paneli | Araç |
| 8088 | `money3` (MPT) | Video üretim | Araç |

## Sunucu içi servisler (localhost / Docker ağı)

Dışarıya açık değil, panelde araç olarak listelenmez.

| Servis | Port | Görev |
| --- | --- | --- |
| `core-nginx` (NPM) | 80 / 81 / 443 | Reverse proxy + TLS |
| `hummingbot-api` | 127.0.0.1:8000 | Hummingbot API (Docker ağından) |
| `hummingbot-broker` | 127.0.0.1:1883 | MQTT broker |
| `hummingbot-postgres` | 5432 | Hummingbot DB |
| `gateway` | 127.0.0.1:15888 | DEX gateway |
| `agentbot-dev` | 4000 | AgentAndBot ana uygulama |
| `agentandbot-cv-generator` | 8080 | CV oluşturucu |
| `admin-uptime` | 3001 | Uptime izleme |
| `admin-watchtower` | 8080 | Container güncelleme |
| `money2` / `money3` (MPT) | 8083 / 8088 | Video |
| `dsh` | 5174 | Dashboard shell |
| `flujo` | 4200-4201 | Workflow |
| `mem-agentandbot` / `mem-embed` / `mem-pg` | 4100 / 4101 / 5432 | Hafıza servisi |
| `headroom` | 8787 | API gateway |
| `omniroute` | 20128 | LLM router |
| `9router` | 20128 | LLM router (alternatif) |

## Aktif AI / agent süreçleri

| Süreç | Image | Görev |
| --- | --- | --- |
| `agent-zero` | `agent0ai/agent-zero:latest` | WebUI üzerinden konuşma |
| 4x `hummingbot` | `hummingbot:2.17.0` | Trading bot (1 ETH + 3 BTC DCA) |
| `omniroute` / `9router` | custom | LLM routing |
| `condor` (tmux) | python | Trading UI süreci |
| `headroom` | `chopratejas/headroom` | API gateway |
| `flujo-flujo-1` | flujo | Workflow |

## Veritabanları (PostgreSQL)

| Container | Port | İçerik |
| --- | --- | --- |
| `core-postgres` | 5432 | `e_any_panel_prod`, `agentbot_dev`, `postgres` |
| `qm-agentandbot-pg` | 5432 | AgentAndBot production |
| `litellm-db` | - | LiteLLM |
| `mem-pg` | 5432 | Hafıza servisi |
| `hummingbot-postgres` | 5432 | Hummingbot |

## Ajan altyapısı yolları

| Yol | İçerik |
| --- | --- |
| `/home/ubuntu/.hermes/hermes-agent` | Hermes ajan reposu (Nous Research fork) |
| `/home/ubuntu/agentandbot_v2` | AgentAndBot MCP kaynağı; e-any.online portalının arkasındaki orchestrator |
| `/mnt/data/spynel/` | agent-zero bağımlılığı |

## Plan: e-any.online'a bağlanabilecekler

Uygulanmadı. Public'e açmadan önce her biri için kimlik doğrulama (NPM access list veya SSO) zorunlu.

1. Trading botlar + condor WebUI → `condor.e-any.online`
2. Portainer / Dozzle / Netdata / Uptime → `admin.e-any.online`
3. MPT video → `studio.e-any.online`
4. agent-zero UI → `agent.e-any.online` (Tailscale yerine public)
5. flujo / dsh / headroom → `flow.e-any.online`

## Açık sorular

- `agentsmesh.e-any.online`: router kaydı var, container yok. Kaldırılacak mı, bağlanacak mı?
- Port 8080: hem `agentandbot-cv-generator` hem `admin-watchtower` için yazılmış; biri container içi port olmalı.
- Port 20128: `omniroute` ve `9router` aynı port. Aynı servis mi, yoksa biri durdurulmuş mu?
- `9router.e-any.online` kartı var ama proxy'ye bağlı değil.
