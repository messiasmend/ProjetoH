from pathlib import Path
import re

p=Path('Sources/PHOverlayManager.m')
s=p.read_text(encoding='utf-8')

# WebFrame path: Documents first.
s=re.sub(r'static NSString \*PHFilterPath\(void\) \{.*?\n\}\n\nstatic NSMutableArray \*PHLoadFilters', '''static NSString *PHFilterPath(void) {
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *home = NSHomeDirectory();
        NSString *documents = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:documents]) { path = documents; return; }
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *r = nil;
        while ((r = [e nextObject])) if ([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) { path = [home stringByAppendingPathComponent:r]; break; }
        if (!path.length) path = documents;
    });
    return path;
}

static NSString *PHSelectorFromFilter(id f) {
    if (![f isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *a=f[@"action"];
    NSString *s=[a isKindOfClass:NSDictionary.class]?a[@"selector"]:f[@"selector"];
    return [s isKindOfClass:NSString.class]&&s.length?s:nil;
}

static NSString *PHDisplayNameForSelector(NSString *s) {
    if (!s.length) return @"Elemento oculto";
    if ([s rangeOfString:@"lottie-player" options:NSCaseInsensitiveSearch].location!=NSNotFound) return @"Lottie Player";
    if ([s hasPrefix:@"#"]) return [NSString stringWithFormat:@"Elemento %@",s];
    if ([s hasPrefix:@"."]) return [NSString stringWithFormat:@"Elemento %@",s.componentsSeparatedByString:@" "][0];
    NSArray *parts=[s componentsSeparatedByString:@" > "]; NSString *last=parts.lastObject?:s; NSRange r=[last rangeOfString:@":"]; if(r.location!=NSNotFound) last=[last substringToIndex:r.location];
    return last.length?[NSString stringWithFormat:@"Elemento <%@>",last]:@"Elemento oculto";
}

static NSMutableArray *PHLoadFilters''',s,flags=re.S)

# Preserve raw existing rules and write a top-level array.
s=re.sub(r'static NSMutableArray \*PHLoadFilters\(void\) \{.*?\n\}\n\nstatic BOOL PHWriteFilters', '''static NSMutableArray *PHLoadFilters(void) {
    NSData *d=[NSData dataWithContentsOfFile:PHFilterPath()]; if(!d) return [NSMutableArray array];
    id j=[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil];
    if([j isKindOfClass:NSDictionary.class]&&[j[@"filters"] isKindOfClass:NSArray.class]) j=j[@"filters"];
    return [j isKindOfClass:NSArray.class]?[j mutableCopy]:[NSMutableArray array];
}

static BOOL PHWriteFilters''',s,flags=re.S)
s=re.sub(r'static BOOL PHWriteFilters\(NSArray \*filters\) \{.*?\n\}\n\nstatic NSString \*PHSelectorsJSON', '''static BOOL PHWriteFilters(NSArray *filters) {
    NSString *path=PHFilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableArray *out=[NSMutableArray array];
    for(id f in filters?:@[]) if([f isKindOfClass:NSDictionary.class]&&[NSJSONSerialization isValidJSONObject:f]) [out addObject:f];
    NSData *d=[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
    return d&&[d writeToFile:path atomically:YES];
}

static NSString *PHSelectorsJSON''',s,flags=re.S)

# Ownership store.
s=s.replace('static NSTimer *PHApplyTimer = nil;', '''static NSTimer *PHApplyTimer = nil;
static NSMutableArray<NSString *> *PHSavedSelectors(void) {
    NSArray *a=[[NSUserDefaults standardUserDefaults] arrayForKey:@"ProjetoH.SavedSelectors"];
    return a?[a mutableCopy]:[NSMutableArray array];
}
static void PHStoreSavedSelectors(NSArray *a) {
    [[NSUserDefaults standardUserDefaults] setObject:a?:@[] forKey:@"ProjetoH.SavedSelectors"];
}''',1)

