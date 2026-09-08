# Airo GitHub issue proxy

Cloudflare Worker that lets the in-app bug reporter file a GitHub issue on
`DevelopersCoffee/airo` without ever putting a GitHub token in the app, and
without requiring the reporting user to have a GitHub account.

Contract this Worker implements — must stay in sync with
`packages/core_data/lib/src/bug_report/github_issue_service.dart`:

```
POST /                    header: X-API-Key: <PROXY_API_KEY>
body:  {"title": "...", "body": "...", "labels": ["..."]}
reply: {"number": 123, "html_url": "https://github.com/...", "title": "..."}
```

## Deploy

```bash
cd infra/cloudflare/github-issue-proxy
npm install
npx wrangler login
```

Create a GitHub Personal Access Token scoped to only this repo, with only
the **Issues: write** permission (fine-grained token) — nothing broader.
Never paste this token into chat; set it directly as a Worker secret:

```bash
npx wrangler secret put GITHUB_TOKEN
```

Generate a random proxy key and set it too:

```bash
openssl rand -hex 32
npx wrangler secret put PROXY_API_KEY
```

Then deploy:

```bash
npx wrangler deploy
```

Wrangler prints the deployed URL (`https://airo-github-issue-proxy.<your-subdomain>.workers.dev`).

## Wire it into the app

Give the deployed URL and the `PROXY_API_KEY` value to whoever cuts the
release build — they go in as build-time `--dart-define`s, never committed:

```
--dart-define=GITHUB_ISSUE_OWNER=DevelopersCoffee
--dart-define=GITHUB_ISSUE_REPO=airo
--dart-define=GITHUB_ISSUE_PROXY_URL=<the deployed Worker URL>
--dart-define=GITHUB_ISSUE_PROXY_API_KEY=<the PROXY_API_KEY value>
```

For the Aika Stream (TV) CI release, these come from GitHub Actions
repository secrets `AIRO_ISSUE_PROXY_URL` and `AIRO_ISSUE_PROXY_API_KEY`
(GitHub forbids secret names starting with `GITHUB_`). The workflow maps
them onto the Flutter `--dart-define`s `GITHUB_ISSUE_PROXY_URL` /
`GITHUB_ISSUE_PROXY_API_KEY`. Add both secrets once this Worker is deployed.

## Local testing

```bash
npm run dev
curl -X POST http://localhost:8787 \
  -H "X-API-Key: <PROXY_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test issue","body":"Test body","labels":["bug"]}'
```

## Notes

- `PROXY_API_KEY` gates casual abuse, not a real secret boundary — the app
  ships it compiled in, and a decompiled APK can recover it. `GITHUB_TOKEN`
  is the actual secret, and it never leaves this Worker.
- No rate limiting beyond GitHub's own API limits. If abuse becomes a
  problem, add a Cloudflare KV or Durable Object counter here.
