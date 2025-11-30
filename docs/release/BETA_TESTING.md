# 🧪 Beta Testing Coordination

Guide for coordinating beta testing for Airo Super App.

---

## 📋 Beta Testing Tracks

### Internal Testing (Alpha)
- **Audience**: Development team, QA
- **Access**: Immediate, no review
- **Purpose**: Early bug detection, feature validation

### Closed Beta
- **Audience**: Selected testers (invite-only)
- **Access**: Via email invite
- **Purpose**: Broader testing, feedback collection

### Open Beta
- **Audience**: Public opt-in
- **Access**: Anyone can join
- **Purpose**: Scale testing, final validation

---

## 🤖 Android Beta Setup

### Play Console Internal Testing
```
1. Go to Play Console > Testing > Internal testing
2. Create new release
3. Upload AAB file
4. Add tester emails (up to 100)
5. Publish
```

### Play Console Closed Testing
```
1. Go to Play Console > Testing > Closed testing
2. Create track (e.g., "Beta testers")
3. Create tester list or Google Group
4. Upload AAB and publish
5. Share opt-in link
```

### Firebase App Distribution (Alternative)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Distribute APK
firebase appdistribution:distribute app-release.apk \
  --app YOUR_FIREBASE_APP_ID \
  --groups "beta-testers" \
  --release-notes "Beta v1.2.0"
```

---

## 🍎 iOS Beta Setup (TestFlight)

### TestFlight Setup
```
1. Upload build to App Store Connect
2. Add internal testers (up to 100)
3. For external: Submit for Beta Review
4. Share TestFlight link
```

### Internal Testing
- Up to 100 testers
- No review required
- Access via email invite

### External Testing
- Up to 10,000 testers
- Requires Beta App Review
- Public link available

---

## 📊 Beta Feedback Collection

### Feedback Channels
| Channel | Purpose | Tool |
|---------|---------|------|
| In-app feedback | Bug reports | Custom form |
| GitHub Issues | Technical bugs | GitHub |
| Google Form | General feedback | Forms |
| Discord/Slack | Real-time chat | Community |

### Feedback Template
```markdown
**Device**: [e.g., Pixel 9, iPhone 15]
**OS Version**: [e.g., Android 14, iOS 17]
**App Version**: [e.g., v1.2.0-beta.1]

**Issue Type**: [ ] Bug [ ] Suggestion [ ] Question

**Description**:
[What happened?]

**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Behavior**:
[What should happen?]

**Screenshots/Videos**:
[Attach if applicable]
```

---

## 🔄 Beta Release Workflow

### 1. Prepare Build
```bash
# Bump version with beta tag
./scripts/release.sh 1.2.0-beta.1

# Build release APK
cd app && flutter build apk --release
```

### 2. Distribute
- Upload to Play Console internal track
- Or use Firebase App Distribution
- Or GitHub Release (pre-release)

### 3. Notify Testers
```markdown
Subject: Airo Beta v1.2.0-beta.1 Available

Hi Beta Testers!

New beta build is ready:
- Feature: [New feature]
- Fix: [Bug fix]
- Please test: [Focus area]

Download: [Link]
Feedback: [Form/Issue link]

Thanks for testing!
```

### 4. Monitor & Iterate
- Collect crash reports
- Review feedback
- Fix critical issues
- Release next beta

---

## ✅ Beta Tester Management

### Onboarding Checklist
- [ ] Add to tester group
- [ ] Send welcome email
- [ ] Share testing guidelines
- [ ] Provide feedback channel access
- [ ] Explain NDA (if applicable)

### Tester Expectations
1. Test new features promptly
2. Report bugs with details
3. Provide constructive feedback
4. Respect confidentiality
5. Update to latest builds

---

## 🔗 Links

- [Play Console Testing](https://play.google.com/console)
- [TestFlight](https://developer.apple.com/testflight/)
- [Firebase App Distribution](https://firebase.google.com/docs/app-distribution)
- [Release Checklist](./RELEASE_CHECKLIST.md)

