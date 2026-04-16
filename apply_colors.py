import os
import re

lib_dir = r"c:\Users\ardaa\StudioProjects\suhatirlatici\lib"

def replace_in_file(filepath, pattern_replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content
    for pattern, repl in pattern_replacements:
        new_content = re.sub(pattern, repl, new_content)
        
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

# main.dart updates
replace_in_file(os.path.join(lib_dir, 'main.dart'), [
    (r'0xFF29B6F6', '0xFF0EA5E9'),
    (r'0xFFF4F9F9', '0xFFF8FAFC'),
    (r'0xFF4DD0E1', '0xFF38BDF8'),
])

# splash_screen.dart updates
replace_in_file(os.path.join(lib_dir, 'screens', 'splash_screen.dart'), [
    (r'0xFFE1F5FE', '0xFFF8FAFC'),
    (r'0xFF29B6F6', '0xFF0EA5E9'),
    (r'0xFF0288D1', '0xFF0EA5E9'),
])

# home_screen.dart updates
replace_in_file(os.path.join(lib_dir, 'screens', 'home_screen.dart'), [
    (r'const accentColor = Color\(0xFF0EA5E9\);', 'const primaryColor = Color(0xFF0EA5E9);\n    const accentColor = Color(0xFF22C55E);'),
    # Use primary for glow, water drop icons, wave etc. Keep accent for "featured" (Add button).
    (r'accentColor\.withOpacity\(0\.08\)', 'primaryColor.withOpacity(0.08)'),
    (r'isFeatured \? accentColor : Colors\.white', 'isFeatured ? accentColor : Colors.white'),
    (r'isFeatured \? accentColor : const Color\(0xFFE2E8F0\)', 'isFeatured ? accentColor : const Color(0xFFE2E8F0)'),
    (r'isFeatured \? accentColor\.withOpacity\(0\.25\)', 'isFeatured ? accentColor.withOpacity(0.25)'),
    (r'isFeatured \? Colors\.white \: accentColor', 'isFeatured ? Colors.white : primaryColor'),
    (r'backgroundColor\: const Color\(0xFF0EA5E9\)', 'backgroundColor: const Color(0xFF22C55E)'), # Add dialog button
])

print("Replacements complete.")
