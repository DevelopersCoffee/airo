# Authentication Testing Guide

This guide covers the authentication testing setup for Airo Super App E2E tests.

## Overview

The E2E tests use two authentication methods:

1. **Demo Credentials** (`demo` / `demo123`) - For automated testing
2. **Google OAuth** - Requires manual session setup due to Google's bot detection

## Quick Start

### Run Demo Login Tests

```bash
cd e2e
npm install
npm test
```

### Run Google OAuth Tests

```bash
# Step 1: Save Google session (one-time, manual)
npm run google:login

# Step 2: Complete Google login in the opened browser
# Step 3: Run tests with saved session
npm test
```

## Project Structure

```
e2e/
├── .auth/                    # Auto-generated demo auth sessions
│   └── demoAuth.json         # Created by auth.setup.ts
├── googleAuth.json           # Manually saved Google OAuth session
├── tests/
│   ├── auth.setup.ts         # Setup file - authenticates before tests
│   ├── auth.spec.ts          # Login/logout tests (no-auth project)
│   └── google-auth.spec.ts   # Google OAuth tests (requires saved session)
└── scripts/
    └── google-auth-setup.ts  # Script to save Google OAuth session
```

## Playwright Projects

| Project | Auth Required | Description |
|---------|--------------|-------------|
| `setup` | No | Runs first, authenticates with demo credentials |
| `no-auth` | No | Login page tests, validation |
| `chromium` | Yes (demo) | Main tests with demo auth |
| `firefox` | Yes (demo) | Main tests with demo auth |
| `webkit` | Yes (demo) | Main tests with demo auth |
| `google-auth` | Yes (Google) | Tests requiring Google OAuth |

## Security Best Practices

### Files to Never Commit

The following files contain sensitive OAuth tokens and are excluded via `.gitignore`:

- `e2e/googleAuth.json` - Google OAuth session cookies
- `e2e/*Auth.json` - Any auth session files
- `e2e/.auth/` - Demo auth sessions directory

### Session Security

1. **Never share** `googleAuth.json` - Contains your Google session cookies
2. **Store securely** - Keep auth files in a secure location
3. **Regenerate if compromised** - Run `npm run google:login` to create new session
4. **Use test accounts** - Consider using a dedicated test Google account

## Regenerating Sessions

### When to Regenerate

- Google session expired (typically after 30 days of inactivity)
- Account password changed
- Account signed out from all devices
- Session compromised

### How to Regenerate

```bash
cd e2e
npm run google:login
```

A browser window will open to `accounts.google.com`. Complete the login manually (you have 2 minutes).

## Test Categories

### Login Screen Tests (`@auth`)

- Login screen loads correctly
- Form fields are visible
- Sign In and Google buttons present

### Form Validation Tests (`@validation`)

- Empty form submission shows errors
- Invalid credentials show error message

### Demo Login Tests (`@demo`)

- Demo credentials button fills form
- Successful login redirects to `/agent`

### Logout Tests (`@logout`)

- Logout clears session
- Redirects to login page

### Google OAuth Tests (`@google-session`)

- Requires saved session from `npm run google:login`
- Tests OAuth popup behavior
- Verifies redirect after sign-in

## Running Specific Tests

```bash
# Run all auth tests
npx playwright test auth.spec.ts

# Run validation tests only
npx playwright test --grep @validation

# Run Google OAuth tests
npx playwright test --project=google-auth

# Run with visible browser
npx playwright test --headed

# Debug mode
npx playwright test --debug
```

## Troubleshooting

### Firebase Initialization Error

If you see:
```
PlatformException(channel-error, Unable to establish connection on channel...)
```

This is a known issue with `firebase_core` 4.x on web. Solutions:
1. Ensure Firebase JS SDK is loaded in `index.html`
2. Consider downgrading to `firebase_core: ^3.x`

### Google Bot Detection

Google blocks automated login attempts. The workaround:
1. Run `npm run google:login` to open browser
2. Complete login manually
3. Session is saved for future test runs

### Session Expired

If tests fail with "session expired":
1. Delete `googleAuth.json`
2. Run `npm run google:login`
3. Complete manual login

