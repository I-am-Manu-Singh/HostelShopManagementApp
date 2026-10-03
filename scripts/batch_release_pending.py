import os
from PIL import Image

def generate_assets(project_dir, logo_path, app_name, short_desc, full_desc):
    print(f">>> Processing {app_name} in {project_dir}...")
    if not logo_path or not os.path.exists(logo_path):
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

For inquiries, contact: support@{app_name.lower().replace(' ', '').replace('-', '')}.com
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
    pending_projects = [
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/NitnemGuktaSteek',
            '/Users/manpreet/Desktop/AndroidStudioProjects/NitnemGuktaSteek/composeApp/src/commonMain/composeResources/drawable/ic_creative_bliss_labs_logo.png',
            'Nitnem Gutka Steek',
            'Authentic Nitnem Banis with Steek, accurate Roman transliteration & audio.',
            '''# Nitnem Gutka Steek - Sacred Daily Prayers & Steek

Read and listen to Gurbani Nitnem with line-by-line Steek, accurate English and Roman transliterations, and Larivaar support.

### Key Features:
- Daily Nitnem Banis with audio recitation.
- In-depth Viakhya (Steek) translation for deeper spiritual reflection.
- Fully offline mode with customized reading themes and night mode.
- Larivaar and Pad Chhed display options.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniMind',
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniMind/composeApp/src/androidMain/ic_launcher-playstore.png',
            'OmniMind',
            'AI-assisted mind mapping, thought visualization & knowledge synthesis.',
            '''# OmniMind - Mind Mapping & Cognitive Workspace

Synthesize thoughts, structure complex concepts, and build hierarchical visual notes with on-device AI acceleration.

### Key Features:
- Infinite canvas node mapping with bi-directional linking.
- AI concept breakdown and visual outlining.
- Markdown, PDF, and OPML export support.
- Fully private on-device storage with encrypted sync.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniChessReader',
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniChessReader/chess-engine/lichess-mobile-source/ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-ios-marketing.png',
            'OmniChess Reader',
            'Scan physical chessboards, digitize PGN games & analyze with Stockfish.',
            '''# OmniChess Reader - AI Chessboard Scanner & PGN Analyzer

Instant camera recognition of real 2D and 3D chessboards. Convert any physical chess position or book diagram into interactive FEN/PGN.

### Key Features:
- Instant camera chessboard recognition with advanced neural vision.
- Live Stockfish evaluation engine and blunders breakdown.
- Export directly to Lichess, Chess.com, or your local PGN library.
- Book diagram scanning with optical diagram recognition.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-App',
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-App/composeApp/src/androidMain/res/mipmap-xxxhdpi/ic_launcher.png',
            'pEQ Pro Audio',
            'Parametric equalizer, acoustic correction & audiophile sound engine.',
            '''# pEQ Pro Audio - Parametric Equalizer & Acoustic Lab

Master-grade parametric sound processor with multi-band parametric filters, high-pass/low-pass shelving, and headphone correction curves.

### Key Features:
- 10-band true parametric EQ with adjustable Q-factors and center frequencies.
- AutoEq integration with thousands of headphone calibration profiles.
- System-wide audio routing with zero latency DSP engine.
- Floating point internal precision audio pipeline.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-Learn',
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-Learn/composeApp/src/main/res/drawable/app_icon.png',
            'pEQ Learn',
            'Interactive ear training, frequency identification & audio engineering coach.',
            '''# pEQ Learn - Audio Ear Training & Frequency Drills

Train your ears like a professional sound engineer. Learn to pinpoint EQ frequency boosts and cuts with interactive listening quizzes.

### Key Features:
- Systematic frequency ear-training drills across octaves and 1/3 octaves.
- Real-time pink noise, drum bus, and vocal training stems.
- Score analytics and ear agility performance reports.
- Comprehensive sound engineering lessons and acoustics cheat sheets.'''
        ),
        (
            '/Users/manpreet/Desktop/ReactNativeProjects/LyftRide',
            '/Users/manpreet/Desktop/ReactNativeProjects/LyftRide/assets/splash-icon.png',
            'LyftRide Mobility',
            'Effortless campus & city rides, on-demand cabs and shared commutes.',
            '''# LyftRide Mobility - Real-Time Ride Hailing & Commute

Book cabs, auto-rickshaws, and campus shared shuttles with transparent fares and real-time GPS tracking.

### Key Features:
- 1-tap ride booking with upfront pricing.
- Live vehicle location tracking and SOS safety features.
- Multi-stop route planning and corporate billing support.
- Cashless wallet, UPI, and card payments.'''
        )
    ]
    
    for p_dir, l_path, a_name, s_desc, f_desc in pending_projects:
        generate_assets(p_dir, l_path, a_name, s_desc, f_desc)
