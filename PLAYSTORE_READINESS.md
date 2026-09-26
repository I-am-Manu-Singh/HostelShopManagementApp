# 🏪 Hostel Shop Management App — Play Store Readiness Checklist

> **App Name:** H House (as titled in main.dart)  
> **Package ID:** `com.hostel.shop.mgmt`  
> **Version:** 1.0.0+1  
> **Backend:** Supabase  
> **Framework:** Flutter (Material 3, Dart SDK ^3.9.2)  
> **Last Reviewed:** June 2026

---

## 🔴 CRITICAL BLOCKERS (Must fix before submitting)

These issues will cause rejection or crashes in production.

### 1. 🔑 Hardcoded API Keys / Secrets in Source Code

**File:** `lib/services/supabase_service.dart` (lines 8–9)

```dart
// ❌ CURRENT — INSECURE: Keys hardcoded in source
static const String supabaseUrl = 'https://kuttseqqxdfqbzekgqll.supabase.co';
static const String supabaseAnonKey = 'sb_publishable_2x-gJ3yNhM9yooDcEdeuWA_HQ379KgN';
```

**Fix:** Move to `--dart-define` build args or a `.env` file loaded via `flutter_dotenv`.

```bash
# Build with injected env vars (no keys in source)
flutter build appbundle \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_key
```

Then read in Dart:
```dart
static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

> ⚠️ Even `anonKey` is publicly safe by design in Supabase, but hardcoding any credential in source that ends up in a public repo is a bad practice and some Play Store policy scanners flag it.

---

### 2. 🔒 Release Signing Config Missing

**File:** `android/app/build.gradle.kts` (line 38)

```kotlin
// ❌ CURRENT — Uses debug keys for release build
signingConfig = signingConfigs.getByName("debug")
```

**Steps to fix:**

1. Generate a keystore (do this ONCE and keep it safe forever):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

2. Create `android/key.properties` (add to `.gitignore`):
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=/Users/manpreet/upload-keystore.jks
   ```

3. Update `android/app/build.gradle.kts`:
   ```kotlin
   val keyProperties = Properties()
   val keyPropertiesFile = rootProject.file("key.properties")
   if (keyPropertiesFile.exists()) keyProperties.load(keyPropertiesFile.inputStream())

   signingConfigs {
       create("release") {
           keyAlias = keyProperties["keyAlias"] as String
           keyPassword = keyProperties["keyPassword"] as String
           storeFile = file(keyProperties["storeFile"] as String)
           storePassword = keyProperties["storePassword"] as String
       }
   }
   buildTypes {
       release {
           signingConfig = signingConfigs.getByName("release")
           isMinifyEnabled = true
           isShrinkResources = true
       }
   }
   ```

> ⚠️ **NEVER lose your keystore.** You cannot update your app on Play Store without the same keystore used in the first upload.

---

### 3. 📝 App Description is Placeholder

**File:** `pubspec.yaml` (line 2)

```yaml
description: "A new Flutter project."  # ❌ Placeholder text
```

**Fix:** Update to a meaningful description:
```yaml
description: "H House — A comprehensive hostel management app for students and administrators."
```

---

### 4. 🏷️ App Label Says "Hostel Shop" (inconsistent branding)

- `AndroidManifest.xml` → `android:label="Hostel Shop"`
- `main.dart` → `title: 'H House'`

Pick one name and apply it consistently everywhere before release.

---

### 5. 🐛 Debug `print()` Statements in Production Code

**Files:** `main.dart` (lines 158, 160) and likely others.

```dart
print("Plugins initialized safely");  // ❌ Not appropriate for production
print("Init error: $e");
```

**Fix:** Replace all `print()` with a proper logging package like `logger` or wrap in `kDebugMode`:
```dart
import 'package:flutter/foundation.dart';
if (kDebugMode) print("...");
```

---

### 6. ❌ ProGuard / R8 Not Enabled for Release

Currently no minification/obfuscation is set. Add to `build.gradle.kts`:
```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
}
```

And create `android/app/proguard-rules.pro` (Flutter-specific rules are needed for Supabase, local_auth, etc.).

