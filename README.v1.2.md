# e-any.online

Repository: [candy-teams/e-any.online](https://github.com/candy-teams/e-any.online)

e-any.online ekosisteminin kaynak kodu. Dört kaynak bölümü:

## portal/
`e-any.online` statik araç dizini; tek kaynak `portal/index.html`. Repo kökündeki Compose dosyası portalın bağımsız Compose modelini içerir.
Nginx, repo dışında tutulan htpasswd dosyasıyla erişimi denetler. `PORTAL_HTPASSWD_FILE` zorunludur; kaynak HTML değiştirilmez. Kurulum ve testler: [portal/README.md](portal/README.md).
Canlı: https://e-any.online

## panel/
Elixir/Phoenix + LiveView panel - bookmark, şifre (Cloak AES-256-GCM), şifreli not, araç yönetimi.
Canlı: https://panel.e-any.online
**Geliştirme:** `cd panel && mix deps.get && mix precommit`. PostgreSQL bağlantısı için `DB_HOSTNAME`, `DB_PORT`, `DB_PASSWORD`; şifreleme için base64 kodlu 32 baytlık `CLOAK_KEY` gerekir. Testlerde yalnızca geçici veritabanı ve test anahtarı kullanın.

Yeni sürüm kaynakta şu yetenekleri içerir:
- Günlük kullanım odaklı ana ekran, ikincil yönetim menüsü ve Ctrl/Cmd+K araması.
- Araç açıklaması, şirket/proje etiketi, kasa kaydı bağlantısı; Activepieces ve Windmill kayıt şablonları.
- Sunucu tarafı işlem yetkileri, beş dakikalık kasa kilidi, içerik yerine metadata araması ve erişim kaydı.
- Şifreli Markdown notları, kaynak düzenleyici, .md içe/dışa aktarımı.
- Kapalı akış, ayrı sahip/yayıncı/konu etiketleri, bookmarktan gönderi oluşturma ve sayfalama.

Önce `mix ecto.migrate` ile yeni araç bağlantısı ve private feed migration'larını uygulayın. Canlıya geçmeden `mix precommit` ve tarayıcı doğrulaması gereklidir. Deploy komutu: `docker compose up -d --build`.

Sosyal medya yayını, Activepieces/Windmill çalıştırma, agent API'si, browser eklentisi ve offline eşitleme henüz yoktur. Notlar veritabanında şifreli saklanır; indirilen .md dosyası düz metindir. Her aracın ayrılabilir ürün sınırları [ARCHITECTURE.md](ARCHITECTURE.md) içinde tanımlanır.

## feed/
Statik blog/RSS üretici - `generate.py` posts'ları HTML + feed.xml'e çevirir, nginx ile serve edilir.
e-any.online'ın `/feed/` alt dizini olarak yayında.

## blog/
Eski/bağımsız blog kopyası - aktif değil, yedek olarak tutulur.