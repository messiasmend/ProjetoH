#!/usr/bin/env python3
from pathlib import Path
import re

# V9.8 is based on the proven V9.6 flow.
# Do not rebuild or search for artificial V9.7 markers.
# Only move the three existing inspector buttons upward and the two
# custom-filter buttons downward so the GUI has two real rows.

overlay = Path("Sources/PHOverlayManager.m")
s = overlay.read_text(encoding="utf-8")

# The V9.1 layout creates the three existing buttons at the bottom of the
# 430pt panel. Move that complete row upward. Work only inside showPanel.
method_match = re.search(r'(- \(void\)showPanelWithSubtitle:\(NSString \*\)subtitle details:\(NSString \*\)details \{.*?\n\}\n\n- \(void\)showSelectedView:)', s, re.S)
if not method_match:
    raise SystemExit("V9.8: showPanelWithSubtitle method not found")

method = method_match.group(1)
for button in ("hierarchy", "copyButton", "close"):
    pattern = rf'(\[{button}\.(?:bottomAnchor) constraintEqualToAnchor:panel\.bottomAnchor constant:)-20\.0(\])'
    method, n = re.subn(pattern, r'\1-96.0\2', method, count=1)
    if n != 1:
        raise SystemExit(f"V9.8: {button} bottom constraint not found in V9.1/V9.6 layout")

s = s[:method_match.start()] + method + s[method_match.end():]
overlay.write_text(s, encoding="utf-8")

custom = Path("Sources/PHCustomFiltersManager.m")
s = custom.read_text(encoding="utf-8")

# V9.6 creates Ocultar/Ocultos at -54. Keep those exact buttons and move
# only their Y position down to -20 (near the panel bottom).
old = 'h.frame=CGRectMake(MAX(18.0,bounds.size.width-192.0),bounds.size.height-54.0,82.0,30.0);m.frame=CGRectMake(MAX(108.0,bounds.size.width-100.0),bounds.size.height-54.0,82.0,30.0);'
new = 'h.frame=CGRectMake(MAX(18.0,bounds.size.width-192.0),bounds.size.height-20.0,82.0,30.0);m.frame=CGRectMake(MAX(108.0,bounds.size.width-100.0),bounds.size.height-20.0,82.0,30.0);'

if old not in s:
    raise SystemExit("V9.8: V9.6 Ocultar/Ocultos button frames not found")

custom.write_text(s.replace(old, new, 1), encoding="utf-8")
print("Applied V9.8 two-row GUI layout from the V9.6 base")
