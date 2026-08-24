#!/usr/bin/env python3
from pathlib import Path
import re

# V9.8 is intentionally minimal and is based on the proven V9.6 flow.
# V9.6 already places Copiar/Fechar on the upper row and Ocultar/Ocultos
# on the lower row. The only remaining change is to move Hierarquia to
# that same upper row.

overlay = Path("Sources/PHOverlayManager.m")
s = overlay.read_text(encoding="utf-8")

method_match = re.search(
    r'(- \(void\)showPanelWithSubtitle:\(NSString \*\)subtitle details:\(NSString \*\)details \{.*?\n\}\n\n- \(void\)showSelectedView:)',
    s,
    re.S,
)
if not method_match:
    raise SystemExit("V9.8: showPanelWithSubtitle method not found")

method = method_match.group(1)
pattern = r'(\[hierarchy\.bottomAnchor constraintEqualToAnchor:panel\.bottomAnchor constant:)-20\.0(\])'
method, n = re.subn(pattern, r'\1-96.0\2', method, count=1)
if n != 1:
    raise SystemExit("V9.8: Hierarquia bottom constraint not found")

s = s[:method_match.start()] + method + s[method_match.end():]
overlay.write_text(s, encoding="utf-8")
print("Applied V9.8 minimal GUI fix: Hierarquia moved to the V9.6 upper row")
