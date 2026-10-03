import os
from PIL import Image

def update_peq_icons(proj_dir, new_logo_path):
    print(f">>> Updating icons for {proj_dir}...")
    img = Image.open(new_logo_path).convert('RGBA')
    
    # 1. Update playstore icon_512
    ps_dir = os.path.join(proj_dir, 'playstore')
    os.makedirs(ps_dir, exist_ok=True)
    img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(ps_dir, 'icon_512.png'), 'PNG')
    
    # 2. Update all mipmaps
    mipmap_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for root, dirs, _ in os.walk(proj_dir):
        if 'build' in root or '.gradle' in root or 'node_modules' in root:
            continue
        if os.path.basename(root) == 'res':
            for folder, sz in mipmap_sizes.items():
                t_dir = os.path.join(root, folder)
                os.makedirs(t_dir, exist_ok=True)
                resized = img.resize((sz, sz), Image.Resampling.LANCZOS)
                resized.save(os.path.join(t_dir, 'ic_launcher.png'), 'PNG')
                resized.save(os.path.join(t_dir, 'ic_launcher_round.png'), 'PNG')
                
    # 3. Update common drawables
    for root, dirs, files in os.walk(proj_dir):
        if 'build' in root or '.gradle' in root:
            continue
        for f in files:
            if f in ['app_icon.png', 'app_logo.png']:
                full = os.path.join(root, f)
                img.save(full, 'PNG')
                print('Replaced internal drawable:', full)

if __name__ == '__main__':
    peq_app_logo = '/Users/manpreet/.gemini/antigravity-ide/brain/d83b0ea4-cb8a-4a7a-a6fb-4cdabe3c0941/peq_app_simple_logo_1791047605891.jpg'
    peq_learn_logo = '/Users/manpreet/.gemini/antigravity-ide/brain/d83b0ea4-cb8a-4a7a-a6fb-4cdabe3c0941/peq_learn_simple_logo_1791047627493.jpg'
    
    update_peq_icons('/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-App', peq_app_logo)
    update_peq_icons('/Users/manpreet/Desktop/AndroidStudioProjects/pEQ-Learn', peq_learn_logo)
    print("SUCCESS: Icons updated for pEQ-App and pEQ-Learn.")
