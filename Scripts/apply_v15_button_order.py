from pathlib import Path

path = Path('Sources/PHOverlayManager.m')
s = path.read_text(encoding='utf-8')

old = '''        [hide.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
        [hide.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],
        [hide.widthAnchor constraintEqualToConstant:100],
        [hidden.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],
        [hidden.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],
        [hidden.widthAnchor constraintEqualToConstant:100],
        [save.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
        [save.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],
        [save.widthAnchor constraintEqualToConstant:100]'''

new = '''        [hidden.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
        [hidden.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],
        [hidden.widthAnchor constraintEqualToConstant:100],
        [hide.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],
        [hide.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],
        [hide.widthAnchor constraintEqualToConstant:100],
        [save.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
        [save.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],
        [save.widthAnchor constraintEqualToConstant:100]'''

if old not in s:
    raise SystemExit('Expected V14 button-layout block was not found; refusing to modify source.')

s = s.replace(old, new, 1)
path.write_text(s, encoding='utf-8')
print('V15 button order applied: Ocultos | Ocultar | Salvar')
