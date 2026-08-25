#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <math.h>

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
@end

static NSMutableArray<NSString *> *PHV12Pending(void) {
    static NSMutableArray *a;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ a = [NSMutableArray array]; });
    return a;
}

static WKWebView *PHV12WebView(void) {
    id m = [NSClassFromString(@"PHOverlayManager") respondsToSelector:@selector(sharedManager)] ? [NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)] : nil;
    return [m valueForKey:@"highlightedWebView"];
}

static UIViewController *PHV12Inspector(void) {
    id m = [NSClassFromString(@"PHOverlayManager") respondsToSelector:@selector(sharedManager)] ? [NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)] : nil;
    return [m valueForKey:@"inspectorViewController"];
}

static NSString *PHV12Path(void) {
    NSString *home = NSHomeDirectory();
    NSString *documents = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:documents]) return documents;
    NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
    NSString *r = nil;
    while ((r = [e nextObject])) if ([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) return [home stringByAppendingPathComponent:r];
    return documents;
}

static NSMutableArray *PHV12Load(void) {
    NSData *d = [NSData dataWithContentsOfFile:PHV12Path()];
    if (!d.length) return [NSMutableArray array];
    id root = [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil];
    if ([root isKindOfClass:NSDictionary.class]) root = root[@"filters"];
    return [root isKindOfClass:NSArray.class] ? [root mutableCopy] : [NSMutableArray array];
}

static NSString *PHV12Selector(id rule) {
    if (![rule isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *action = rule[@"action"];
    NSString *s = [action isKindOfClass:NSDictionary.class] ? action[@"selector"] : rule[@"selector"];
    return [s isKindOfClass:NSString.class] && s.length ? s : nil;
}

static BOOL PHV12IsNative(id rule) {
    if (![rule isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *a = rule[@"action"], *t = rule[@"trigger"];
    return [a isKindOfClass:NSDictionary.class] && [t isKindOfClass:NSDictionary.class] && [a[@"type"] isEqualToString:@"css-display-none"] && [t[@"url-filter"] isKindOfClass:NSString.class];
}

static NSDictionary *PHV12Rule(NSString *selector) {
    return @{@"trigger":@{@"url-filter":@".*"}, @"action":@{@"type":@"css-display-none", @"selector":selector}};
}

static BOOL PHV12Save(NSArray *rules) {
    NSMutableArray *out = [NSMutableArray array];
    for (id rule in rules) {
        if (PHV12IsNative(rule)) [out addObject:rule];
        else if ([rule isKindOfClass:NSDictionary.class] && PHV12Selector(rule).length) [out addObject:PHV12Rule(PHV12Selector(rule))];
    }
    NSData *d = [NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:nil];
    return d && [d writeToFile:PHV12Path() atomically:YES];
}

static void PHV12JS(NSString *selector, BOOL hide) {
    WKWebView *w = PHV12WebView(); if (!w || !selector.length) return;
    NSData *d = [NSJSONSerialization dataWithJSONObject:@[selector] options:0 error:nil];
    NSString *j = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    NSString *script = hide ? [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';})}catch(x){}})",j] : [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display');})}catch(x){}})",j];
    [w evaluateJavaScript:script completionHandler:nil];
}

static void PHV12Selected(void (^completion)(NSString *selector)) {
    WKWebView *w = PHV12WebView(); if (!w) { completion(nil); return; }
    NSString *script = @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var s=[...q.children].filter(function(x){return x.tagName===n.tagName});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(s.indexOf(n)+1)+')');n=q;}return a.join(' > ')}return p(e)})()";
    [w evaluateJavaScript:script completionHandler:^(id r, NSError *e){ dispatch_async(dispatch_get_main_queue(), ^{ completion((e || ![r isKindOfClass:NSString.class]) ? nil : r); }); }];
}

