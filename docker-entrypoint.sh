#!/bin/sh
# index.html içindeki __ADMIN_HASH__ placeholder'ını env'den doldur
# Not: sed -i bind-mount'ta rename edemez (Resource busy) -> cp ile yerinde yaz
if [ -n "$ADMIN_HASH" ] && [ -f /usr/share/nginx/html/index.html ]; then
  sed "s/__ADMIN_HASH__/$ADMIN_HASH/g" /usr/share/nginx/html/index.html > /tmp/index.html.tmp
  cat /tmp/index.html.tmp > /usr/share/nginx/html/index.html
  rm -f /tmp/index.html.tmp
fi
exit 0