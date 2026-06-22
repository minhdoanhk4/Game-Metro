import sys

with open(r'c:\Users\msi2k\Documents\FPTU_MATERIAL\PRU\Metro Train\Scenes\HUD.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    # Count quotes
    if line.count('"') % 2 != 0:
        print(f"Unbalanced quote at line {i+1}: {line.strip()}")
    if '[' in line and ']' not in line:
        print(f"Unbalanced bracket at line {i+1}: {line.strip()}")
    if '\\"' in line:
        print(f"Stray backslash-quote at line {i+1}: {line.strip()}")