static NSString *PHV12Friendly(NSString *s) {
    if (!s.length) return @"Elemento oculto";
    if ([s rangeOfString:@"lottie-player" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"Lottie Player";
    if ([s hasPrefix:@"#"]) return [NSString stringWithFormat:@"Elemento %@",s];
    NSArray *p = [s componentsSeparatedByString:@" > "]; NSString *last = [p.lastObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSRange pseudo = [last rangeOfString:@":"]; if (pseudo.location != NSNotFound) last = [last substringToIndex:pseudo.location];
    NSRange dot = [last rangeOfString:@"."]; if (dot.location != NSNotFound) return [NSString stringWithFormat:@"Elemento %@",[last substringFromIndex:dot.location]];
    if (last.length && last.length < 32) return [NSString stringWithFormat:@"Elemento <%@>",last];
    return @"Elemento oculto";
}

static void PHV12RestorePending(void) {
    for (NSString *s in PHV12Pending().copy) PHV12JS(s, NO);
    [PHV12Pending() removeAllObjects];
}

static void PHV12RefreshSaveButton(void);

@interface PHV12Target : NSObject
+ (instancetype)shared;
- (void)hide;
- (void)save;
- (void)manage;
@end

@implementation PHV12Target
+ (instancetype)shared { static PHV12Target *x; static dispatch_once_t once; dispatch_once(&once, ^{x=[self new];}); return x; }

- (void)hide {
    PHV12Selected(^(NSString *selector){
        if (!selector.length) return;
        if (![PHV12Pending() containsObject:selector]) [PHV12Pending() addObject:selector];
        PHV12JS(selector, YES);
        PHV12RefreshSaveButton();
    });
}

- (void)save {
    NSArray *pending = PHV12Pending().copy; if (!pending.count) return;
    UIViewController *vc = PHV12Inspector();
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Salvar alterações?" message:[NSString stringWithFormat:@"%lu elemento(s) serão adicionados permanentemente ao custom-filters.json.",(unsigned long)pending.count] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Salvar" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){
        NSMutableArray *rules=PHV12Load();
        for(NSString *s in pending){BOOL exists=NO;for(id r in rules)if([PHV12Selector(r) isEqualToString:s]){exists=YES;break;}if(!exists)[rules addObject:PHV12Rule(s)];}
        if(PHV12Save(rules))[PHV12Pending() removeAllObjects];
        PHV12RefreshSaveButton();
    }]];
    [vc presentViewController:a animated:YES completion:nil];
}

- (void)manage {
    UIViewController *vc=PHV12Inspector(); if(!vc)return;
    NSArray *rules=PHV12Load();
    NSMutableArray *hideRules=[NSMutableArray array];
    for(id r in rules) if([PHV12Selector(r) length] && PHV12IsNative(r)) [hideRules addObject:r];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu filtro(s) salvos no custom-filters.json",(unsigned long)hideRules.count] preferredStyle:UIAlertControllerStyleAlert];
    for(id r in hideRules){NSString *s=PHV12Selector(r);NSString *name=PHV12Friendly(s);[a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@",name] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){NSMutableArray *cur=PHV12Load();NSMutableArray *rem=[NSMutableArray array];for(id item in cur)if(![PHV12Selector(item) isEqualToString:s])[rem addObject:item];if(PHV12Save(rem))PHV12JS(s,NO);}]];}
    [a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}
@end

static char KHide, KSave;
static void (*PHV12OrigShow)(id, SEL, NSString *) = NULL;
static void (*PHV12OrigClose)(id, SEL) = NULL;

static UIButton *PHV12ButtonWithTitle(UIView *root, NSString *title) {
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:UIButton.class] && [[(UIButton *)v titleForState:UIControlStateNormal] isEqualToString:title]) return (UIButton *)v;
        UIButton *nested = PHV12ButtonWithTitle(v,title); if(nested)return nested;
    }
    return nil;
}

