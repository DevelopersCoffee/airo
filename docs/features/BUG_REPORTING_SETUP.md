# Bug Reporting Feature Setup

This document explains how to configure the cross-platform bug reporting feature that allows users to submit bug reports directly to GitHub Issues.

## Overview

The bug reporting feature enables users to:
- Report bugs from any platform (Android, iOS, Web, Windows, macOS, Linux)
- Automatically include device information and app logs
- Submit reports as GitHub Issues with proper labels and formatting

## Prerequisites

1. **GitHub Repository**: Issues will be submitted to `DevelopersCoffee/airo_super_app`
2. **GitHub Bot Account** (recommended) or Personal Account
3. **Personal Access Token** with `issues:write` permission

## Step 1: Create a GitHub Bot Account (Recommended)

For security, create a dedicated bot account:

1. Create a new GitHub account (e.g., `airo-bot`)
2. Add the bot as a collaborator to `DevelopersCoffee/airo_super_app` with write access
3. This isolates your personal account from automated submissions

## Step 2: Generate a Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Configure the token:
   - **Token name**: `airo-bug-reporter`
   - **Expiration**: Set an appropriate expiration (recommend 1 year max)
   - **Repository access**: Select "Only select repositories" → `DevelopersCoffee/airo_super_app`
   - **Permissions**:
     - Repository permissions → Issues → Read and write
4. Click "Generate token" and **copy the token immediately** (you won't see it again)

## Step 3: Configure the Token

### Option A: Development (Local Testing)

Pass the token via `--dart-define` when running the app:

```bash
# Run on Android
flutter run --dart-define=GITHUB_ISSUE_TOKEN=ghp_xxxxx

# Run on iOS
flutter run -d ios --dart-define=GITHUB_ISSUE_TOKEN=ghp_xxxxx

# Run on Web
flutter run -d chrome --dart-define=GITHUB_ISSUE_TOKEN=ghp_xxxxx

# Run on Desktop
flutter run -d windows --dart-define=GITHUB_ISSUE_TOKEN=ghp_xxxxx
```

### Option B: Production (CI/CD)

Add the token as a secret in your CI/CD environment:

**GitHub Actions:**
1. Go to repository Settings → Secrets and variables → Actions
2. Add a new secret: `GITHUB_ISSUE_TOKEN`
3. Update your workflow to pass it during build:

```yaml
- name: Build APK
  run: flutter build apk --release --dart-define=GITHUB_ISSUE_TOKEN=${{ secrets.GITHUB_ISSUE_TOKEN }}

- name: Build iOS
  run: flutter build ios --release --dart-define=GITHUB_ISSUE_TOKEN=${{ secrets.GITHUB_ISSUE_TOKEN }}

- name: Build Web
  run: flutter build web --release --dart-define=GITHUB_ISSUE_TOKEN=${{ secrets.GITHUB_ISSUE_TOKEN }}
```

## Step 4: Customize Repository (Optional)

To submit issues to a different repository, modify the environment variables:

```bash
flutter run \
  --dart-define=GITHUB_ISSUE_TOKEN=ghp_xxxxx \
  --dart-define=GITHUB_ISSUE_REPO_OWNER=YourOrg \
  --dart-define=GITHUB_ISSUE_REPO_NAME=YourRepo
```

## Option C: Backend Proxy (Recommended for Production)

For maximum security, route bug reports through your own backend server. This way, the GitHub token is **never exposed** in the app.

### Why Use a Backend Proxy?

- ✅ Token never embedded in app binary
- ✅ Can add rate limiting and spam protection
- ✅ Can sanitize/validate content before submission
- ✅ Can add server-side labeling and metadata
- ✅ Can require user authentication

### Setting Up the Proxy

1. Create a backend endpoint that accepts bug reports:

```
POST https://api.yourbackend.com/create-github-issue
```

2. Expected request body (sent by the app):

```json
{
  "title": "[User Report] App crashes on login",
  "body": "## Description\n...",
  "labels": ["bug", "user-reported", "severity:high"]
}
```

3. Your backend should forward to GitHub API:

```javascript
// Example Node.js/Express handler
app.post('/create-github-issue', async (req, res) => {
  const { title, body, labels } = req.body;

  const response = await fetch(
    'https://api.github.com/repos/DevelopersCoffee/airo_super_app/issues',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.GITHUB_TOKEN}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: JSON.stringify({ title, body, labels }),
    }
  );

  const data = await response.json();
  res.json(data);
});
```

4. Configure the app to use your proxy:

```bash
flutter run \
  --dart-define=GITHUB_ISSUE_PROXY_URL=https://api.yourbackend.com/create-github-issue \
  --dart-define=GITHUB_ISSUE_PROXY_API_KEY=your-api-key
```

### Proxy Authentication

The app sends an `X-API-Key` header when `GITHUB_ISSUE_PROXY_API_KEY` is set. Your backend should validate this key to prevent unauthorized submissions.

## Security Best Practices

1. **Use backend proxy** for production deployments
2. **Never commit tokens** to version control
3. **Use a bot account** instead of personal tokens
4. **Limit token permissions** to only `issues:write`
5. **Set token expiration** and rotate periodically
6. **Use repository-scoped tokens** (fine-grained) instead of classic tokens
7. **Add rate limiting** on your proxy endpoint
8. **Validate content** to prevent abuse

## Testing the Feature

1. Build and run the app with the token configured
2. Navigate to Profile → Developer Tools → Report a Bug
3. Fill in the form and submit
4. Verify the issue appears in the GitHub repository

## Troubleshooting

### "Bug reporting is not configured" Warning

This appears when `GITHUB_ISSUE_TOKEN` is not set. Ensure you're passing the token via `--dart-define`.

### "Failed to submit bug report" Error

Check:
- Token has `issues:write` permission
- Token has access to the target repository
- Token has not expired
- Network connectivity is available

### Rate Limiting

GitHub API has rate limits. If users submit too many reports:
- Authenticated requests: 5,000 per hour
- The service handles rate limit errors gracefully

## Architecture

```
app/lib/shared/widgets/bug_report_dialog.dart     # UI Dialog
packages/core_data/lib/src/bug_report/
  ├── bug_report_model.dart                       # Data models
  └── github_issue_service.dart                   # GitHub API service
.github/ISSUE_TEMPLATE/user_bug_report.md         # Issue template
```

## Related Files

- `app/lib/core/utils/logger.dart` - Log buffer for bug reports
- `app/lib/core/platform/platform_config.dart` - Platform detection
- `app/lib/features/agent_chat/presentation/screens/profile_screen.dart` - Settings integration

