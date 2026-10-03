import os
import shutil
from PIL import Image

def generate_assets(project_dir, logo_path, app_name, short_desc, full_desc):
    print(f">>> Processing {app_name} in {project_dir}...")
    if not os.path.exists(logo_path):
        print(f"  [ERR] Logo not found: {logo_path}")
        return
        
    img = Image.open(logo_path).convert('RGBA')
    
    # 1. Playstore directory & assets
    ps_dir = os.path.join(project_dir, 'playstore')
    os.makedirs(ps_dir, exist_ok=True)
    
    # icon_512.png
    icon_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
    icon_512.save(os.path.join(ps_dir, 'icon_512.png'), 'PNG')
    
    # feature_graphic.png (1024x500)
    fg = Image.new('RGBA', (1024, 500), (18, 24, 38, 255))
    logo_for_fg = img.resize((320, 320), Image.Resampling.LANCZOS)
    fg.paste(logo_for_fg, (100, 90), logo_for_fg)
    fg.save(os.path.join(ps_dir, 'feature_graphic.png'), 'PNG')
    
    # STORE_LISTING.md
    listing_content = f"""# Google Play Store Listing: {app_name}

## 1. App Title (Max 30 characters)
{app_name[:30]}

## 2. Short Description (Max 80 characters)
{short_desc[:80]}

## 3. Full Description (Max 4000 characters)
{full_desc}

---

## 4. Play Store Graphics Checklist
- [x] App Icon: 512x512 PNG (`playstore/icon_512.png`)
- [x] Feature Graphic: 1024x500 PNG (`playstore/feature_graphic.png`)
- [ ] Phone Screenshots: Min 2, Max 8 (16:9 or 9:16 aspect ratio)
"""
    with open(os.path.join(ps_dir, 'STORE_LISTING.md'), 'w') as f:
        f.write(listing_content)
        
    # 2. Docs directory
    docs_dir = os.path.join(project_dir, 'docs')
    os.makedirs(docs_dir, exist_ok=True)
    
    # PRIVACY_POLICY.md
    with open(os.path.join(docs_dir, 'PRIVACY_POLICY.md'), 'w') as f:
        f.write(f"""# Privacy Policy for {app_name}
**Last updated:** October 3, 2026

We respect your privacy. {app_name} collects minimal data necessary to provide essential functionality.
Data is processed securely and is never sold to third parties.

For inquiries, contact: support@{app_name.lower().replace(' ', '')}.com
""")

    # TERMS_OF_SERVICE.md
    with open(os.path.join(docs_dir, 'TERMS_OF_SERVICE.md'), 'w') as f:
        f.write(f"""# Terms of Service for {app_name}
**Effective Date:** October 3, 2026

By downloading or using {app_name}, you agree to these terms.
The application is provided "as is" without warranty.
""")

    # data_safety_export.csv
    with open(os.path.join(docs_dir, 'data_safety_export.csv'), 'w') as f:
        f.write("""Question,Response
Does your app collect or share user data?,Yes
Is all data encrypted in transit?,Yes
Do you provide a way for users to request data deletion?,Yes
Personal Info - User IDs,Collected for app functionality and account management
Device or other IDs,Collected for analytics and security
""")

    # 3. Android mipmaps
    res_dirs = []
    for root, dirs, _ in os.walk(project_dir):
        if 'build' in root or '.gradle' in root or 'node_modules' in root:
            continue
        if os.path.basename(root) == 'res' and any(d.startswith('mipmap') for d in dirs):
            res_dirs.append(root)
            
    mipmap_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    
    for r_dir in res_dirs:
        for folder, sz in mipmap_sizes.items():
            t_dir = os.path.join(r_dir, folder)
            os.makedirs(t_dir, exist_ok=True)
            resized = img.resize((sz, sz), Image.Resampling.LANCZOS)
            resized.save(os.path.join(t_dir, 'ic_launcher.png'), 'PNG')
            resized.save(os.path.join(t_dir, 'ic_launcher_round.png'), 'PNG')
            
    print(f"  [SUCCESS] {app_name} playstore, docs & mipmaps updated.")

