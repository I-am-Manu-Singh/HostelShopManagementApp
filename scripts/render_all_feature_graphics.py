import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

def render_rich_feature_graphic(project_dir, app_name, tagline, theme_accent, theme_bg, logo_path=None):
    ps_dir = os.path.join(project_dir, 'playstore')
    os.makedirs(ps_dir, exist_ok=True)
    out_path = os.path.join(ps_dir, 'feature_graphic.png')
    
    # 1024x500 Google Play standard
    W, H = 1024, 500
    base = Image.new('RGBA', (W, H), theme_bg)
    draw = ImageDraw.Draw(base)
    
    # Create stylish background gradient glow / ambient lighting
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Left ambient glow circle
    glow_draw.ellipse([80, 50, 480, 450], fill=(theme_accent[0], theme_accent[1], theme_accent[2], 40))
    # Right accent glow
    glow_draw.ellipse([650, 80, 950, 380], fill=(theme_accent[0], theme_accent[1], theme_accent[2], 25))
    glow = glow.filter(ImageFilter.GaussianBlur(50))
    base = Image.alpha_composite(base, glow)
    draw = ImageDraw.Draw(base)
    
    # Subtle modern grid/mesh lines
    for x in range(0, W, 80):
        draw.line([(x, 0), (x, H)], fill=(255, 255, 255, 6), width=1)
    for y in range(0, H, 80):
        draw.line([(0, y), (W, y)], fill=(255, 255, 255, 6), width=1)
        
    # App Icon with circular elevation & border
    icon_sz = 220
    icon_x = 90
    icon_y = (H - icon_sz) // 2
    
    if logo_path and os.path.exists(logo_path):
        try:
            raw_logo = Image.open(logo_path).convert('RGBA')
            resized_logo = raw_logo.resize((icon_sz, icon_sz), Image.Resampling.LANCZOS)
            
            # Mask to circle
            mask = Image.new('L', (icon_sz, icon_sz), 0)
            mask_draw = ImageDraw.Draw(mask)
            mask_draw.ellipse([0, 0, icon_sz, icon_sz], fill=255)
            
            # Outer glowing ring
            ring_pad = 12
            draw.ellipse(
                [icon_x - ring_pad, icon_y - ring_pad, icon_x + icon_sz + ring_pad, icon_y + icon_sz + ring_pad],
                outline=(theme_accent[0], theme_accent[1], theme_accent[2], 180),
                width=3
            )
            # Inner background container
            draw.ellipse(
                [icon_x, icon_y, icon_x + icon_sz, icon_y + icon_sz],
                fill=(20, 25, 40, 255)
            )
            base.paste(resized_logo, (icon_x, icon_y), mask)
        except Exception as e:
            print(f'Error pasting logo for {app_name}: {e}')
    
    # Render typography and pills
    # Pill Badge: "OFFICIAL RELEASE"
    pill_x = 380
    pill_y = 120
    pill_w = 190
    pill_h = 32
    draw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=16, fill=(theme_accent[0], theme_accent[1], theme_accent[2], 40), outline=(theme_accent[0], theme_accent[1], theme_accent[2], 150), width=1)
    
    # We use default font or bitmap font for portability
    try:
        font_large = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 46)
        font_sub = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 21)
        font_pill = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 13)
    except:
        font_large = font_sub = font_pill = ImageFont.load_default()
        
    draw.text((pill_x + 18, pill_y + 8), "★ PRODUCTION RELEASE", font=font_pill, fill=(theme_accent[0], theme_accent[1], theme_accent[2], 255))
    draw.text((pill_x, 175), app_name, font=font_large, fill=(255, 255, 255, 255))
    
    # Word wrap tagline
    words = tagline.split(' ')
    line1 = []
    line2 = []
    for w in words:
        if len(' '.join(line1 + [w])) <= 44:
            line1.append(w)
        else:
            line2.append(w)
            
    draw.text((pill_x, 245), ' '.join(line1), font=font_sub, fill=(200, 210, 230, 240))
    if line2:
        draw.text((pill_x, 275), ' '.join(line2), font=font_sub, fill=(200, 210, 230, 240))
        
    # Feature checklist pill footer
    draw.rounded_rectangle([pill_x, 340, pill_x + 560, 395], radius=12, fill=(255, 255, 255, 12), outline=(255, 255, 255, 30))
    draw.text((pill_x + 20, 355), "⚡ High Performance  •  🔒 Privacy First  •  📱 Multi-Device Ready", font=font_sub, fill=(240, 240, 250, 220))
    
    base.convert('RGB').save(out_path, 'PNG', quality=95)
    print(f"  [SUCCESS] Rendered feature_graphic.png for {app_name}")

