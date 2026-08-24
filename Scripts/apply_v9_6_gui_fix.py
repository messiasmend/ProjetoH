from pathlib import Path
import re

p = Path("Sources/PHCustomFiltersManager.m")
s = p.read_text(encoding="utf-8")

# The V9.8 flow may run this compatibility step against a source that already
# contains the V9.6 layout. In that case there is nothing to patch and the
# build must continue instead of failing on an exact-text anchor.
if 'bounds.size.height-96.0,82.0,30.0' in s and 'bounds.size.height-54.0,82.0,30.0' in s:
    print("V9.6 GUI row spacing already applied")
else:
    pattern = re.compile(
        r'CGRect bounds=host\.bounds;'
        r'UIButton\*h=\[UIButton buttonWithType:UIButtonTypeSystem\];'
        r'UIButton\*m=\[UIButton buttonWithType:UIButtonTypeSystem\];'
        r'h\.frame=CGRectMake\(MAX\(18\.0,bounds\.size\.width-192\.0\),bounds\.size\.height-54\.0,82\.0,30\.0\);'
        r'm\.frame=CGRectMake\(MAX\(108\.0,bounds\.size\.width-100\.0\),bounds\.size\.height-54\.0,82\.0,30\.0\);'
    )
    replacement = (
        'CGRect bounds=host.bounds;'
        'for(UIView*sub in host.subviews.copy){'
        'if(![sub isKindOfClass:UIButton.class])continue;'
        'UIButton*b=(UIButton*)sub;NSString*t=[b titleForState:UIControlStateNormal];'
        'if([t isEqualToString:@"Copiar"]||[t isEqualToString:@"Fechar"]){'
        'CGRect r=b.frame;r.origin.y=bounds.size.height-96.0;b.frame=r;}'
        '}'
        'UIButton*h=[UIButton buttonWithType:UIButtonTypeSystem];'
        'UIButton*m=[UIButton buttonWithType:UIButtonTypeSystem];'
        'h.frame=CGRectMake(MAX(18.0,bounds.size.width-192.0),bounds.size.height-54.0,82.0,30.0);'
        'm.frame=CGRectMake(MAX(108.0,bounds.size.width-100.0),bounds.size.height-54.0,82.0,30.0);'
    )
    s2, n = pattern.subn(replacement, s, count=1)
    if n != 1:
        raise SystemExit("V9.6 GUI block not found in supported source layout")
    s = s2
    p.write_text(s, encoding="utf-8")
    print("Applied V9.6 GUI row spacing fix")
