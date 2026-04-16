import os

lib_dir = r"c:\Users\ardaa\StudioProjects\suhatirlatici\lib"

replaces = [
    ('Colors.black87', 'const Color(0xFF0F172A)'),
    ('0xFFF0F8FF', '0xFFF8FAFC'), # Light background
]

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if not file.endswith('.dart'):
            continue
        filepath = os.path.join(root, file)
        
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        new_content = content
        for old, new in replaces:
            new_content = new_content.replace(old, new)
            
        if new_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated {filepath}")