if __name__ == '__main__':
    projects = [
        (
            '/Users/manpreet/Desktop/FlutterProjects/TrekBookingApp',
            '/Users/manpreet/Desktop/FlutterProjects/TrekBookingApp/app_logo.png',
            'Trek Booking App',
            'Explore, book, and experience mountain treks & adventures worldwide.',
            '''# Trek Booking App - Your Ultimate Mountain Expedition Companion

Plan, discover, and reserve high-altitude adventures, weekend trails, and certified guided expeditions with ease.

### Key Features:
- Curated Trails & Expeditions: In-depth itinerary guides, elevation charts, gear requirements, and weather intelligence.
- Certified Guide Booking: Reserve slots directly with verified local climbing instructors.
- Offline Gear & Safety Checklist: Pack with confidence and access digital maps offline.
- Secure Reservations: Real-time slot locking, instant payments, and transparent cancellation terms.'''
        ),
        (
            '/Users/manpreet/Desktop/ReactNativeProjects/MedHome',
            '/Users/manpreet/Desktop/ReactNativeProjects/MedHome/assets/icon.png',
            'MedHome',
            'Healthcare management, prescription reminders & home medical care booking.',
            '''# MedHome - Personal Health & Home Medical Care

Manage prescriptions, consult doctors, and schedule home lab visits with utmost security and privacy.

### Key Features:
- Doctor Consultation & Booking: Tele-health and verified doctor house visits.
- Medication Reminders: Daily dosage notifications and refilling alerts.
- Lab Test at Home: Diagnostic tests sample pickup directly from your doorstep.
- Health Records Vault: Encrypted medical history and lab reports accessible anytime.'''
        ),
        (
            '/Users/manpreet/Desktop/ReactNativeProjects/MerchantApp',
            '/Users/manpreet/Desktop/ReactNativeProjects/MerchantApp/assets/images/icon.png',
            'Merchant App',
            'Manage storefront inventory, orders, billing, and customer settlements.',
            '''# Merchant App - Retail POS & Inventory Command Center

Empower your store operations with fast POS barcode billing, live stock tracking, and supplier settlements.

### Key Features:
- Instant POS Billing: High-speed barcode scanning and multi-mode payment collection.
- Real-Time Inventory: Automated low-stock alerts, supplier tracking, and batch control.
- Customer Ledger & Analytics: Track sales trends, credit ledgers, and profit margins.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/TiffinManagement',
            '/Users/manpreet/Desktop/AndroidStudioProjects/TiffinManagement/composeApp/src/commonMain/composeResources/drawable/app_logo.png',
            'Tiffin Management',
            'Automate daily meal subscriptions, tiffin delivery tracking & billing.',
            '''# Tiffin Management - Daily Meal & Tiffin Logistics

Simplify meal service subscriptions, route dispatches, and daily meal preferences.

### Key Features:
- Subscription Calendars: Pause, resume, or modify meal deliveries with one tap.
- Kitchen & Route Dispatch: Driver route optimization and kitchen quantity forecasting.
- Automated Monthly Invoicing: Transparent billing, UPI payments, and ledger receipts.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/Signy-App',
            '/Users/manpreet/Desktop/AndroidStudioProjects/Signy-App/androidApp/src/androidMain/res/drawable/app_logo.png',
            'Signy',
            'AI-powered sign language recognition, live translation & learning tool.',
            '''# Signy - Sign Language Interpreter & Interactive Learning

Bridge communication barriers with on-device computer vision and real-time sign language interpretation.

### Key Features:
- Live Camera Translation: Real-time sign-to-text and sign-to-speech translation.
- Interactive Practice Mode: Step-by-step interactive lessons and gesture feedback.
- Offline AI Processing: Private, low-latency inferencing on your mobile device.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/MoonlightWebcam',
            '/Users/manpreet/Desktop/AndroidStudioProjects/MoonlightWebcam/composeApp/src/commonMain/composeResources/drawable/moonlight_logo.png',
            'Moonlight Webcam',
            'Turn your phone into a high-definition, low-latency wireless webcam.',
            '''# Moonlight Webcam - Professional HD Phone Camera Streamer

Stream crisp 1080p/4K video directly to your PC, Mac, or Linux machine over Wi-Fi or USB.

### Key Features:
- Ultra Low Latency: Hardware-accelerated H.264/H.265 video encoding.
- Studio Controls: Manual exposure, white balance, focal lock, and flash assist.
- Multi-OS Compatibility: Works seamlessly with OBS, Zoom, Teams, and Discord.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/STUDIO V4',
            '/Users/manpreet/Desktop/AndroidStudioProjects/STUDIO V4/app/src/main/res/drawable/app_logo.png',
            'STUDIO V4',
            'Professional audio recording, DSP effects & digital audio workstation.',
            '''# STUDIO V4 - Next-Gen Mobile DAW & Sound Lab

Record, mix, and produce pristine audio tracks with studio-grade DSP processing on mobile.

### Key Features:
- Multi-Track Audio Engine: 32-bit floating point audio mixing.
- Parametric EQ & Compression: Pro audio filters and low-latency monitoring.
- High-Res Export: WAV, FLAC, and AAC studio masters.'''
        )
    ]
    
    for p_dir, l_path, a_name, s_desc, f_desc in projects:
        generate_assets(p_dir, l_path, a_name, s_desc, f_desc)
