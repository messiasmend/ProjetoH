#!/usr/bin/env python3
from pathlib import Path

path = Path("Sources/PHOverlayManager.m")
s = path.read_text(encoding="utf-8")

old = '''[hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
            [copyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0]'''

new = '''[hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-64.0],
            [copyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-64.0],
            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-64.0]'''

if old not in s:
    raise SystemExit("Expected V9.7 button constraints not found")

s = s.replace(old, new, 1)
path.write_text(s, encoding="utf-8")
print("Applied V9.8 GUI two-row button layout")
