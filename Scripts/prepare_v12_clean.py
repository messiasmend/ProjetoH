from pathlib import Path
import re, subprocess

BASE='96953d9b1f6dbc9d55567d8a4b6e53c6c47dd502'
p=Path('Sources/PHOverlayManager.m')

# GitHub Actions uses a shallow checkout. Fetch the exact known-good V9.6
# source commit before restoring PHOverlayManager.m from it.
subprocess.run(['git','fetch','--no-tags','origin',BASE],check=True)
subprocess.run(['git','checkout',BASE,'--',str(p)],check=True)
s=p.read_text(encoding='utf-8')

def rep(pattern,repl,label):
    global s
    s,n=re.subn(pattern,repl,s,count=1,flags=re.S)
    if n!=1: raise SystemExit(f'{label}: expected 1 match, got {n}')

# Add only the V12 persistence helpers and keep the known-good GUI as the base.
rep(r'static NSString \*PHFilterPath\(void\) \{.*?\n\}\n\nstatic NSMutableArray \*PHLoadFilters',r'''static NSString *PHFilterPath(void) {
    static NSString *cachedPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *documents=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/custom-filters.json"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:documents]) { cachedPath=documents; return; }
        NSString *home=NSHomeDirectory(); NSDirectoryEnumerator *e=[NSFileManager.defaultManager enumeratorAtPath:home]; NSString *relative=nil;
        while ((relative=[e nextObject])) if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) { cachedPath=[home stringByAppendingPathComponent:relative]; break; }
        if (!cachedPath.length) cachedPath=documents;
    });
    return cachedPath;
}
static NSString *PHSelectorFromFilter(id filter) {
    if (![filter isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *action=filter[@"action"];
    NSString *selector=[action isKindOfClass:NSDictionary.class]?action[@"selector"]:filter[@"selector"];
    return ([selector isKindOfClass:NSString.class]&&selector.length)?selector:nil;
}
static NSString *PHDisplayNameForSelector(NSString *selector) {
    if (!selector.length) return @"Elemento oculto";
    if ([selector rangeOfString:@"lottie-player" options:NSCaseInsensitiveSearch].location!=NSNotFound) return @"Lottie Player";
    if ([selector hasPrefix:@"#"]) return [NSString stringWithFormat:@"Elemento %@",selector];
    if ([selector hasPrefix:@"."]) return [NSString stringWithFormat:@"Elemento %@",[[selector componentsSeparatedByString:@" "] firstObject]];
    NSString *last=[[selector componentsSeparatedByString:@" > "] lastObject]?:selector;
    NSRange r=[last rangeOfString:@":"]; if(r.location!=NSNotFound) last=[last substringToIndex:r.location];
    return last.length?[NSString stringWithFormat:@"Elemento <%@>",last]:@"Elemento oculto";
}
static NSMutableArray *PHLoadFilters''','filter helpers')

rep(r'static NSMutableArray \*PHLoadFilters\(void\) \{.*?\n\}\n\nstatic BOOL PHWriteFilters',r'''static NSMutableArray *PHLoadFilters(void) {
    NSData *data=[NSData dataWithContentsOfFile:PHFilterPath()]; if(!data) return [NSMutableArray array];
    id json=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if([json isKindOfClass:NSDictionary.class]) json=json[@"filters"];
    return [json isKindOfClass:NSArray.class]?[json mutableCopy]:[NSMutableArray array];
}
static BOOL PHWriteFilters''','load')

rep(r'static BOOL PHWriteFilters\(NSArray \*filters\) \{.*?\n\}\n\nstatic NSString \*PHSelectorsJSON',r'''static BOOL PHWriteFilters(NSArray *filters) {
    NSString *path=PHFilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data=[NSJSONSerialization dataWithJSONObject:filters?:@[] options:NSJSONWritingPrettyPrinted error:nil];
    return data&&[data writeToFile:path atomically:YES];
}
static NSString *PHSelectorsJSON''','write')

# Add a small persistent ownership store; the known-good V9.6 GUI itself is not replaced here.
s=s.replace('static NSMutableArray<NSString *> *PHPendingSelectors = nil;\nstatic NSTimer *PHApplyTimer = nil;', '''static NSMutableArray<NSString *> *PHPendingSelectors=nil;
static NSTimer *PHApplyTimer=nil;
static NSMutableArray<NSString *> *PHSavedSelectors(void){ NSArray *a=[[NSUserDefaults standardUserDefaults] arrayForKey:@"ProjetoH.SavedSelectors"]; return a?[a mutableCopy]:[NSMutableArray array]; }
static void PHStoreSavedSelectors(NSArray *a){ [[NSUserDefaults standardUserDefaults] setObject:a?:@[] forKey:@"ProjetoH.SavedSelectors"]; }''',1)

p.write_text(s,encoding='utf-8')
print('V12 clean source prepared from known-good V9.6 commit')
