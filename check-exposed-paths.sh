#!/usr/bin/env bash
# check-exposed-paths.sh — status-only check for common deploy debris on an origin YOU control.
#
#   ./check-exposed-paths.sh https://your-site.example
#
# What it does: requests a fixed list of well-known debris paths (.git/HEAD, .env, backups,
# source maps, directory listings) and reports HTTP status + content-type + a verdict.
# It peeks at the first 64 bytes IN MEMORY to tell a real file from a soft-404/SPA fallback.
# It NEVER prints, saves, or uploads response bodies. It does not crawl, brute-force, or
# follow links. Only run it against sites you own or are authorised to test.
#
# Verdicts:  LIKELY_EXPOSED  real-looking file served (signature matched)
#            CHECK_MANUALLY  200 but no signature match (could be a soft-404 or custom page)
#            SOFT_404        200 that matches the site's "not found" fallback
#            OK              404/403/410 or redirect away
#
# Exit code: 0 = nothing likely exposed, 1 = at least one LIKELY_EXPOSED, 2 = usage/network error.
#
# Free fix for one server is in deny-snippets/. The paid LeakDeny pack builds exact-path
# deny/404 rules for the paths it actually confirms on your site (htaccess/nginx, manual
# Vercel/Netlify snippets) plus verify.sh: https://leakdeny.adjudi.com/?utm_source=github&utm_medium=checker&utm_campaign=leakdeny-first-sale-w2&utm_content=check-script
# LeakDeny 404s paths. It does not rotate keys — if a secret was public, rotate it first.
set -euo pipefail
origin="${1:-}"
if [[ -z "$origin" || "$origin" != http*://* ]]; then
  echo "usage: $0 https://your-site.example" >&2; exit 2
fi
origin="${origin%/}"
UA="leakdeny-check/1.0 (+status-only; owner self-check)"

paths=(
  "/.git/HEAD" "/.git/config" "/.env" "/.env.local" "/.env.production"
  "/backup.zip" "/site.zip" "/backup.tar.gz" "/db.sql" "/dump.sql"
  "/main.js.map" "/static/js/main.js.map" "/assets/index.js.map"
  "/.DS_Store" "/wp-config.php.bak" "/config.php.bak" "/.svn/entries" "/uploads/"
)

# signature check on the first 64 bytes, never echoed
sig_ok() {
  local path="$1" head="$2"
  case "$path" in
    */.git/HEAD)   [[ "$head" == ref:* || "$head" =~ ^[0-9a-f]{40} ]] ;;
    */.git/config) [[ "$head" == *"[core]"* ]] ;;
    */.env*)       [[ "$head" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] ;;
    *.zip)         [[ "$head" == PK* ]] ;;
    *.tar.gz)      [[ "$(printf '%s' "$head" | od -An -tx1 -N2 | tr -d ' \n')" == "1f8b" ]] ;;
    *.sql)         [[ "$head" == *"CREATE"* || "$head" == *"INSERT"* || "$head" == "-- "* ]] ;;
    *.map)         [[ "$head" == *'"version"'* || "$head" == *'"mappings"'* || "$head" == '{"version'* ]] ;;
    */.DS_Store)   [[ "$head" == *Bud1* ]] ;;
    *.bak)         [[ "$head" == "<?php"* ]] ;;
    */.svn/entries) [[ "$head" =~ ^[0-9]+ ]] ;;
    */uploads/)    [[ "$head" == *"Index of"* ]] ;;
    *) return 1 ;;
  esac
}

fetch() { # prints: status<TAB>content-type<TAB>first64bytes(base64)
  local url="$1" tmp; tmp="$(mktemp)"
  local meta
  meta="$(curl -sS -m 15 -A "$UA" -o "$tmp" -r 0-63 -w '%{http_code}\t%{content_type}' "$url" 2>/dev/null || echo "000	")"
  printf '%s\t%s\n' "$meta" "$(head -c 64 "$tmp" | base64 -w0)"
  rm -f "$tmp"
}

# baseline: what does a definitely-missing path return?
rnd="/leakdeny-check-$RANDOM$RANDOM-not-here"
IFS=$'\t' read -r b_status b_type b_head <<<"$(fetch "$origin$rnd")"
[[ "$b_status" == "000" ]] && { echo "could not reach $origin" >&2; exit 2; }

found=0
printf '%-26s %-6s %-28s %s\n' PATH STATUS CONTENT-TYPE VERDICT
for p in "${paths[@]}"; do
  IFS=$'\t' read -r st ct hd <<<"$(fetch "$origin$p")"
  head_txt="$(printf '%s' "$hd" | base64 -d 2>/dev/null | tr -d '\0' || true)"
  verdict="OK"
  if [[ "$st" == 200 || "$st" == 206 ]]; then
    if sig_ok "$p" "$head_txt"; then verdict="LIKELY_EXPOSED"; found=1
    elif [[ "$b_status" == 200 || "$b_status" == 206 ]] && [[ "$hd" == "$b_head" ]]; then verdict="SOFT_404"
    else verdict="CHECK_MANUALLY"; fi
  fi
  printf '%-26s %-6s %-28s %s\n' "$p" "$st" "${ct:0:28}" "$verdict"
done
unset head_txt
echo
if [[ $found -eq 1 ]]; then
  echo "At least one path looks really exposed. Rotate any secret that was public FIRST, then deny the path."
  enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]+"/",safe=""))' "$origin" 2>/dev/null || true)
  echo "Free single-server snippet: deny-snippets/  ·  Exact-path pack + verify.sh: https://leakdeny.adjudi.com/?${enc:+url=$enc&}utm_source=github&utm_medium=checker&utm_campaign=leakdeny-first-sale-w2&utm_content=check-result"
  exit 1
fi
echo "Nothing on this short list looks exposed (this is not a full audit)."
exit 0
