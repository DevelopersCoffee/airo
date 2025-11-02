# SonarQube & Snyk Integration Setup

## 🎯 Overview

This guide explains how to set up SonarQube and Snyk for code quality and security scanning in the Airo super app CI/CD pipeline.

### What They Do

**SonarQube**:
- Code quality analysis
- Bug detection
- Code smells identification
- Technical debt tracking
- Coverage reporting

**Snyk**:
- Dependency vulnerability scanning
- Security issue detection
- License compliance checking
- Automated fix suggestions

---

## 🔐 SonarQube Setup

### Step 1: Create SonarQube Account

1. Go to: https://sonarcloud.io
2. Click **Sign up**
3. Choose **GitHub** as login method
4. Authorize SonarCloud to access your GitHub account
5. Create organization (or use existing)

### Step 2: Create Project

1. In SonarCloud, click **Create project**
2. Select **GitHub** as repository source
3. Search for `airo` repository
4. Click **Set up**
5. Choose **Free plan** (or paid if needed)

### Step 3: Generate Token

1. Go to: https://sonarcloud.io/account/security
2. Click **Generate Tokens**
3. Name: `AIRO_CI_TOKEN`
4. Type: `Global Analysis Token`
5. Click **Generate**
6. **Copy the token** (you won't see it again!)

### Step 4: Add GitHub Secret

1. Go to: https://github.com/DevelopersCoffee/airo/settings/secrets/actions
2. Click **New repository secret**
3. Name: `SONAR_TOKEN`
4. Value: Paste the token from Step 3
5. Click **Add secret**

### Step 5: Configure SonarQube (Optional)

For SonarCloud (cloud version):
- No additional configuration needed
- Uses default settings

For Self-Hosted SonarQube:
1. Add another secret: `SONAR_HOST_URL`
2. Value: `https://your-sonarqube-instance.com`

---

## 🔐 Snyk Setup

### Step 1: Create Snyk Account

1. Go to: https://app.snyk.io
2. Click **Sign up**
3. Choose **GitHub** as login method
4. Authorize Snyk to access your GitHub account
5. Complete onboarding

### Step 2: Add Repository

1. In Snyk dashboard, click **Add project**
2. Select **GitHub**
3. Search for `airo` repository
4. Click **Add selected repositories**
5. Snyk will scan the repository

### Step 3: Generate API Token

1. Go to: https://app.snyk.io/account/api-token
2. Click **Show** to reveal token
3. Click **Copy** to copy token
4. **Save the token** (you'll need it for GitHub)

### Step 4: Add GitHub Secret

1. Go to: https://github.com/DevelopersCoffee/airo/settings/secrets/actions
2. Click **New repository secret**
3. Name: `SNYK_TOKEN`
4. Value: Paste the token from Step 3
5. Click **Add secret**

### Step 5: Configure Snyk Settings (Optional)

In Snyk dashboard:
1. Go to **Settings** → **Organization settings**
2. Configure severity thresholds
3. Set up notifications
4. Configure auto-fix settings

---

## 📊 GitHub Secrets Summary

Add these secrets to your GitHub repository:

| Secret Name | Value | Source |
|-------------|-------|--------|
| `SONAR_TOKEN` | SonarCloud token | https://sonarcloud.io/account/security |
| `SNYK_TOKEN` | Snyk API token | https://app.snyk.io/account/api-token |
| `SONAR_HOST_URL` | (Optional) Self-hosted URL | Your SonarQube instance |

---

## 🚀 How It Works

### On Every Push

1. **SonarQube Analysis**
   - Analyzes code quality
   - Detects bugs and code smells
   - Generates quality report
   - Checks quality gate

2. **Snyk Scan**
   - Scans dependencies
   - Detects vulnerabilities
   - Checks licenses
   - Suggests fixes

### Results

**SonarQube**:
- View results at: https://sonarcloud.io/projects
- Check quality gate status
- Review code issues

**Snyk**:
- View results at: https://app.snyk.io/org/ucguy4u/
- Check vulnerability report
- Review recommendations

---

## 📈 Viewing Results

### SonarQube Dashboard

1. Go to: https://sonarcloud.io/projects
2. Click on **airo-super-app** project
3. View:
   - Code quality metrics
   - Bug count
   - Code smells
   - Coverage
   - Technical debt

### Snyk Dashboard

1. Go to: https://app.snyk.io/org/ucguy4u/
2. Click on **airo** project
3. View:
   - Vulnerability count
   - Severity breakdown
   - Dependency issues
   - License compliance

---

## 🔧 Workflow Configuration

### SonarQube Job

```yaml
sonarqube:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Full history for better analysis
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
    
    - name: Get dependencies
      run: cd app && flutter pub get
    
    - name: SonarQube Scan
      uses: SonarSource/sonarqube-scan-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

### Snyk Job

```yaml
snyk:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
    
    - name: Get dependencies
      run: cd app && flutter pub get
    
    - name: Run Snyk Security Scan
      uses: snyk/actions/flutter@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

---

## 📋 Troubleshooting

### SonarQube Issues

**Q: "SONAR_TOKEN not found"**
- A: Add SONAR_TOKEN secret to GitHub

**Q: "Quality gate failed"**
- A: Review issues in SonarCloud dashboard
- Fix code quality issues
- Re-run workflow

**Q: "No coverage data"**
- A: Ensure tests run with coverage
- Check coverage file path

### Snyk Issues

**Q: "SNYK_TOKEN not found"**
- A: Add SNYK_TOKEN secret to GitHub

**Q: "No vulnerabilities found"**
- A: This is good! No security issues detected

**Q: "Vulnerabilities detected"**
- A: Review in Snyk dashboard
- Update dependencies
- Apply suggested fixes

---

## 🎯 Best Practices

### Code Quality

1. **Fix SonarQube Issues**
   - Address bugs first
   - Then code smells
   - Improve coverage

2. **Maintain Quality Gate**
   - Keep quality gate passing
   - Monitor technical debt
   - Regular refactoring

### Security

1. **Fix Vulnerabilities**
   - High severity first
   - Medium severity next
   - Low severity last

2. **Keep Dependencies Updated**
   - Regular updates
   - Monitor advisories
   - Use Snyk auto-fix

---

## 📞 Support

### Documentation
- SonarCloud: https://docs.sonarcloud.io
- Snyk: https://docs.snyk.io

### Dashboards
- SonarCloud: https://sonarcloud.io/projects
- Snyk: https://app.snyk.io/org/ucguy4u/

### Help
- SonarCloud Support: https://community.sonarsource.com
- Snyk Support: https://support.snyk.io

---

## ✅ Verification Checklist

- [ ] SonarCloud account created
- [ ] Snyk account created
- [ ] SONAR_TOKEN secret added
- [ ] SNYK_TOKEN secret added
- [ ] First CI run completed
- [ ] SonarQube results visible
- [ ] Snyk results visible
- [ ] Quality gate configured
- [ ] Team notified

---

**Status**: ✅ Ready for setup
**Date**: November 2, 2025
**Next Step**: Follow setup steps above

