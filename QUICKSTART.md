# 🚀 QUICK START GUIDE - Masterpiece App

## 1️⃣ SETUP (First Time Only)

### Step 1: Install Dependencies
```bash
cd c:\Users\kingk\Documents\konsi_app
flutter pub get
```

### Step 2: Verify .env File
Ensure `.env` exists in project root with:
```
GEMINI_API_KEY=AIzaSyB56VnFFk_H-sY8dWidjAmWDSj-PzoTQKQ
```

If missing, copy from `.env.example` and update with your actual API key.

---

## 2️⃣ RUNNING THE APP

### On Emulator/Device
```bash
flutter run
```

### Hot Reload (Active Development)
- **Hot Reload**: Press `R` in terminal (fast reload, keeps state)
- **Full Rebuild**: Press `r` in terminal (full rebuild)
- **Stop**: Press `q` in terminal

### Build APK (Android)
```bash
flutter build apk --release
```

### Build IPA (iOS)  
```bash
flutter build ios --release
```

---

## 3️⃣ KEY FEATURES TO TEST

### 📅 Schedule Management
1. Go to **Schedule** tab
2. Click **"+"** button
3. Select **"From Image"** or **"From AI" or "Manual"**
4. Add schedule events
5. Events > 2 hours old auto-move to History tab

### 💬 Solicitation Tracking
1. Go to **Solicitations** tab
2. Create new solicitation (Camera/Gallery/Manual)
3. Track status: Pending → Completed
4. Add completion details (amount given, notes)

### 📝 Masterpiece Content Creation
1. Go to **Posting** tab
2. Click **Monday**, **Saturday**, or **Sunday**
3. Click **"Generate Content"**
4. Preview generated content
5. Click **"Schedule"** to schedule post
6. View calendar of scheduled posts

### 📸 Photo Template
1. Go to **Photo** tab
2. Create beautiful photo template (as before)
3. Export/share directly

### 📊 Masterpiece Reports
1. Go to **Reports & Analytics** tab
2. View **Overview**: KPIs and completion rate
3. View **Year Graph**: Trends and year-over-year comparison
4. View **Monthly**: Month-by-month breakdown
5. View **Events**: Distribution by day of week
6. Click **"Export Masterpiece Report"** for hardcopy

---

## 4️⃣ DEVELOPMENT TIPS

### Enable Hot Reload Preference
Edit config for faster development:
```bash
# Keep app running during development
flutter run --hot
```

### View Logs
```bash
# Real-time logs
flutter logs

# Filter by app
flutter logs --grep="konsi_app"
```

### Check App Size
```bash
flutter build apk --analyze-size
```

### Dart Analysis (Find Errors)
```bash
flutter analyze
```

### Format Code
```bash
dart format lib/
```

---

## 5️⃣ TROUBLESHOOTING

### "API Key Not Found"
✅ **Solution**: Add `GEMINI_API_KEY` to `.env`

### Widgets Not Updating
✅ **Solution**: Press `R` for hot reload

### Charts Not Showing
✅ **Solution**: Run `flutter pub get` again

### App Crashes on Startup  
✅ **Solution**: 
```bash
flutter clean
flutter pub get
flutter run
```

### Permission Denied (Android/iOS)
✅ **Solution**: Grant permissions when prompted
- Camera
- Photo Library
- External Storage
- Notifications

---

## 6️⃣ KEY FILES TO KNOW

### Core Files
- `lib/main.dart` - App entry point
- `lib/screens/home_screen.dart` - Main navigation
- `lib/themes/masterpiece_theme.dart` - Unified design

### Service Layer  
- `lib/services/storage_service.dart` - Local data
- `lib/services/gemini_service.dart` - AI integration
- `lib/services/analytics_service.dart` - Tracking
- `lib/services/cloud_sync_framework.dart` - Future cloud sync

### Models
- `lib/models/schedule_event.dart` - Event structure
- `lib/models/solicitation.dart` - Request structure
- `lib/models/scheduled_post.dart` - Post structure

---

## 7️⃣ ENVIRONMENT VARIABLES

### Development (.env)
```
GEMINI_API_KEY=dev_key_here
```

### Production  
```
GEMINI_API_KEY=prod_key_here
```

**NEVER commit .env to version control!**

---

## 8️⃣ USEFUL FLUTTER COMMANDS

