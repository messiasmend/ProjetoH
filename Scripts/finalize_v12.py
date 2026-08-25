from pathlib import Path
import re

p=Path('Sources/PHOverlayManager.m')
s=p.read_text(encoding='utf-8')

s=re.sub(r'static NSString \*PHFilterPath\(void\) \{.*?\n\}\n\nstatic NSMutableArray \*PHLoadFilters', '''static NSString *PHFilterPath(void) {
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *documents=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/custom-filters.json"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:documents]) { path=documents; return; }
        NSString *home=NSHomeDirectory(); NSDirectoryEnumerator *e=[NSFileManager.defaultManager enumeratorAtPath:home]; NSString *r=nil;
        while ((r=[e nextObject])) if ([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) { path=[home stringByAppendingPathComponent:r]; break; }
        if (!path.length) path=documents;
    });
    return path;
}
static NSString *PHSelectorFromFilter(id filter) {
    if (![filter isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *action=filter[@"action"];
    NSString *selector=[action isKindOfClass:NSDictionary.class]?action[@"selector"]:filter[@"selector"];
    return [selector isKindOfClass:NSString.class]&&selector.length?selector:nil;
}
static NSString *PHDisplayNameForSelector(NSString *selector) {
    if (!selector.length) return @"Elemento oculto";
    if ([selector rangeOfString:@"lottie-player" options:NSCaseInsensitiveSearch].location!=NSNotFound) return @"Lottie Player";
    if ([selector hasPrefix:@"#"]) return [NSString stringWithFormat:@"Elemento %@",selector];
    if ([selector hasPrefix:@"."]) { NSArray *parts=[selector componentsSeparatedByString:@" "]; NSString *first=parts.firstObject?:selector; return [NSString stringWithFormat:@"Elemento %@",first]; }
    NSArray *parts=[selector componentsSeparatedByString:@" > "]; NSString *last=parts.lastObject?:selector; NSRange pseudo=[last rangeOfString:@":"]; if(pseudo.location!=NSNotFound) last=[last substringToIndex:pseudo.location];
    return last.length?[NSString stringWithFormat:@"Elemento <%@>",last]:@"Elemento oculto";
}
static NSMutableArray *PHLoadFilters''',s,flags=re.S)

s=re.sub(r'static NSMutableArray \*PHLoadFilters\(void\) \{.*?\n\}\n\nstatic BOOL PHWriteFilters', '''static NSMutableArray *PHLoadFilters(void) {
    NSData *data=[NSData dataWithContentsOfFile:PHFilterPath()]; if(!data)return [NSMutableArray array];
    id json=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if([json isKindOfClass:NSDictionary.class]&&[json[@"filters"] isKindOfClass:NSArray.class]) json=json[@"filters"];
    return [json isKindOfClass:NSArray.class]?[json mutableCopy]:[NSMutableArray array];
}
static BOOL PHWriteFilters''',s,flags=re.S)

s=re.sub(r'static BOOL PHWriteFilters\(NSArray \*filters\) \{.*?\n\}\n\nstatic NSString \*PHSelectorsJSON', '''static BOOL PHWriteFilters(NSArray *filters) {
    NSString *path=PHFilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableArray *valid=[NSMutableArray array];
    for(id filter in filters?:@[]) if([filter isKindOfClass:NSDictionary.class]&&[NSJSONSerialization isValidJSONObject:filter])[valid addObject:filter];
    NSData *data=[NSJSONSerialization dataWithJSONObject:valid options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
    return data&&[data writeToFile:path atomically:YES];
}
static NSString *PHSelectorsJSON''',s,flags=re.S)

s=re.sub(r'static void PHApplyFilters\(WKWebView \*webView\) \{.*?\n\}\n\nstatic void PHHideSelector', '''static void PHApplyFilters(WKWebView *webView) {
    if(!webView)return; NSMutableArray *selectors=[NSMutableArray array];
    for(id filter in PHLoadFilters()){NSString *selector=PHSelectorFromFilter(filter);if(selector.length)[selectors addObject:selector];}
    if(!selectors.count)return; NSString *json=PHSelectorsJSON(selectors);
    NSString *script=[NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';})}catch(e){}});",json];
    [webView evaluateJavaScript:script completionHandler:nil];
}
static void PHHideSelector''',s,flags=re.S)

