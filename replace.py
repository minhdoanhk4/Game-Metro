import re

file_path = "docs/style.css"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace variables
content = content.replace("--bg-color: #050505;", "--bg-color: #0c100a;")
content = content.replace("--text-primary: #f8f9fa;", "--text-primary: #fdfbf7;")
content = content.replace("--text-secondary: #a0aab2;", "--text-secondary: #c9cebd;")
content = content.replace("--accent-glow: #00f0ff;", "--accent-glow: #e8b923;")
content = content.replace("--accent-secondary: #ff003c;", "--accent-secondary: #d33c5e;")
content = content.replace("--glass-bg: rgba(20, 25, 35, 0.4);", "--glass-bg: rgba(20, 30, 20, 0.4);")
content = content.replace("--glass-border: rgba(255, 255, 255, 0.1);", "--glass-border: rgba(232, 185, 35, 0.15);")

# Replace background image
content = content.replace("url('assets/bg.png')", "url('assets/bg_vietnam.png')")

# Replace hardcoded rgb values (0, 240, 255) with golden yellow (232, 185, 35)
content = content.replace("0, 240, 255", "232, 185, 35")

# Update gradient to make it fit Vietnamese style
# From: background: linear-gradient(135deg, var(--accent-glow), #0077ff);
content = content.replace("background: linear-gradient(135deg, var(--accent-glow), #0077ff);", "background: linear-gradient(135deg, var(--accent-glow), #d33c5e);")
content = content.replace("background: linear-gradient(to right, var(--accent-glow), #a200ff);", "background: linear-gradient(to right, var(--accent-glow), #d33c5e);")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
