# Browser-facing services from INFRASTRUCTURE.md, registered as panel tools.
# Data only: no passwords or tokens. Link credentials from Kasa in the panel.
# Keep in sync with the "Panelde: Araç" rows in ../../../../INFRASTRUCTURE.md.
[
  %{name: "e-any portal", url: "https://e-any.online", category: "e-any",
    description: "Portal landing, link kartları"},
  %{name: "e-any panel", url: "https://panel.e-any.online", category: "e-any",
    description: "Bookmark, araç, kasa ve not çalışma alanı"},
  %{name: "Agent Zero", url: "http://100.98.86.15:8090", category: "AI ajan",
    description: "Otonom AI ajan arayüzü. Tailscale gerekli."},
  %{name: "Dozzle", url: "http://100.98.86.15:8081", category: "Yönetim",
    description: "Docker log görüntüleyici. Tailscale gerekli."},
  %{name: "Portainer", url: "http://100.98.86.15:9000", category: "Yönetim",
    description: "Docker container yönetimi. Tailscale gerekli."},
  %{name: "Netdata", url: "http://100.98.86.15:19999", category: "Yönetim",
    description: "Sunucu izleme. Tailscale gerekli."},
  %{name: "Orca IDE", url: "http://100.98.86.15:6768", category: "Geliştirme",
    description: "Web tabanlı IDE. Tailscale gerekli."},
  %{name: "Condor", url: "http://100.98.86.15:8089", category: "Trading",
    description: "Hummingbot trading bot paneli. Tailscale gerekli."},
  %{name: "MPT Studio", url: "http://100.98.86.15:8088", category: "Medya",
    description: "money3 (MPT) video üretim. Tailscale gerekli."}
]