if __name__ == '__main__':
    all_apps = [
        (
            '/Users/manpreet/Desktop/FlutterProjects/HostelShopManagementApp',
            'Hostel & Campus Mart',
            'All-in-one hostel living, room allocation, mess & automated store POS billing.',
            (79, 70, 229), (13, 17, 28, 255),
            '/Users/manpreet/Desktop/FlutterProjects/HostelShopManagementApp/assets/images/app_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/FlutterProjects/TrekBookingApp',
            'Trek Booking App',
            'Discover expeditions, certified mountain guides & offline survival trails.',
            (16, 185, 129), (10, 26, 20, 255),
            '/Users/manpreet/Desktop/FlutterProjects/TrekBookingApp/app_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/ReactNativeProjects/MedHome',
            'MedHome Healthcare',
            'Doorstep doctor visits, electronic prescriptions & lab tests at home.',
            (14, 165, 233), (12, 24, 36, 255),
            '/Users/manpreet/Desktop/ReactNativeProjects/MedHome/assets/icon.png'
        ),
        (
            '/Users/manpreet/Desktop/ReactNativeProjects/MerchantApp',
            'Merchant POS Command',
            'High-speed barcode scanner billing, live inventory & customer ledger.',
            (245, 158, 11), (26, 20, 10, 255),
            '/Users/manpreet/Desktop/ReactNativeProjects/MerchantApp/assets/images/icon.png'
        ),
        (
            '/Users/manpreet/Desktop/ReactNativeProjects/LyftRide',
            'LyftRide Mobility',
            'Real-time cab booking, campus shuttles & transparent commuter fares.',
            (236, 72, 153), (28, 12, 22, 255),
            '/Users/manpreet/Desktop/ReactNativeProjects/LyftRide/assets/splash-icon.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/NitnemGuktaSteek',
            'Nitnem Gutka Steek',
            'Sacred Gurbani prayers with line-by-line Steek, audio & Roman transliteration.',
            (234, 179, 8), (24, 18, 8, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/NitnemGuktaSteek/composeApp/src/commonMain/composeResources/drawable/ic_creative_bliss_labs_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/TiffinManagement',
            'Tiffin Meal Logistics',
            'Automate daily meal subscriptions, driver route dispatch & transparent billing.',
            (249, 115, 22), (28, 16, 10, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/TiffinManagement/composeApp/src/commonMain/composeResources/drawable/app_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/Signy-App',
            'Signy AI Interpreter',
            'Real-time sign language recognition, live camera translation & lessons.',
            (99, 102, 241), (14, 16, 32, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/Signy-App/androidApp/src/androidMain/res/drawable/app_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniMind',
            'OmniMind Visual Notes',
            'AI-assisted mind mapping, concept visualization & infinite cognitive canvas.',
            (168, 85, 247), (20, 12, 32, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniMind/composeApp/src/androidMain/ic_launcher-playstore.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniChessReader',
            'OmniChess Reader',
            'Scan physical chessboards, convert to FEN/PGN & analyze with Stockfish.',
            (14, 165, 233), (10, 20, 30, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/OmniChessReader/chess-engine/lichess-mobile-source/ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-ios-marketing.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-App',
            'pEQ Pro Audio Studio',
            'Parametric equalizer, acoustic correction & audiophile 10-band DSP.',
            (20, 184, 166), (10, 26, 26, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-App/composeApp/src/androidMain/res/mipmap-xxxhdpi/ic_launcher.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-Learn',
            'pEQ Audio Ear Trainer',
            'Interactive sound frequency ear training & audio engineering drills.',
            (234, 179, 8), (26, 22, 10, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-Learn/composeApp/src/main/res/drawable/app_icon.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/STUDIO V4',
            'STUDIO V4 Audio Lab',
            'Multi-track mobile DAW, studio effects, 32-bit float audio recorder.',
            (239, 68, 68), (30, 12, 14, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/STUDIO V4/app/src/main/res/drawable/app_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/MoonlightWebcam',
            'Moonlight HD Webcam',
            'Turn your phone into an ultra low-latency 4K wireless webcam for PC/Mac.',
            (99, 102, 241), (14, 16, 32, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/MoonlightWebcam/composeApp/src/commonMain/composeResources/drawable/moonlight_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/WearProductivityApp',
            'Wear OS Productivity',
            'Smartwatch focus timer, daily micro-tasks, wrist complications & habits.',
            (6, 182, 212), (10, 24, 30, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/WearProductivityApp/wear_logo.png'
        ),
        (
            '/Users/manpreet/Desktop/AndroidStudioProjects/nux-mg-101-quick-tone',
            'QuickTone Guitar Lab',
            'Wireless patch editor, IR cabinet loader & tone manager for NUX MG-101.',
            (249, 115, 22), (28, 16, 10, 255),
            '/Users/manpreet/Desktop/AndroidStudioProjects/nux-mg-101-quick-tone/quick_tone_logo.png'
        )
    ]
    
    for p_dir, a_name, tag, acc, bg, l_path in all_apps:
        render_rich_feature_graphic(p_dir, a_name, tag, acc, bg, l_path)
