from pathlib import Path

p = Path("Sources/PHCustomFiltersManager.m")
s = p.read_text(encoding="utf-8")
old = '''    CGRect bounds=host.bounds;UIButton*h=[UIButton buttonWithType:UIButtonTypeSystem];UIButton*m=[UIButton buttonWithType:UIButtonTypeSystem];h.frame=CGRectMake(MAX(18.0,bounds.size.width-192.0),bounds.size.height-54.0,82.0,30.0);m.frame=CGRectMake(MAX(108.0,bounds.size.width-100.0),bounds.size.height-54.0,82.0,30.0);'''
new = '''    CGRect bounds=host.bounds;
    for(UIView*sub in host.subviews.copy){
        if(![sub isKindOfClass:UIButton.class])continue;
        UIButton*b=(UIButton*)sub;NSString*t=[b titleForState:UIControlStateNormal];
        if([t isEqualToString:@"Copiar"]||[t isEqualToString:@"Fechar"]){CGRect r=b.frame;r.origin.y=bounds.size.height-96.0;b.frame=r;}
    }
    UIButton*h=[UIButton buttonWithType:UIButtonTypeSystem];UIButton*m=[UIButton buttonWithType:UIButtonTypeSystem];h.frame=CGRectMake(MAX(18.0,bounds.size.width-192.0),bounds.size.height-54.0,82.0,30.0);m.frame=CGRectMake(MAX(108.0,bounds.size.width-100.0),bounds.size.height-54.0,82.0,30.0);'''
if old not in s:
    raise SystemExit("Expected V9.6 GUI block not found")
p.write_text(s.replace(old, new, 1), encoding="utf-8")
print("Applied V9.6 GUI row spacing fix")
