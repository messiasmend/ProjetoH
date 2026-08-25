from pathlib import Path
import re, subprocess
BASE='96953d9b1f6dbc9d55567d8a4b6e53c6c47dd502'
p=Path('Sources/PHOverlayManager.m')
subprocess.run(['git','checkout',BASE,'--',str(p)],check=True)
s=p.read_text(encoding='utf-8')
def rep(pattern,repl,label):
 global s
 s,n=re.subn(pattern,repl,s,count=1,flags=re.S)
 if n!=1: raise SystemExit(f'{label}: expected 1 match, got {n}')
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
    NSString *last=[[selector componentsSeparatedByString:@" > "] lastObject]?:selector; NSRange r=[last rangeOfString:@":"]; if(r.location!=NSNotFound) last=[last substringToIndex:r.location];
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
    NSString *path=PHFilterPath(); [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data=[NSJSONSerialization dataWithJSONObject:filters?:@[] options:NSJSONWritingPrettyPrinted error:nil];
    return data&&[data writeToFile:path atomically:YES];
}
static NSString *PHSelectorsJSON''','write')
rep(r'static void PHApplyFilters\(WKWebView \*webView\) \{.*?\n\}\n\nstatic void PHHideSelector',r'''static void PHApplyFilters(WKWebView *webView) {
    if(!webView)return; NSMutableArray *selectors=[NSMutableArray array];
    for(id filter in PHLoadFilters()){NSString *selector=PHSelectorFromFilter(filter);if(selector.length)[selectors addObject:selector];}
    if(!selectors.count)return; NSString *json=PHSelectorsJSON(selectors);
    NSString *script=[NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){if(e.getAttribute('data-projetoh-hidden')!=='1'){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';}})}catch(e){}});",json];
    [webView evaluateJavaScript:script completionHandler:nil];
}
static void PHHideSelector''','apply')
s=s.replace('static NSMutableArray<NSString *> *PHPendingSelectors = nil;\nstatic NSTimer *PHApplyTimer = nil;','''static NSMutableArray<NSString *> *PHPendingSelectors=nil;
static NSTimer *PHApplyTimer=nil;
static NSMutableArray<NSString *> *PHSavedSelectors(void){ NSArray *a=[[NSUserDefaults standardUserDefaults] arrayForKey:@"ProjetoH.SavedSelectors"]; return a?[a mutableCopy]:[NSMutableArray array]; }
static void PHStoreSavedSelectors(NSArray *a){ [[NSUserDefaults standardUserDefaults] setObject:a?:@[] forKey:@"ProjetoH.SavedSelectors"]; }''',1)
rep(r'- \(void\)render:\(BOOL\)hierarchyMode \{.*?\n\}\n\n- \(void\)hierarchyTapped',r'''- (void)render:(BOOL)hierarchyMode {
    [self clear]; UIView *p=[self panel]; [self.view addSubview:p];
    UILabel *title=[self label:@"ProjetoH Inspector" font:[UIFont boldSystemFontOfSize:21] color:UIColor.whiteColor];
    UILabel *subtitle=[self label:(hierarchyMode?@"Hierarquia DOM":self.currentSubtitle) font:[UIFont systemFontOfSize:14] color:[UIColor colorWithWhite:0.72 alpha:1]];
    UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO; scroll.backgroundColor=[UIColor colorWithWhite:0.055 alpha:1]; scroll.layer.cornerRadius=12; scroll.alwaysBounceVertical=YES;
    UILabel *content=[self label:self.currentDetails font:[UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular] color:[UIColor colorWithWhite:0.88 alpha:1]]; [scroll addSubview:content];
    UIButton *left=[self button:(hierarchyMode?@"Voltar":@"Hierarquia") action:(hierarchyMode?@selector(backTapped):@selector(hierarchyTapped))];
    UIButton *copy=[self button:@"Copiar" action:@selector(copyTapped)]; UIButton *close=[self button:@"Fechar" action:@selector(closeTapped)];
    UIButton *hide=[self button:@"Ocultar" action:@selector(hideTapped)]; UIButton *hidden=[self button:@"Ocultos" action:@selector(hiddenTapped)]; UIButton *save=[self button:@"Salvar" action:@selector(saveTapped)];
    BOOL pending=PHPendingSelectors.count>0; save.alpha=pending?1.0:0.35; save.userInteractionEnabled=pending;
    for(UIView *v in @[title,subtitle,scroll,left,copy,close,hide,hidden,save])[p addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [p.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[p.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[p.widthAnchor constraintEqualToConstant:360],[p.heightAnchor constraintEqualToConstant:500],
        [title.topAnchor constraintEqualToAnchor:p.topAnchor constant:20],[title.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:20],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],[subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:16],[scroll.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[scroll.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[scroll.heightAnchor constraintEqualToConstant:320],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:14],[content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:14],[content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-14],[content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-14],[content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-28],
        [left.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[left.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-66],[left.widthAnchor constraintEqualToConstant:100],
        [copy.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],[copy.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-66],[copy.widthAnchor constraintEqualToConstant:100],
        [close.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[close.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-66],[close.widthAnchor constraintEqualToConstant:100],
        [hide.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[hide.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-16],[hide.widthAnchor constraintEqualToConstant:100],
        [hidden.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],[hidden.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-16],[hidden.widthAnchor constraintEqualToConstant:100],
        [save.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[save.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-16],[save.widthAnchor constraintEqualToConstant:100]
    ]];
}
- (void)hierarchyTapped''','render')
rep(r'- \(void\)savePendingFilters \{.*?\n\}\n\n- \(void\)showHiddenElements',r'''- (void)savePendingFilters {
    if(!PHPendingSelectors.count)return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Salvar alterações?" message:[NSString stringWithFormat:@"%lu elemento(s) serão salvos permanentemente no custom-filters.json.",(unsigned long)PHPendingSelectors.count] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf=self;
    UIAlertAction *saveAction=[UIAlertAction actionWithTitle:@"Salvar" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        __strong typeof(weakSelf) self=weakSelf;if(!self)return; NSMutableArray *filters=PHLoadFilters(); NSMutableArray *owned=PHSavedSelectors();
        for(NSString *selector in PHPendingSelectors){BOOL exists=NO;for(id filter in filters)if([[PHSelectorFromFilter(filter)?:@""] isEqualToString:selector]){exists=YES;break;}if(!exists)[filters addObject:@{@"trigger":@{@"url-filter":@".*"},@"action":@{@"type":@"css-display-none",@"selector":selector}}];if(![owned containsObject:selector])[owned addObject:selector];}
        if(PHWriteFilters(filters)){PHStoreSavedSelectors(owned);[PHPendingSelectors removeAllObjects];[self applyKnownWebViews];[self.inspectorViewController render:self.inspectorViewController.showingHierarchy];}
    }]; [alert addAction:saveAction]; alert.preferredAction=saveAction; [self.inspectorViewController presentViewController:alert animated:YES completion:nil];
}
- (void)showHiddenElements''','save')
rep(r'- \(void\)showHiddenElements \{.*?\n\}\n\n- \(void\)applyKnownWebViews',r'''- (void)showHiddenElements {
    NSArray *filters=PHLoadFilters(); NSArray *owned=PHSavedSelectors(); UIViewController *vc=self.inspectorViewController;if(!vc)return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Filtros" message:@"Filtros salvos e regras manuais" preferredStyle:UIAlertControllerStyleActionSheet];
    for(id filter in filters){NSString *selector=PHSelectorFromFilter(filter);if(!selector.length)continue;NSString *name=PHDisplayNameForSelector(selector);BOOL isOwned=[owned containsObject:selector];NSString *title=[NSString stringWithFormat:@"%@ %@",isOwned?@"🟢":@"⚪",name];
        if(isOwned){[alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){NSMutableArray *cur=PHLoadFilters();NSIndexSet *idx=[cur indexesOfObjectsPassingTest:^BOOL(id item,NSUInteger i,BOOL *stop){return [[PHSelectorFromFilter(item)?:@""] isEqualToString:selector];}];[cur removeObjectsAtIndexes:idx];if(PHWriteFilters(cur)){NSMutableArray *saved=PHSavedSelectors();[saved removeObject:selector];PHStoreSavedSelectors(saved);PHRestoreSelector(self.highlightedWebView,selector);}}]];}
        else {UIAlertAction *manual=[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:nil];manual.enabled=NO;[alert addAction:manual];}
    }
    if(owned.count)[alert addAction:[UIAlertAction actionWithTitle:@"Reativar todos os salvos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a){NSMutableArray *cur=PHLoadFilters();NSIndexSet *idx=[cur indexesOfObjectsPassingTest:^BOOL(id item,NSUInteger i,BOOL *stop){NSString *selector=PHSelectorFromFilter(item);return selector.length&&[owned containsObject:selector];}];[cur removeObjectsAtIndexes:idx];if(PHWriteFilters(cur)){for(NSString *selector in owned)PHRestoreSelector(self.highlightedWebView,selector);PHStoreSavedSelectors(@[]);}}]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]]; UIPopoverPresentationController *popover=alert.popoverPresentationController;popover.sourceView=vc.view;popover.sourceRect=CGRectMake(CGRectGetMidX(vc.view.bounds),CGRectGetMidY(vc.view.bounds),1,1);[vc presentViewController:alert animated:YES completion:nil];
}
- (void)applyKnownWebViews''','hidden')
rep(r'- \(void\)dismissOverlay \{.*?\n\}\n@end',r'''- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        for(NSString *selector in PHPendingSelectors.copy)PHRestoreSelector(self.highlightedWebView,selector);[PHPendingSelectors removeAllObjects];
        if(self.highlightedView){self.highlightedView.layer.borderWidth=self.previousBorderWidth;self.highlightedView.layer.borderColor=self.previousBorderColor.CGColor;}
        if(self.highlightedWebView)[self.highlightedWebView evaluateJavaScript:@"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(e){e.style.outline=e.getAttribute('data-projetoh-prev-outline')||'';e.removeAttribute('data-projetoh-selected');e.removeAttribute('data-projetoh-prev-outline');}})();" completionHandler:nil];
        self.selectionModeActive=NO;self.inspectorWindow.hidden=YES;self.inspectorWindow=nil;self.inspectorViewController=nil;self.highlightedView=nil;self.highlightedWebView=nil;self.previousBorderColor=nil;self.previousBorderWidth=0;
    });
}
@end''','dismiss')
needle='NSMutableString *d = [NSMutableString stringWithFormat:@"HTML: <%@>", info[@"tag"] ?: @"?"];'
if needle not in s: raise SystemExit('name insertion point missing')
repl='''NSString *displayName=[info[@"id"] length]?[NSString stringWithFormat:@"#%@",info[@"id"]]:([info[@"className"] length]?[NSString stringWithFormat:@".%@",[[info[@"className"] componentsSeparatedByString:@" "] firstObject]]:([info[@"text"] length]?info[@"text"]:[NSString stringWithFormat:@"Elemento <%@>",info[@"tag"]?:@"?"]));
            NSMutableString *d=[NSMutableString stringWithFormat:@"Nome: %@\\nHTML: <%@>",displayName,info[@"tag"]?:@"?"];'''
s=s.replace(needle,repl,1)
p.write_text(s,encoding='utf-8')
print('V12 clean source prepared')
