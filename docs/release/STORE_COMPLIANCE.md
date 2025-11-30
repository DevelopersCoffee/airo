# 🏪 Store Compliance Guide

App Store and Play Store compliance requirements for Airo Super App.

---

## 📱 Google Play Store Requirements

### Metadata Requirements
| Field | Requirement | Airo Status |
|-------|-------------|-------------|
| App Name | ≤30 characters | ✅ "Airo" (4 chars) |
| Short Description | ≤80 characters | 📝 Pending |
| Full Description | ≤4000 characters | 📝 Pending |
| Screenshots | Min 2, Max 8 per device | 📝 Pending |
| Feature Graphic | 1024x500 PNG/JPG | 📝 Pending |
| App Icon | 512x512 PNG | 📝 Pending |

### Content Rating
- [ ] Complete IARC questionnaire
- [ ] Declare in-app purchases (if any)
- [ ] Declare ads (if any)
- [ ] Target audience declaration

### Privacy & Data Safety
- [ ] Privacy policy URL required
- [ ] Data safety form completed
- [ ] Data collection declaration
- [ ] Data sharing declaration
- [ ] Data security practices

### Technical Requirements
- [ ] Target API Level: Android 14 (API 34) minimum
- [ ] 64-bit support required
- [ ] App Bundle (AAB) format preferred
- [ ] Deobfuscation file uploaded (if ProGuard used)

### Permissions Declaration
| Permission | Justification |
|------------|---------------|
| CAMERA | Receipt/document scanning |
| INTERNET | AI queries, content sync |
| STORAGE | Save exports, cached content |

---

## 🍎 App Store (iOS) Requirements

### App Store Guidelines Summary
| Category | Requirement | Airo Status |
|----------|-------------|-------------|
| 1. Safety | No objectionable content | ✅ Clean |
| 2. Performance | No crashes, complete features | ✅ Stable |
| 3. Business | Clear monetization | ✅ Free |
| 4. Design | Follow HIG | 📝 Review |
| 5. Legal | Privacy compliance | 📝 Pending |

### Required Assets
- [ ] App icon (1024x1024)
- [ ] Screenshots (6.7", 6.5", 5.5" iPhones)
- [ ] iPad screenshots (if universal)
- [ ] App Preview video (optional)

### Privacy Requirements
- [ ] Privacy policy URL
- [ ] App Privacy details (nutrition labels)
- [ ] Tracking transparency (ATT if tracking)
- [ ] Sign in with Apple (if other social login)

### Technical Requirements
- [ ] Built with latest Xcode
- [ ] iOS 15+ minimum deployment
- [ ] IPv6 network support
- [ ] No private API usage

---

## 📄 Privacy Policy Requirements

### Must Include
1. **Data Collection** - What data is collected
2. **Data Usage** - How data is used
3. **Data Sharing** - Third parties involved
4. **Data Security** - Protection measures
5. **User Rights** - Access, deletion, portability
6. **Contact Info** - Developer contact
7. **Updates** - Policy change notification

### Airo-Specific Declarations
```markdown
## Data We Collect
- User preferences (local storage)
- AI conversation history (on-device)
- Receipt images (processed locally)

## Data We DON'T Collect
- Personal identification
- Location data
- Contact information
- Financial account details

## On-Device Processing
Airo uses on-device AI (Gemini Nano) for:
- Document analysis
- Expense extraction
- Natural language queries
No data is sent to external servers for AI processing.
```

---

## ✅ Pre-Submission Checklist

### Play Store
- [ ] App signed with release key
- [ ] Version code incremented
- [ ] AAB uploaded (not APK for new apps)
- [ ] All metadata filled
- [ ] Content rating completed
- [ ] Data safety form done
- [ ] Privacy policy live

### App Store
- [ ] Archive uploaded to App Store Connect
- [ ] Screenshots for all required devices
- [ ] App Privacy completed
- [ ] Review notes provided (if needed)
- [ ] Export compliance answered

---

## 🔗 Resources

- [Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Play Store Policy](https://play.google.com/about/developer-content-policy/)
- [App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)