# Save confirmation + WebFrame rule.
start=s.index('- (void)savePendingFilters {'); end=s.index('- (void)showHiddenElements {',start)
s=s[:start]+'''- (void)savePendingFilters {
    if(!PHPendingSelectors.count)return;
    UIAlertController *c=[UIAlertController alertControllerWithTitle:@"Salvar alterações?" message:[NSString stringWithFormat:@"%lu elemento(s) serão gravado(s) permanentemente no custom-filters.json.",(unsigned long)PHPendingSelectors.count] preferredStyle:UIAlertControllerStyleAlert];
    [c addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [c addAction:[UIAlertAction actionWithTitle:@"Salvar" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        NSMutableArray *f=PHLoadFilters();
        for(NSString *s in PHPendingSelectors){BOOL e=NO;for(id x in f)if([[PHSelectorFromFilter(x)?:@""] isEqualToString:s]){e=YES;break;}if(!e)[f addObject:@{@"trigger":@{@"url-filter":@".*"},@"action":@{@"type":@"css-display-none",@"selector":s}}];}
        if(!PHWriteFilters(f))return; NSMutableArray *saved=PHSavedSelectors();for(NSString *s in PHPendingSelectors)if(![saved containsObject:s])[saved addObject:s];PHStoreSavedSelectors(saved);[PHPendingSelectors removeAllObjects];[self applyKnownWebViews];[self.inspectorViewController render:self.inspectorViewController.showingHierarchy];
    }]]; [self.inspectorViewController presentViewController:c animated:YES completion:nil];
}

''' + s[end:]

# Only ProjectH-owned entries may be removed.
start=s.index('- (void)showHiddenElements {'); end=s.index('- (void)applyKnownWebViews {',start)
s=s[:start]+'''- (void)showHiddenElements {
    NSMutableArray *owned=PHSavedSelectors(), *f=PHLoadFilters(), *valid=[NSMutableArray array]; UIViewController *vc=self.inspectorViewController;if(!vc)return;
    for(NSString *sel in owned.copy){for(id x in f)if([[PHSelectorFromFilter(x)?:@""] isEqualToString:sel]){[valid addObject:sel];break;}}
    PHStoreSavedSelectors(valid);
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu item(ns) salvo(s) pelo ProjetoH",(unsigned long)valid.count] preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSString *sel in valid){NSString *title=[NSString stringWithFormat:@"Reativar: %@\n%@",PHDisplayNameForSelector(sel),sel.length>70?[[sel substringToIndex:70]stringByAppendingString:@"…"]:sel];[a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){NSMutableArray *cur=PHLoadFilters();NSIndexSet *idx=[cur indexesOfObjectsPassingTest:^BOOL(id item,NSUInteger i,BOOL *stop){return [[PHSelectorFromFilter(item)?:@""] isEqualToString:sel];}];[cur removeObjectsAtIndexes:idx];if(PHWriteFilters(cur)){NSMutableArray *saved=PHSavedSelectors();[saved removeObject:sel];PHStoreSavedSelectors(saved);PHRestoreSelector(self.highlightedWebView,sel);}}]];}
    if(valid.count)[a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x){NSMutableArray *cur=PHLoadFilters();NSIndexSet *idx=[cur indexesOfObjectsPassingTest:^BOOL(id item,NSUInteger i,BOOL *stop){NSString *sel=PHSelectorFromFilter(item);return sel.length&&[valid containsObject:sel];}];[cur removeObjectsAtIndexes:idx];if(PHWriteFilters(cur)){for(NSString *sel in valid)PHRestoreSelector(self.highlightedWebView,sel);PHStoreSavedSelectors(@[]);}}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];UIPopoverPresentationController *p=a.popoverPresentationController;p.sourceView=vc.view;p.sourceRect=CGRectMake(CGRectGetMidX(vc.view.bounds),CGRectGetMidY(vc.view.bounds),1,1);[vc presentViewController:a animated:YES completion:nil];
}

''' + s[end:]

# Close without Save restores previews.
start=s.index('- (void)dismissOverlay {'); end=s.index('\n@end',start)
s=s[:start]+'''- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{for(NSString *sel in PHPendingSelectors.copy)PHRestoreSelector(self.highlightedWebView,sel);[PHPendingSelectors removeAllObjects];if(self.highlightedView){self.highlightedView.layer.borderWidth=self.previousBorderWidth;self.highlightedView.layer.borderColor=self.previousBorderColor.CGColor;}self.selectionModeActive=NO;self.inspectorWindow.hidden=YES;self.inspectorWindow=nil;self.inspectorViewController=nil;self.highlightedView=nil;self.highlightedWebView=nil;});
}
''' + s[end:]

p.write_text(s,encoding='utf-8')
