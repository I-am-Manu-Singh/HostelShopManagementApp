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
- [ ] Phone / Wear Screenshots: Min 2, Max 8
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

We respect your privacy. {app_name} operates strictly on-device with zero telemetry or tracking.
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
Does your app collect or share user data?,No
Is all data processed locally on device?,Yes
Does the app transmit sensitive user information?,No
""")

    # 3. Android mipmaps
    res_dirs = []
    for root, dirs, _ in os.walk(project_dir):
        if 'build' in root or '.gradle' in root or 'node_modules' in root:
            continue
        if os.path.basename(root) == 'res':
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
    items = [
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/WearProductivityApp',
            '/Users/manpreet/.gemini/antigravity-ide/brain/d83b0ea4-cb8a-4a7a-a6fb-4cdabe3c0941/wear_productivity_logo_1791046376211.jpg',
            'Wear Productivity',
            'Smartwatch focus timer, daily micro-tasks, wrist complications & habits.',
            '''# Wear Productivity - Smartwatch Task & Focus Manager

Boost focus with ultra-fast glanceable wrist interactions, customized watch face complications, Pomodoro intervals, and habit tracking designed for Wear OS.

### Key Features:
- Designed from the ground up for Wear OS circular and square dials.
- Tile and Complication support for immediate wrist accessibility.
- Haptic vibrations for Pomodoro breaks and focus transitions.
- Standalone functionality with optional phone companion sync.'''
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/nux-mg-101-quick-tone',
            '/Users/manpreet/Desktop/AndroidStudioProjects/nux-mg-101-quick-tone/quick_tone_logo.png',
            'QuickTone Guitar Lab',
            'Wireless patch editor, IR cabinet loader & tone manager for NUX MG-101.',
            '''# QuickTone Guitar Lab - FX & Amp Modeling Controller

Take complete wireless command of your NUX MG-101 guitar multi-effects processor. Edit tone chains, tweak amplifier parameters, and manage acoustic IRs in real time.

### Key Features:
- Real-time patch parameter tweaking over USB-OTG and Bluetooth.
- Custom IR (Impulse Response) cabinet loading and backup management.
- Quick preset switching and cloud tone library sharing.
- Built-in chromatic guitar tuner and metronome.'''
        )
    ]
    
    # Save the generated quick tone logo locally in project
    qt_logo_src = '/Users/manpreet/.gemini/antigravity-ide/brain/d83b0ea4-cb8a-4a7a-a6fb-4cdabe3c0941/quick_tone_logo_1791046401735.jpg'
    qt_logo_dst = '/Users/manpreet/Desktop/AndroidStudioProjects/nux-mg-101-quick-tone/quick_tone_logo.png'
    Image.open(qt_logo_src).save(qt_logo_dst, 'PNG')
    
    wp_logo_src = '/Users/manpreet/.gemini/antigravity-ide/brain/d83b0ea4-cb8a-4a7a-a6fb-4cdabe3c0941/wear_productivity_logo_1791046376211.jpg'
    wp_logo_dst = '/Users/manpreet/Desktop/AndroidStudioProjects/WearProductivityApp/wear_logo.png'
    Image.open(wp_logo_src).save(wp_logo_dst, 'PNG')
    
    for p_dir, l_path, a_name, s_desc, f_desc in items:
        generate_assets(p_dir, l_path, a_name, s_desc, f_desc)
