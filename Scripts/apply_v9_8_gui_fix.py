#!/usr/bin/env python3
from pathlib import Path
import re

# V9.8 keeps the proven V9.6 flow and only fixes the final GUI arrangement.
# Row 1: Hierarquia / Copiar / Fechar.
# Row 2: Ocultar / Ocultos.
# Both rows stay inside the 350x430 inspector panel.

overlay = Path("Sources/PHOverlayManager.m")
s = overlay.read_text(encoding="utf-8")

method_match = re.search(r'(- \(void\)showPanelWithSubtitle:\(NSString \*\)subtitle details:\(NSString \*\)details \{.*?\n\}\n\n- \(void\)showSelectedView:)', s, re.S)
if not method_match:
    raise SystemExit("V9.8: showPanelWithSubtitle method not found")

method = method_match.group(1)
for button in ("hierarchy", "copyButton", "close"):
    pattern = rf'(\[{button}\.(?:bottomAnchor) constraintEqualToAnchor:panel\.bottomAnchor constant:)-20\.0(\])'
    method, n = re.subn(pattern, r'\1-96.0\2', method, count=1)
    if n != 1:
        raise SystemExit(f"V9.8: {button} bottom constraint not found")

s = s[:method_match.start()] + method + s[method_match.end():]
overlay.write_text(s, encoding="utf-8")

custom = Path("Sources/PHCustomFiltersManager.m")
s = custom.read_text(encoding="utf-8")

# Keep the V9.6 second-row position: the custom buttons remain 54pt above
# the panel bottom, below the existing inspector row at -96pt.
if 'bounds.size.height-54.0,82.0,30.0' not in s:
    raise SystemExit("V9.8: V9.6 Ocultar/Ocultos row not found")

# Normalize filter entries before the UI reads them. Some existing
# custom-filters.json entries can have selector in action.selector or can be
# plain selector strings; treating those as dictionaries prevents '(null)'
# button titles in the hidden-elements dialog.
old_load = r'''static NSMutableArray\*PHLoad\(void\)\{.*?\n\}'''
new_load = '''static NSString*PHSelectorFromFilter(id f){
    if([f isKindOfClass:NSString.class]) return [(NSString*)f length] ? (NSString*)f : nil;
    if(![f isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary*d=(NSDictionary*)f;
    id s=d[@"selector"];
    if([s isKindOfClass:NSString.class]&&[(NSString*)s length]) return (NSString*)s;
    id action=d[@"action"];
    if([action isKindOfClass:NSDictionary.class]){
        id as=action[@"selector"];
        if([as isKindOfClass:NSString.class]&&[(NSString*)as length]) return (NSString*)as;
    }
    for(NSString*k in @[@"filter",@"rule",@"data",@"payload"]){
        NSString*nested=PHSelectorFromFilter(d[k]);
        if(nested.length) return nested;
    }
    return nil;
}
static NSMutableArray*PHLoad(void){
    NSData*d=[NSData dataWithContentsOfFile:PHPath()];
    if(!d)return[NSMutableArray array];
    id j=[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil];
    if([j isKindOfClass:NSDictionary.class])j=j[@"filters"];
    if(![j isKindOfClass:NSArray.class])return[NSMutableArray array];
    NSMutableArray*out=[NSMutableArray array];
    for(id f in (NSArray*)j){
        NSString*selector=PHSelectorFromFilter(f);
        if(!selector.length)continue;
        if([f isKindOfClass:NSDictionary.class]&&[f[@"selector"] isKindOfClass:NSString.class]&&[f[@"selector"] length])
            [out addObject:f];
        else
            [out addObject:@{@"selector":selector}];
    }
    return out;
}'''
s2, n = re.subn(old_load, new_load, s, count=1, flags=re.S)
if n != 1:
    raise SystemExit("V9.8: PHLoad block not found")
s = s2
custom.write_text(s, encoding="utf-8")
print("Applied V9.8 GUI: row 1 at -96, Ocultar/Ocultos at -54, and normalized hidden-filter names")
