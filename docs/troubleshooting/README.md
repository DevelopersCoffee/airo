# 🐛 Troubleshooting

Common issues and solutions.

---

## 📖 Common Issues

### Build Issues

**Q: "Flutter not found"**
- A: Ensure Flutter is installed and in PATH
- Check: `flutter --version`

**Q: "Java version error"**
- A: Ensure Java 17+ is installed
- Check: `java -version`

**Q: "Android SDK not found"**
- A: Install Android SDK
- Check: `flutter doctor`

### CI/CD Issues

**Q: "SONAR_TOKEN not found"**
- A: Add SONAR_TOKEN secret to GitHub
- See: [Security Setup](../security/SONAR_SNYK_SETUP_GUIDE.md)

**Q: "Build timeout"**
- A: Check runner logs
- Increase timeout if needed

**Q: "Release not created"**
- A: Verify tag format (v1.0.0)
- Check workflow permissions

### Security Issues

**Q: "Vulnerabilities detected"**
- A: Review in Snyk dashboard
- Update dependencies

**Q: "Quality gate failed"**
- A: Fix issues in SonarCloud
- Review code quality metrics

### Runtime Issues

**Q: "App crashes on startup"**
- A: Check logs
- Verify Firebase config
- Check permissions

**Q: "Feature not working"**
- A: Check feature flags
- Verify permissions
- Check logs

---

## 🔗 Getting Help

### Documentation
- [Getting Started](../getting-started/)
- [CI/CD Guide](../ci-cd/)
- [Security Guide](../security/)

### External Resources
- **Flutter Issues**: https://github.com/flutter/flutter/issues
- **GitHub Issues**: https://github.com/DevelopersCoffee/airo/issues
- **Stack Overflow**: https://stackoverflow.com/questions/tagged/flutter

### Contact
- **GitHub Issues**: Create an issue
- **Email**: team@airo.dev

---

## 📋 Debugging Tips

### Enable Verbose Logging
```bash
flutter run -v
```

### Check Flutter Doctor
```bash
flutter doctor -v
```

### View Logs
```bash
adb logcat  # Android
log stream --predicate 'process == "airo"'  # iOS
```

### Clear Cache
```bash
flutter clean
flutter pub get
```

---

## 📞 Support

### Need Help?

1. **Check this guide** - Most answers are here
2. **Search GitHub Issues** - Your issue might be answered
3. **Create an Issue** - If you can't find the answer
4. **Contact Team** - For urgent matters

---

**Can't find your issue?** → [Create a GitHub Issue](https://github.com/DevelopersCoffee/airo/issues)

