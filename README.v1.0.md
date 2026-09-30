# e-any.online

e-any.online ekosisteminin kaynak kodu. Üç parça:

## portal/
`e-any.online` statik landing sayfası — tek `index.html`, nginx container'ı ile serve edilir.
Admin şifre hash'i `.env`'deki `ADMIN_HASH` ile doldurulur (placeholder `__ADMIN_HASH__`).
Canlı: https://e-any.online

## panel/
Elixir/Phoenix + LiveView panel — bookmark, şifre (Cloak AES-256-GCM), şifreli not, araç yönetimi.
Canlı: https://panel.e-any.online
**Geliştirme:** `cd panel && mix deps.get && mix test` (25 test). Deploy: `docker compose up -d --build`.

## feed/
Statik blog/RSS üretici — `generate.py` posts'ları HTML + feed.xml'e çevirir, nginx ile serve edilir.
e-any.online'ın `/feed/` alt dizini olarak yayında.

## blog/
Eski/bağımsız blog kopyası — aktif değil, yedek olarak tutulur.