---

## 🟡 IMPORTANT (Strongly Recommended Before Launch)

### 7. 📊 Analytics Integration — NOT PRESENT

No analytics library detected in `pubspec.yaml` or services. You need analytics to understand user behavior.

**Recommended:** Firebase Analytics (free, integrates with Play Console)

**Steps:**
1. Add to `pubspec.yaml`:
   ```yaml
   firebase_core: ^3.x.x
   firebase_analytics: ^11.x.x
   firebase_crashlytics: ^4.x.x   # Crash reporting
   ```

2. Set up Firebase project at https://console.firebase.google.com
3. Download `google-services.json` → place in `android/app/`
4. Add plugin to `android/build.gradle.kts`:
   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   id("com.google.firebase.crashlytics") version "3.0.2" apply false
   ```
5. In `main.dart`:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
   ```

**Key events to track for a hostel app:**
- `login`, `logout`
- `shop_product_viewed`, `add_to_cart`, `checkout_started`, `order_placed`
- `complaint_submitted`, `outpass_requested`
- `attendance_marked`

---

### 8. 💳 In-App Purchases — NOT PRESENT

No IAP library detected. If you plan to monetize (premium features, digital wallet top-ups, etc.), integrate before launch.

**Recommended:** `in_app_purchase` (official Flutter plugin)

```yaml
in_app_purchase: ^3.x.x
```

**Setup Steps:**
1. Add the package above
2. In Google Play Console → your app → **Monetize** → **Products**:
   - **One-time products** (consumable): e.g., wallet top-up credits
   - **Subscriptions**: e.g., premium student plan
3. Define product IDs like: `wallet_100`, `wallet_500`, `premium_monthly`
4. Implement `InAppPurchase.instance.buyConsumable()` in your wallet reload flow
5. Verify purchases server-side (via Supabase Edge Function calling Google Play Developer API)

> ⚠️ Google Play **requires** server-side purchase verification for consumables to prevent fraud.

**Current wallet/fiscal flows to update:**
- `fiscal_reloading_screen.dart` — add IAP as a payment method
- `student_payment_screen.dart` — potentially gate premium features
- `employee_wallet_screen.dart` — potentially IAP for employer top-ups

**IAP Testing:** Use a test Google account and "License Testers" in Play Console before going live.

---

### 9. 🔒 Privacy Policy URL — Must Be Hosted

**Requirement:** Play Store requires a publicly accessible Privacy Policy URL.

You already have `privacy_policy_screen.dart` — now you need to:
1. Host the privacy policy as a web page (e.g., GitHub Pages, Notion, or your own domain)
2. Provide that URL in Play Console during app submission
3. Optionally add the URL to your `AndroidManifest.xml`:
   ```xml
   <meta-data
     android:name="android.support.PARENT_ACTIVITY"
     android:value=".MainActivity" />
   ```

