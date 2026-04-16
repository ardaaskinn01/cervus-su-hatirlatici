import os
import re

lib_dir = r"c:\Users\ardaa\StudioProjects\suhatirlatici\lib"

# 1. Standard Hex Replacements
hex_replaces = [
    ('0xFF29B6F6', '0xFF0EA5E9'), # Old primary -> New Primary
    ('0xFF0288D1', '0xFF0EA5E9'), # Old primary dark -> New Primary
    ('0xFF4DD0E1', '0xFF38BDF8'), # Old secondary -> New Secondary
    ('0xFFE1F5FE', '0xFFF8FAFC'), # Light sky -> Background
    ('0xFFF4F9F9', '0xFFF8FAFC'), # Old background -> Background
    ('0xFFFAFAFA', '0xFFF8FAFC'), # Another background -> Background
    
    ('0xFF10B981', '0xFF22C55E'), # Success green -> New Accent green
    ('0xFF059669', '0xFF16A34A'), # Dark success green -> Darker Accent green
]

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if not file.endswith('.dart'):
            continue
        filepath = os.path.join(root, file)
        
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        new_content = content
        
        for old, new in hex_replaces:
            new_content = new_content.replace(old, new)
            
        if new_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Hex replaced in {filepath}")

# 2. Specific fixes for home_screen.dart (Separating Primary and Accent)
home_path = os.path.join(lib_dir, 'screens', 'home_screen.dart')
with open(home_path, 'r', encoding='utf-8') as f:
    home_content = f.read()

# Replace the single accentColor with both
home_content = home_content.replace(
    'const accentColor = Color(0xFF0EA5E9);',
    'const primaryColor = Color(0xFF0EA5E9);\n    const accentColor = Color(0xFF22C55E);'
)

# Replace the specific usages in home_screen.dart
home_content = home_content.replace('accentColor.withOpacity(0.08)', 'primaryColor.withOpacity(0.08)')
# _buildWaterCard method signature
home_content = home_content.replace(
    'const accentColor = Color(0xFF0EA5E9);',
    'const primaryColor = Color(0xFF0EA5E9);\n    const accentColor = Color(0xFF22C55E);'
)

# In _buildWaterCard: "isFeatured ? Colors.white : accentColor" -> use primaryColor for non-featured icons
home_content = home_content.replace(
    'color: isFeatured ? Colors.white : accentColor',
    'color: isFeatured ? Colors.white : primaryColor'
)
# Update icon container color
home_content = home_content.replace(
    'accentColor.withOpacity(0.08)',
    'primaryColor.withOpacity(0.08)'
)

with open(home_path, 'w', encoding='utf-8') as f:
    f.write(home_content)

print("Home screen specific replacements done.")