```bash
# Check health
flutter doctor

# List connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run with specific flavor (if configured)
flutter run --flavor production

# Enable verbose logging
flutter run -v

# Profile app performance
flutter run --profile

# Release build for deployment
flutter build apk --release
flutter build appbundle --release
```

---

## 9️⃣ SCREEN OVERVIEW

### 📅 Schedule Screen
- Create/view/delete schedule events
- Filter by day of week
- Multi-select and bulk delete
- Export events as images
- Export day bundles

### 💬 Solicitation Screen  
- Track community requests
- Separate pending/completed tabs
- Mark as completed with details
- History of fulfilled requests

### 📝 Posting Screen (Masterpiece Content)
- **Monday**: Trivia/Did You Know?
- **Saturday**: Inspirational & Leadership
- **Sunday**: Bible Verses
- AI-powered content generation
- Schedule for future publishing
- Share to community channels

### 📸 Photo Template
- Create branded photo templates
- Save to gallery
- Share directly
- Professional design elements

### 📊 Reports (Masterpiece Analytics)
- **Overview**: Key metrics
- **Year Graph**: Trends analysis
- **Monthly**: Month-by-month breakdown  
- **Events**: Distribution analysis
- Export comprehensive reports

---

## 🎯 TESTING WORKFLOW

Suggested order for feature testing:

1. ✅ Basic navigation (all tabs working)
2. ✅ Create schedule event
3. ✅ Create solicitation
4. ✅ Mark solicitation completed
5. ✅ Create Monday content
6. ✅ Create Saturday content
7. ✅ Create Sunday content
8. ✅ View reports
9. ✅ Generate & export report
10. ✅ Check theme consistency

---

## 💾 DATA PERSISTENCE

All data stored locally:
- **Schedule Events**: `schedule_events` (SharedPreferences)
- **Solicitations**: `solicitations` (SharedPreferences)
- **Scheduled Posts**: `scheduled_content_posts` (SharedPreferences)
- **Photos**: `konsi_gallery` directory (App Documents)
- **Analytics**: `app_analytics_data` (SharedPreferences)

**Clear app data**:
```bash
# Android
adb shell pm clear com.example.konsi_app

# iOS: Settings → General → Storage → Konsehal Lagaya → Offload App
```

---

## 🚢 DEPLOYMENT CHECKLIST

- [ ] Test all 5 main tabs
- [ ] Verify theme colors throughout
- [ ] Export a report successfully
- [ ] Create content for all 3 days (Mon, Sat, Sun)
- [ ] Check auto-history migration
- [ ] Build APK/AAB successfully
- [ ] Test on real device
- [ ] Verify permissions working
- [ ] Check no hardcoded secrets in code

---

## 📱 APK INSTALLATION (Android)

### Build
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Install via ADB
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Install via File
- Transfer APK to Android device
- Open file manager → Navigate to APK
- Tap to install (allow unknown sources if prompted)

---

## 🎓 ARCHITECTURE OVERVIEW

```
User Interface (Screens)
        ↓
State Management (StatefulWidget)
        ↓
Service Layer (Gemini, Storage, Analytics)
        ↓
Data Models (Event, Solicitation, Post)
        ↓
Local Storage (SharedPreferences, Files)
        ↓
[Future: Cloud Backend]
```

---

## ✨ PERFORMANCE TIPS

- App loads theme once at startup (no repeated loading)
- Analytics keeps 1000 recent events (auto-prunes old entries)
- Reports generate on-demand (no background processing)
- Images compressed before storage
- All operations are async (UI never blocks)

---

## 🤝 SUPPORTING DOCUMENTATION

- `MASTERPIECE.md` - Complete feature documentation
- `README.md` - Project overview
- `SETUP_COMPLETE.md` - Initial setup details
- `.env.example` - Environment variable template

---

## 🔗 DEPENDENCIES

Key packages installed:
- `google_fonts` ^6.1.0 - Typography
- `google_generative_ai` ^0.4.7 - AI features
- `flutter_local_notifications` ^17.2.2 - Notifications
- `shared_preferences` ^2.2.2 - Local storage
- `fl_chart` ^0.69.0 - Analytics charts
- `flutter_dotenv` ^5.1.0 - Environment config
- `pdf` ^3.10.0 - Report generation
- `printing` ^5.11.0 - Print/share

---

**Ready to Crush It! 🚀**

*Serbisyong Tapat para sa Lahat*
