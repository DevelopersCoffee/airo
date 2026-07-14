# Security Policy

Security reports need a private path. Please do not open a public GitHub issue
for vulnerabilities, exposed secrets, auth bypasses, signing problems, or
privacy-impacting bugs.

## What To Report Privately

- Credential, token, keystore, certificate, or signing leaks.
- Authentication or authorization bypasses.
- Remote code execution, injection, deserialization, or supply-chain issues.
- Local data exposure, privacy leaks, unsafe logging, or missing redaction.
- Unsafe model, tool, plugin, file, network, or background automation behavior.
- Vulnerabilities in release, CI, or artifact publishing workflows.

## How To Report

Use GitHub's private vulnerability reporting if it is enabled for this repository.
If it is not enabled, open a minimal public issue asking maintainers to enable a
private security contact path, but do not include exploit details.

Include:

- Affected commit, release, package, or platform.
- Steps to reproduce.
- Impact and likely severity.
- Whether the issue is already public.
- Any safe workaround you know.

## Handling Expectations

Maintainers should:

- Acknowledge valid reports as soon as practical.
- Avoid asking reporters to disclose sensitive details publicly.
- Coordinate fixes before public disclosure when possible.
- Credit reporters when they want credit and it is safe to do so.

## Supported Versions

| Release line | Status | Notes |
| --- | --- | --- |
| Airo TV v0.0.x | Supported | Security fixes target the latest Airo TV release from `v2`. |
| `main` | Supported | Security fixes also target the latest development branch. |
| Older releases | Best effort | Upgrade to the latest release before reporting issues that are already fixed. |

## Contributor Hygiene

Before opening a PR, confirm the diff does not include:

- `app/android/key.properties`
- keystore files
- private certificates
- API keys or access tokens
- production logs
- personal user data
- unredacted model, tool, or network traces
