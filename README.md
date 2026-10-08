# leakdeny-check — is your deploy serving `.env`, backups or source maps?

A ~100-line bash script that checks **your own site** for common deploy debris and reports **HTTP status only**.

```bash
curl -fsSLO https://raw.githubusercontent.com/dimonch-byte/leakdeny-check/main/check-exposed-paths.sh
bash check-exposed-paths.sh https://your-site.example
```

```
PATH                       STATUS CONTENT-TYPE                 VERDICT
/.env                      200    application/octet-stream     LIKELY_EXPOSED
/backup.zip                200    application/zip              LIKELY_EXPOSED
/main.js.map               200    application/octet-stream     LIKELY_EXPOSED
/.git/HEAD                 404    text/html                    OK
```
*(output from a throwaway test site that serves fake files on purpose)*

## What it does / doesn't do
- Requests a **fixed list** of ~18 well-known paths (`/.git/HEAD`, `/.env*`, `backup.zip`, `*.sql`, `*.js.map`, `.DS_Store`, `*.bak`, `/uploads/` directory index).
- Looks at the first 64 bytes **in memory** to tell a real file apart from a soft-404 or SPA fallback. **It never prints, saves or uploads response bodies.**
- No crawling, no brute force, no third-party calls. **Only run it on sites you own or are authorised to test.**
- `CHECK_MANUALLY` means "200 but doesn't look like the real file" — often a custom 404 page. Open it yourself.
- This is a short list, not a security audit.

## If something is exposed
1. **Rotate any secret that was public first.** Denying the path later doesn't un-leak it.
2. Deny the path. Free starter snippets for one server are in [`deny-snippets/`](deny-snippets/) (nginx, Apache/.htaccess).
3. Re-run the script; expect `OK`.

## Disclosure: I also sell a paid version of step 2
[LeakDeny](https://leakdeny.adjudi.com/?utm_source=github&utm_medium=readme&utm_campaign=leakdeny-first-sale-w2&utm_content=readme) ($29 one-time, 14-day refund) runs a redacted check on your live URL and builds **exact-path** deny/404 rules for only the paths it confirms: an htaccess or nginx marked block, manual Vercel/Netlify snippets, ROLLBACK notes, and a status-only `verify.sh`.
It **404s paths. It does not rotate keys**, never edits your site, and never ships secret contents. If the free snippet above is enough for you, use that.

MIT licence. Operated by 9213651 Canada Inc. · idealstoronto@gmail.com