static void PHV12InstallButtons(void) {
    UIViewController *vc=PHV12Inspector(); if(!vc)return;
    UIView *panel=nil; for(UIView *v in vc.view.subviews.reverseObjectEnumerator) if(fabs(v.bounds.size.width-350.0)<3&&fabs(v.bounds.size.height-430.0)<3){panel=v;break;}
    if(!panel)return;

    UIButton *oldHide=PHV12ButtonWithTitle(panel,@"Ocultar"); if(oldHide){[oldHide removeFromSuperview];}
    UIButton *oldManage=PHV12ButtonWithTitle(panel,@"Ocultos"); if(oldManage){[oldManage removeFromSuperview];}

    UIButton *manage=[UIButton buttonWithType:UIButtonTypeSystem]; manage.translatesAutoresizingMaskIntoConstraints=NO; [manage setTitle:@"Ocultos" forState:UIControlStateNormal]; manage.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; [manage addTarget:PHV12Target.shared action:@selector(manage) forControlEvents:UIControlEventTouchUpInside]; [panel addSubview:manage];
    [NSLayoutConstraint activateConstraints:@[[manage.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],[manage.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20],[manage.widthAnchor constraintEqualToConstant:90],[manage.heightAnchor constraintEqualToConstant:30]]];

    UIButton *save=objc_getAssociatedObject(vc,&KSave);
    if(!save){save=[UIButton buttonWithType:UIButtonTypeSystem];save.translatesAutoresizingMaskIntoConstraints=NO;[save setTitle:@"Salvar" forState:UIControlStateNormal];save.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];[save addTarget:PHV12Target.shared action:@selector(save) forControlEvents:UIControlEventTouchUpInside];[panel addSubview:save];[NSLayoutConstraint activateConstraints:@[[save.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22],[save.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20],[save.widthAnchor constraintEqualToConstant:90],[save.heightAnchor constraintEqualToConstant:30]]];objc_setAssociatedObject(vc,&KSave,save,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}

    UIButton *hide=[UIButton buttonWithType:UIButtonTypeSystem];hide.translatesAutoresizingMaskIntoConstraints=NO;[hide setTitle:@"Ocultar" forState:UIControlStateNormal];hide.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];[hide addTarget:PHV12Target.shared action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];[panel addSubview:hide];[NSLayoutConstraint activateConstraints:@[[hide.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22],[hide.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20],[hide.widthAnchor constraintEqualToConstant:90],[hide.heightAnchor constraintEqualToConstant:30]]];objc_setAssociatedObject(vc,&KHide,hide,OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    save.enabled=PHV12Pending().count>0; save.alpha=save.enabled?1.0:0.45;
}

static void PHV12RefreshSaveButton(void){UIViewController *vc=PHV12Inspector();UIButton *b=objc_getAssociatedObject(vc,&KSave);if(b){b.enabled=PHV12Pending().count>0;b.alpha=b.enabled?1.0:0.45;}}

static void PHV12HookShow(id self, SEL cmd, NSString *details) {
    if(PHV12OrigShow)PHV12OrigShow(self,cmd,details);
    dispatch_async(dispatch_get_main_queue(), ^{PHV12InstallButtons();});
}

static void PHV12HookClose(id self, SEL cmd) {
    PHV12RestorePending();
    if(PHV12OrigClose)PHV12OrigClose(self,cmd);
}

__attribute__((constructor)) static void PHV12Init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c=NSClassFromString(@"PHInspectorViewController");
        Method show=class_getInstanceMethod(c,@selector(showSelectedWebElement:));
        Method close=class_getInstanceMethod(c,@selector(closeTapped));
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            if(show){PHV12OrigShow=(void(*)(id,SEL,NSString *))method_getImplementation(show);method_setImplementation(show,(IMP)PHV12HookShow);}
            if(close){PHV12OrigClose=(void(*)(id,SEL))method_getImplementation(close);method_setImplementation(close,(IMP)PHV12HookClose);}
        });
    });
}