s=s.replace('static NSTimer *PHApplyTimer = nil;','''static NSTimer *PHApplyTimer = nil;
static NSMutableArray<NSString *> *PHSavedSelectors(void) { NSArray *stored=[[NSUserDefaults standardUserDefaults] arrayForKey:@"ProjetoH.SavedSelectors"]; return stored?[stored mutableCopy]:[NSMutableArray array]; }
static void PHStoreSavedSelectors(NSArray *selectors) { [[NSUserDefaults standardUserDefaults] setObject:selectors?:@[] forKey:@"ProjetoH.SavedSelectors"]; }''',1)

start=s.index('- (void)savePendingFilters {'); end=s.index('- (void)applyKnownWebViews {',start)
methods='''- (void)savePendingFilters {
    if (!PHPendingSelectors.count) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Salvar alterações?" message:[NSString stringWithFormat:@"%lu elemento(s) serão salvos no custom-filters.json.",(unsigned long)PHPendingSelectors.count] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Salvar" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        NSMutableArray *filters=PHLoadFilters(); NSMutableArray *saved=PHSavedSelectors();
        for(NSString *selector in PHPendingSelectors.copy){
            BOOL exists=NO; for(id filter in filters){NSString *existing=PHSelectorFromFilter(filter); if([existing isEqualToString:selector]){exists=YES;break;}}
            if(!exists){ NSDictionary *rule=@{@"trigger":@{@"url-filter":@".*"},@"action":@{@"type":@"css-display-none",@"selector":selector}}; [filters addObject:rule]; }
            if(![saved containsObject:selector])[saved addObject:selector];
        }
        if(PHWriteFilters(filters)){PHStoreSavedSelectors(saved);[PHPendingSelectors removeAllObjects];[self applyKnownWebViews];[self.inspectorViewController render:self.inspectorViewController.showingHierarchy];}
    }]];
    [self.inspectorViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showHiddenElements {
    NSMutableArray *owned=PHSavedSelectors(); NSMutableArray *filters=PHLoadFilters(); NSMutableArray *valid=[NSMutableArray array];
    for(NSString *selector in owned.copy){for(id filter in filters){if([[PHSelectorFromFilter(filter)?:@""] isEqualToString:selector]){[valid addObject:selector];break;}}}
    PHStoreSavedSelectors(valid); UIViewController *vc=self.inspectorViewController; if(!vc)return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu elemento(s) salvo(s) pelo ProjetoH",(unsigned long)valid.count] preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSString *selector in valid){ NSString *name=PHDisplayNameForSelector(selector); [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@",name] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        NSMutableArray *current=PHLoadFilters(); NSIndexSet *indexes=[current indexesOfObjectsPassingTest:^BOOL(id filter,NSUInteger idx,BOOL *stop){return [[PHSelectorFromFilter(filter)?:@""] isEqualToString:selector];}]; [current removeObjectsAtIndexes:indexes];
        if(PHWriteFilters(current)){NSMutableArray *saved=PHSavedSelectors();[saved removeObject:selector];PHStoreSavedSelectors(saved);PHRestoreSelector(self.highlightedWebView,selector);[self applyKnownWebViews];}
    }]]; }
    if(valid.count)[alert addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action){
        NSMutableArray *current=PHLoadFilters(); NSIndexSet *indexes=[current indexesOfObjectsPassingTest:^BOOL(id filter,NSUInteger idx,BOOL *stop){NSString *selector=PHSelectorFromFilter(filter);return selector.length&&[valid containsObject:selector];}];
        for(NSString *selector in valid)PHRestoreSelector(self.highlightedWebView,selector); [current removeObjectsAtIndexes:indexes]; if(PHWriteFilters(current))PHStoreSavedSelectors(@[]);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover=alert.popoverPresentationController; popover.sourceView=vc.view; popover.sourceRect=CGRectMake(CGRectGetMidX(vc.view.bounds),CGRectGetMidY(vc.view.bounds),1,1); [vc presentViewController:alert animated:YES completion:nil];
}

'''
s=s[:start]+methods+s[end:]

start=s.index('- (void)dismissOverlay {'); end=s.index('\n@end',start)
s=s[:start]+'''- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        for(NSString *selector in PHPendingSelectors.copy)PHRestoreSelector(self.highlightedWebView,selector);
        [PHPendingSelectors removeAllObjects];
        if(self.highlightedView){self.highlightedView.layer.borderWidth=self.previousBorderWidth;self.highlightedView.layer.borderColor=self.previousBorderColor.CGColor;}
        self.selectionModeActive=NO;self.inspectorWindow.hidden=YES;self.inspectorWindow=nil;self.inspectorViewController=nil;self.highlightedView=nil;self.highlightedWebView=nil;
    });
}
''' + s[end:]
p.write_text(s,encoding='utf-8')
