#!/usr/bin/env python3
from pathlib import Path

# V9.8: keep the proven V9.6 base and only separate the two button rows.
# Row 1 (inside PHOverlayManager): Hierarquia / Copiar / Fechar
# Row 2 (inside PHCustomFiltersManager): Ocultar / Ocultos

overlay = Path("Sources/PHOverlayManager.m")
s = overlay.read_text(encoding="utf-8")

old_overlay = '''[hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
            [copyButton.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
            [copyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0]'''

new_overlay = '''[hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-64.0],
            [copyButton.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
            [copyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-64.0],
            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-64.0]'''

if old_overlay not in s:
    raise SystemExit("Expected V9.8 PHOverlayManager button constraints not found")

overlay.write_text(s.replace(old_overlay, new_overlay, 1), encoding="utf-8")

custom = Path("Sources/PHCustomFiltersManager.m")
s = custom.read_text(encoding="utf-8")

old_custom = '''h.frame=CGRectMake(MAX(18.0,bounds.size.width-192.0),bounds.size.height-54.0,82.0,30.0);m.frame=CGRectMake(MAX(108.0,bounds.size.width-100.0),bounds.size.height-54.0,82.0,30.0);'''

new_custom = '''h.frame=CGRectMake(MAX(18.0,bounds.size.width-192.0),bounds.size.height-20.0,82.0,30.0);m.frame=CGRectMake(MAX(108.0,bounds.size.width-100.0),bounds.size.height-20.0,82.0,30.0);'''

if old_custom not in s:
    raise SystemExit("Expected V9.6 Ocultar/Ocultos button frames not found")

custom.write_text(s.replace(old_custom, new_custom, 1), encoding="utf-8")
print("Applied V9.8 GUI two-row button layout")
