# Airo GitHub Wiki Source

This directory is the source of truth for Airo's public GitHub Wiki content.
It mirrors the lightweight structure used by the Google AI Edge Gallery wiki:

- `Home.md`
- `1.-Overview.md`
- `2.-Getting-Started.md`
- `3.-Navigating-Airo.md`
- `4.-Using-Core-Capabilities.md`
- `5.-AI-and-Model-Management.md`
- `6.-Privacy-and-Local-Data.md`
- `7.-Troubleshooting-and-FAQ.md`
- `8.-Feedback.md`
- `9.-Useful-Links.md`

When a PR changes a user-visible capability, supported platform, route,
download/install flow, model behavior, privacy behavior, or troubleshooting
detail, update the matching file in this directory in the same PR.

## Publishing

GitHub Wikis are stored in a separate git repository. To publish these pages,
copy or sync these Markdown files into the repository wiki:

```bash
git clone https://github.com/DevelopersCoffee/airo.wiki.git
rsync -av --delete docs/wiki/ airo.wiki/
cd airo.wiki
git add .
git commit -m "docs(wiki): update Airo user guide"
git push
```

Keep `docs/wiki` updated even when the GitHub Wiki is edited manually. The app
repository should remain reviewable as the long-term source for user-facing
capability documentation.
