# 🔒 SonarQube & Snyk Setup Guide

## 📋 Overview

This guide walks you through setting up SonarQube and Snyk for the Airo super app.

**Time Required**: ~15 minutes
**Difficulty**: Easy
**Prerequisites**: GitHub account

---

## 🎯 Step-by-Step Setup

### Part 1: SonarQube Setup (5 minutes)

#### Step 1.1: Create SonarCloud Account

1. Go to: **https://sonarcloud.io**
2. Click **Sign up**
3. Choose **GitHub** as login method
4. Click **Authorize SonarCloud**
5. Complete the authorization

#### Step 1.2: Create Organization

1. After login, click **Create organization**
2. Choose **Free plan**
3. Name: `airo-super-app`
4. Click **Create**

#### Step 1.3: Create Project

1. Click **Create project**
2. Select **GitHub** as repository source
3. Search for `airo` repository
4. Click **Set up**
5. Choose **Free plan**
6. Click **Create project**

#### Step 1.4: Generate Token

1. Go to: **https://sonarcloud.io/account/security**
2. Click **Generate Tokens**
3. Name: `AIRO_CI_TOKEN`
4. Type: `Global Analysis Token`
5. Click **Generate**
6. **Copy the token** (save it somewhere safe!)

#### Step 1.5: Add GitHub Secret

1. Go to: **https://github.com/DevelopersCoffee/airo/settings/secrets/actions**
2. Click **New repository secret**
3. Name: `SONAR_TOKEN`
4. Value: Paste the token from Step 1.4
5. Click **Add secret**

✅ **SonarQube Setup Complete!**

---

### Part 2: Snyk Setup (5 minutes)

#### Step 2.1: Create Snyk Account

1. Go to: **https://app.snyk.io**
2. Click **Sign up**
3. Choose **GitHub** as login method
4. Click **Authorize Snyk**
5. Complete the authorization

#### Step 2.2: Add Repository

1. After login, click **Add project**
2. Select **GitHub**
3. Search for `airo` repository
4. Click **Add selected repositories**
5. Wait for initial scan to complete

#### Step 2.3: Generate API Token

1. Go to: **https://app.snyk.io/account/api-token**
2. Click **Show** to reveal token
3. Click **Copy** to copy token
4. **Save the token** (you'll need it for GitHub)

#### Step 2.4: Add GitHub Secret

1. Go to: **https://github.com/DevelopersCoffee/airo/settings/secrets/actions**
2. Click **New repository secret**
3. Name: `SNYK_TOKEN`
4. Value: Paste the token from Step 2.3
5. Click **Add secret**

✅ **Snyk Setup Complete!**

---

## ✅ Verification

### Verify Secrets Added

1. Go to: **https://github.com/DevelopersCoffee/airo/settings/secrets/actions**
2. You should see:
   - ✅ `SONAR_TOKEN`
   - ✅ `SNYK_TOKEN`

### Test Integration

1. Push a commit to main:
   ```bash
   git push origin main
   ```

2. Go to: **https://github.com/DevelopersCoffee/airo/actions**

3. Wait for workflow to complete (~10 minutes)

4. Check results:
   - **SonarQube**: https://sonarcloud.io/projects
   - **Snyk**: https://app.snyk.io/org/ucguy4u/

---

## 📊 Viewing Results

### SonarCloud Dashboard

**URL**: https://sonarcloud.io/projects

**What You'll See**:
- Code quality metrics
- Bug count and details
- Code smells
- Test coverage percentage
- Technical debt
- Quality gate status

### Snyk Dashboard

**URL**: https://app.snyk.io/org/ucguy4u/

**What You'll See**:
- Vulnerability count
- Severity breakdown
- Dependency issues
- License compliance
- Remediation suggestions

---

## 🛠️ Local Testing

### Run SonarQube Analysis Locally

```bash
# Set token
export SONAR_TOKEN=your_token_here

# Run analysis
make sonar-scan
```

### Run Snyk Scan Locally

```bash
# Set token
export SNYK_TOKEN=your_token_here

# Run scan
make snyk-scan
```

### Run All Checks

```bash
make full-check
```

---

## 📋 Troubleshooting

### SonarQube Issues

**Q: "SONAR_TOKEN not found" error**
- A: Verify secret is added to GitHub
- Check secret name is exactly `SONAR_TOKEN`

**Q: "Quality gate failed"**
- A: Review issues in SonarCloud dashboard
- Fix code quality issues
- Re-run workflow

**Q: "No coverage data"**
- A: Ensure tests run with coverage
- Check `app/coverage/lcov.info` exists

### Snyk Issues

**Q: "SNYK_TOKEN not found" error**
- A: Verify secret is added to GitHub
- Check secret name is exactly `SNYK_TOKEN`

**Q: "Vulnerabilities detected"**
- A: Review in Snyk dashboard
- Update vulnerable dependencies
- Apply suggested fixes

**Q: "License issues"**
- A: Review licenses in Snyk dashboard
- Update or replace incompatible packages

---

## 🎯 Next Steps

1. ✅ Create SonarCloud account
2. ✅ Create Snyk account
3. ✅ Add GitHub secrets
4. ✅ Test integration
5. 📊 Monitor dashboards
6. 🔧 Fix issues as they appear
7. 📈 Improve metrics over time

---

## 📞 Support

### Documentation
- **SonarCloud**: https://docs.sonarcloud.io
- **Snyk**: https://docs.snyk.io

### Dashboards
- **SonarCloud**: https://sonarcloud.io/projects
- **Snyk**: https://app.snyk.io/org/ucguy4u/

### Help
- **SonarCloud Community**: https://community.sonarsource.com
- **Snyk Support**: https://support.snyk.io

---

## ✅ Checklist

- [ ] SonarCloud account created
- [ ] Snyk account created
- [ ] SONAR_TOKEN secret added
- [ ] SNYK_TOKEN secret added
- [ ] First CI run completed
- [ ] SonarQube results visible
- [ ] Snyk results visible
- [ ] Team notified

---

**Status**: ✅ Ready to setup
**Date**: November 2, 2025
**Time to Complete**: ~15 minutes

