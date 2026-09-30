#!/bin/sh
set -eu

# Fail closed before starting nginx. Never modify the bind-mounted HTML.
auth_file=/run/secrets/portal_htpasswd
if [ ! -r "$auth_file" ] || [ ! -s "$auth_file" ]; then
  echo "Portal requires a readable, non-empty htpasswd secret." >&2
  exit 1
fi

exec /docker-entrypoint.sh "$@"