**Free hosting option:** Create a GitHub Pages site or use [privacypolicygenerator.info](https://www.privacypolicygenerator.info)

---

### 10. 🛡️ Sensitive Permissions Justification

The following permissions require explicit justification in Play Console:

| Permission | Why Needed | Play Store Category |
|---|---|---|
| `USE_BIOMETRIC` | Biometric login for students | Normal — explain in description |
| `USE_FINGERPRINT` | Fallback biometric | Normal |
| `CAMERA` (implied by `mobile_scanner`, `camera`) | QR scanner, face enrollment | Declare in Play Console |
| `READ_MEDIA_AUDIO` | On-device music player | Declare in Play Console |
| `READ_EXTERNAL_STORAGE` | File picker / PDF generation | Needs justification |
| `FOREGROUND_SERVICE` | Background audio playback | Declare foreground service type |

**Action:** In Play Console → **App content** → **Permissions declaration**, explain each.

---

### 11. 📱 Target SDK Must Be Current

**Current:** `targetSdk = flutter.targetSdkVersion` (resolves via Flutter tooling — verify it's ≥ 35)

Google Play **requires** `targetSdkVersion >= 35` for new apps submitted after August 2025.

**Check:**
```bash
flutter doctor -v
# Look for: "Android target: Android 15 (API level 35)"
```

If not, update in `build.gradle.kts`:
```kotlin
targetSdk = 35
```

---

### 12. 🖼️ Play Store Assets Needed

You must prepare the following before submitting:

| Asset | Dimensions | Notes |
|---|---|---|
| App icon (hi-res) | 512×512 px PNG | No alpha, no rounded corners |
| Feature graphic | 1024×500 px | Required for store listing |
| Phone screenshots | Min 2, max 8 | At least 1 required per device type |
| Short description | Max 80 chars | Shown in search results |
| Full description | Max 4000 chars | App listing page |

**Your current logo:** `assets/images/app_logo.png` (53 KB) — verify it's 512×512 and high quality.

---

### 13. 🧪 No Tests Present

No test files detected beyond the default `flutter_test` dev dependency.

**Minimum recommended before launch:**
```bash
# Add to test/ directory
flutter test
```

Write tests for:
- `supabase_service.dart` — auth flow
- `cart_service.dart` — cart logic
- `notification_service.dart` — initialization

---

## 🟢 ALREADY DONE (Good to go)

- ✅ **Custom App Icon** — `flutter_launcher_icons` configured with `assets/images/app_logo.png`
- ✅ **Debug Banner Removed** — `debugShowCheckedModeBanner: false` in `main.dart`
- ✅ **Auth Guard Implemented** — `AuthGuard` widget with session stream
- ✅ **Deep Link for Supabase Auth** — `io.supabase.hostelshop://login-callback` configured
- ✅ **Min SDK = 24** — Covers ~97%+ of active Android devices
- ✅ **Material 3 + Dark Mode** — Both light and dark themes implemented
- ✅ **Legal Screens Present** — Privacy Policy, Terms of Service, Refund Policy screens exist
- ✅ **Notifications Infrastructure** — `flutter_local_notifications` + `POST_NOTIFICATIONS` permission
- ✅ **Core Library Desugaring** — Enabled for Java 8+ API compatibility
- ✅ **Background Audio** — `just_audio_background` + service declared in manifest
- ✅ **Biometric Auth** — `local_auth` integrated
- ✅ **QR Scanner** — `mobile_scanner` integrated

---

## 📋 Play Store Submission Process (Step-by-Step)

### Step 1: Create a Google Play Developer Account
- Go to: https://play.google.com/console
- One-time fee: **$25 USD**
- Requires a Google account and identity verification

### Step 2: Build a Release AAB

```bash
# Clean build
flutter clean
flutter pub get

# Build Android App Bundle (required by Play Store since 2021)
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://kuttseqqxdfqbzekgqll.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_key_here
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Step 3: Create App in Play Console

1. Go to **Play Console** → **Create app**
2. Fill in: App name, Default language, App type (App/Game), Free/Paid
3. Accept declarations

### Step 4: Complete Store Listing

- Short description (80 chars)
- Full description (4000 chars)
- Screenshots (phone, tablet if applicable)
- Feature graphic (1024×500)
- App icon (512×512)
- Privacy Policy URL (REQUIRED)
- Category: **Productivity** or **Business**

### Step 5: Content Rating Questionnaire

- Complete the IARC rating questionnaire
- For a hostel management app: likely **Everyone** rating
- Takes ~5 minutes in Play Console → **App content**

### Step 6: Target Audience & Ads Declaration

- Declare your target age group (18+, since hostel management = adults)
- Declare whether your app has ads (currently: NO)

### Step 7: App Content Declarations (Play Console → App content)

- **Permissions:** Justify each sensitive permission
- **Data safety form:** Declare what data your app collects (Supabase stores user data — you MUST declare: Name, Email, User IDs, Usage data)
- **Sensitive app access:** Declare biometric, camera, storage use

### Step 8: Set Up Release Track

1. Go to **Testing** → **Internal testing** (recommended first)
2. Upload your `.aab` file
3. Add internal testers (your own email)
4. Test thoroughly on real devices

### Step 9: Promote to Production

After internal + (optionally) closed/open testing:
1. **Production** → **Create new release**
2. Upload the same or updated `.aab`
3. Write release notes
4. Set rollout percentage (start with 10–20%)
5. Submit for review

### Step 10: Wait for Review

- First submission: **3–7 days** typically
- Subsequent updates: **Hours to 2 days**
- Monitor Play Console for any policy violations

---

## 🔢 Versioning Strategy

```yaml
# pubspec.yaml
version: 1.0.0+1
#         ^   ^
#         |   versionCode (integer, must increase with every upload)
#         versionName (user-visible, e.g., "1.0.0")
```

**Before each Play Store upload:**
```bash
# Bump version in pubspec.yaml, then build
# Example: 1.0.0+1 → 1.0.1+2 for a patch, 1.1.0+3 for a minor release
flutter build appbundle --build-name=1.0.1 --build-number=2 --release
```

---

## 📊 Post-Launch Monitoring Checklist

Once live, monitor these regularly:

- [ ] **Firebase Crashlytics** — Check crash-free rate (target >99.5%)
- [ ] **Firebase Analytics** — DAU/MAU, retention, funnel drop-off
- [ ] **Play Console → Android Vitals** — ANR rate, crash rate
- [ ] **Play Console → Reviews** — Respond to user reviews
- [ ] **Play Console → Pre-launch report** — Automated test results by Google

---

## 📁 Summary: Files To Change Before Release

| File | Change Required | Priority |
|---|---|---|
| `lib/services/supabase_service.dart` | Remove hardcoded keys, use `--dart-define` | 🔴 Critical |
| `android/app/build.gradle.kts` | Add release signing config | 🔴 Critical |
| `pubspec.yaml` | Fix placeholder description | 🔴 Critical |
| `android/app/src/main/AndroidManifest.xml` | Fix app label branding | 🟡 Important |
| `lib/main.dart` | Remove `print()` statements | 🟡 Important |
| `android/app/build.gradle.kts` | Enable R8/ProGuard minification | 🟡 Important |
| NEW: `pubspec.yaml` | Add `firebase_analytics`, `firebase_crashlytics` | 🟡 Important |
| NEW: `android/app/google-services.json` | Firebase config file | 🟡 Important |
| NEW: `android/key.properties` | Release keystore reference | 🔴 Critical |
| NEW: `android/app/proguard-rules.pro` | ProGuard rules | 🟡 Important |

---

*Generated by Antigravity IDE — H House Hostel App*

✅ 

PLAYSTORE_READINESS.md
 has been created at the project root. Here's the summary of what was found:

🔍 Audit Results for H House (Hostel Shop)
🔴 Critical Blockers (Fix First)
Hardcoded Supabase keys in supabase_service.dart — move to --dart-define build args
Release signing uses debug keystore — you need a proper upload keystore + key.properties
Placeholder description in pubspec.yaml ("A new Flutter project.")
Branding inconsistency — Manifest says "Hostel Shop", app title says "H House"
print() statements in production code (main.dart)
No ProGuard/R8 minification enabled for release builds
🟡 Important (Before Launch)
No analytics — Firebase Analytics + Crashlytics not integrated
No In-App Purchases — If you plan to monetize (wallet top-ups etc.), use in_app_purchase package
Privacy Policy must be hosted at a public URL (Play Console requires a link)
Sensitive permissions (biometric, camera, storage) need Play Console justifications in the Data Safety form
No tests written
✅ Already Done Well
Custom app icon configured
Debug banner disabled
Auth guard with Supabase session stream
Deep links for auth callback
Legal screens (Privacy Policy, ToS, Refund Policy) exist
Dark mode + Material 3
Biometric, QR scanner, notifications all integrated
🚀 Key Things to Know About IAP & Analytics
Analytics: Add firebase_analytics + firebase_crashlytics → create a Firebase project → download google-services.json → track events like order_placed, outpass_requested, login.

In-App Purchases: Use in_app_purchase Flutter package. Define products in Play Console → wire up to your existing fiscal_reloading_screen.dart and student_payment_screen.dart. Must verify purchases server-side via a Supabase Edge Function.

The file has the complete step-by-step Play Store submission process included.
