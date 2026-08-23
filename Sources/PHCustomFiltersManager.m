#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
@end

@interface PHCustomFiltersTarget : NSObject
+ (instancetype)sharedTarget;
- (void)hide:(id)sender;
- (void)manage:(id)sender;
- (void)save:(id)sender;
@end

static char PHHideKey, PHManageKey, PHSaveKey;
static NSString *PHPendingSelector = nil;
static NSTimer *PHApplyTimer = nil;
static NSMutableDictionary<NSValue *, NSString *> *PHWebViewState = nil;

static NSString *PHPath(void) {
    NSString *home = NSHomeDirectory();
    NSDirectoryEnumerator *enumerator = [NSFileManager.defaultManager enumeratorAtPath:home];
    NSString *relative;
    while ((relative = [enumerator nextObject])) {
        if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
            return [home stringByAppendingPathComponent:relative];
        }
    }
    return [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
}

static id PHM(void) {
    Class c = NSClassFromString(@"PHOverlayManager");
    return [c respondsToSelector:@selector(sharedManager)] ? [c performSelector:@selector(sharedManager)] : nil;
}

static WKWebView *PHW(void) {
    id manager = PHM();
    return [manager valueForKey:@"highlightedWebView"];
}

static UIViewController *PHI(void) {
    id manager = PHM();
    return [manager valueForKey:@"inspectorViewController"];
}

static NSMutableArray *PHLoad(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHPath()];
    if (!data) return [NSMutableArray array];
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    return [json isKindOfClass:NSArray.class] ? [json mutableCopy] : [NSMutableArray array];
}

static void PHWrite(NSArray *filters) {
    NSString *path = PHPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"version": @1, @"filters": filters ?: @[] } options:0 error:nil];
    [data writeToFile:path atomically:YES];
}

static NSString *PHSelectedScript(void) {
    return @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var s=[...q.children].filter(x=>x.tagName===n.tagName);a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(s.indexOf(n)+1)+')');n=q}return a.join(' > ')}return JSON.stringify({selector:p(e)})})()";
}

static NSString *PHJSONArray(NSArray *selectors) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:selectors ?: @[] options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
}

static void PHApplyToWebView(WKWebView *webView) {
    if (!webView) return;
    NSMutableArray *selectors = [NSMutableArray array];
    for (NSDictionary *filter in PHLoad()) {
        NSString *selector = filter[@"selector"];
        if (selector.length) [selectors addObject:selector];
    }
    if (!selectors.count) return;

    NSString *json = PHJSONArray(selectors);
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){if(e.getAttribute('data-projetoh-hidden')!=='1'){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none'}})}catch(x){}})", json];
    [webView evaluateJavaScript:script completionHandler:nil];
}

static void PHHideVisually(WKWebView *webView, NSString *selector) {
    if (!webView || !selector.length) return;
    NSString *json = PHJSONArray(@[selector]);
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none'})}catch(x){}})", json];
    [webView evaluateJavaScript:script completionHandler:nil];
}

static void PHRestore(NSString *selector) {
    WKWebView *webView = PHW();
    if (!webView || !selector.length) return;
    NSString *json = PHJSONArray(@[selector]);
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display')})}catch(x){}})", json];
    [webView evaluateJavaScript:script completionHandler:nil];
}

static void PHSetSaveVisible(BOOL visible) {
    UIViewController *vc = PHI();
    if (!vc) return;
    UIButton *button = objc_getAssociatedObject(vc, &PHSaveKey);
    button.hidden = !visible;
}

static void PHHide(void) {
    WKWebView *webView = PHW();
    if (!webView) return;

    [webView evaluateJavaScript:PHSelectedScript() completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) return;
        NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *info = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *selector = info[@"selector"];
        if (!selector.length) return;

        PHPendingSelector = [selector copy];
        PHHideVisually(webView, selector);
        dispatch_async(dispatch_get_main_queue(), ^{ PHSetSaveVisible(YES); });
    }];
}

static void PHSavePending(void) {
    NSString *selector = PHPendingSelector;
    if (!selector.length) return;

    NSMutableArray *filters = PHLoad();
    BOOL exists = NO;
    for (NSDictionary *filter in filters) {
        if ([filter[@"selector"] isEqualToString:selector]) { exists = YES; break; }
    }
    if (!exists) [filters addObject:@{ @"selector": selector }];
    PHWrite(filters);
    PHPendingSelector = nil;
    PHSetSaveVisible(NO);
    PHApplyToWebView(PHW());
}

static void PHManage(void) {
    UIViewController *vc = PHI();
    if (!vc) return;

    NSArray *filters = PHLoad();
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Elementos ocultos"
        message:[NSString stringWithFormat:@"%lu item(ns) em custom-filters.json", (unsigned long)filters.count]
        preferredStyle:UIAlertControllerStyleAlert];

    for (NSDictionary *filter in filters) {
        NSString *selector = filter[@"selector"] ?: @"";
        NSString *shortSelector = selector.length > 90 ? [[selector substringToIndex:90] stringByAppendingString:@"…"] : selector;
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@", shortSelector]
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                NSMutableArray *current = PHLoad();
                NSIndexSet *indexes = [current indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
                    return [item[@"selector"] isEqualToString:selector];
                }];
                [current removeObjectsAtIndexes:indexes];
                PHWrite(current);
                PHRestore(selector);
            }]];
    }

    if (filters.count) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            for (NSDictionary *filter in PHLoad()) PHRestore(filter[@"selector"]);
            PHWrite(@[]);
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}

static void PHAddButtons(void) {
    UIViewController *vc = PHI();
    if (!vc) return;

    UIButton *oldHide = objc_getAssociatedObject(vc, &PHHideKey);
    UIButton *oldManage = objc_getAssociatedObject(vc, &PHManageKey);
    UIButton *oldSave = objc_getAssociatedObject(vc, &PHSaveKey);
    [oldHide removeFromSuperview];
    [oldManage removeFromSuperview];
    [oldSave removeFromSuperview];

    UIView *panel = nil;
    for (UIView *candidate in vc.view.subviews.reverseObjectEnumerator) {
        if (candidate != vc.view && fabs(candidate.bounds.size.width - 350.0) < 2.0 && fabs(candidate.bounds.size.height - 430.0) < 2.0) {
            panel = candidate;
            break;
        }
    }
    if (!panel) return;

    UIButton *hide = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButton *manage = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    NSArray *buttons = @[hide, manage, save];
    NSArray *titles = @[@"Ocultar", @"Ocultos", @"Salvar"];
    for (NSUInteger i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];
        button.frame = CGRectMake(18.0 + i * 108.0, 72.0, 100.0, 30.0);
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        [panel addSubview:button];
    }
    [hide addTarget:PHCustomFiltersTarget.sharedTarget action:@selector(hide:) forControlEvents:UIControlEventTouchUpInside];
    [manage addTarget:PHCustomFiltersTarget.sharedTarget action:@selector(manage:) forControlEvents:UIControlEventTouchUpInside];
    [save addTarget:PHCustomFiltersTarget.sharedTarget action:@selector(save:) forControlEvents:UIControlEventTouchUpInside];
    save.hidden = PHPendingSelector.length == 0;

    objc_setAssociatedObject(vc, &PHHideKey, hide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, &PHManageKey, manage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, &PHSaveKey, save, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void PHApplyKnownWebViews(void) {
    NSArray *windows = UIApplication.sharedApplication.windows;
    if (!PHWebViewState) PHWebViewState = [NSMutableDictionary dictionary];
    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= 0.0) continue;
        NSMutableArray *stack = [NSMutableArray arrayWithObject:window];
        while (stack.count) {
            UIView *view = stack.lastObject;
            [stack removeLastObject];
            if ([view isKindOfClass:WKWebView.class]) {
                WKWebView *webView = (WKWebView *)view;
                NSString *url = webView.URL.absoluteString ?: @"";
                NSValue *key = [NSValue valueWithNonretainedObject:webView];
                NSString *lastURL = PHWebViewState[key];
                if (!lastURL || ![lastURL isEqualToString:url]) PHWebViewState[key] = url;
                PHApplyToWebView(webView);
            }
            [stack addObjectsFromArray:view.subviews];
        }
    }
}

@implementation PHCustomFiltersTarget
+ (instancetype)sharedTarget { static PHCustomFiltersTarget *target; static dispatch_once_t once; dispatch_once(&once, ^{ target = [self new]; }); return target; }
- (void)hide:(id)sender { PHHide(); }
- (void)manage:(id)sender { PHManage(); }
- (void)save:(id)sender { PHSavePending(); }
@end

static void(*PHOrigShow)(id, SEL, NSString *);
static void PHHookShow(id self, SEL selector, NSString *details) {
    if (PHOrigShow) PHOrigShow(self, selector, details);
    dispatch_async(dispatch_get_main_queue(), ^{ PHAddButtons(); });
}

__attribute__((constructor)) static void PHInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class inspector = NSClassFromString(@"PHInspectorViewController");
        Method method = class_getInstanceMethod(inspector, @selector(showSelectedWebElement:));
        if (method) {
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                PHOrigShow = (void(*)(id, SEL, NSString *))method_getImplementation(method);
                method_setImplementation(method, (IMP)PHHookShow);
            });
        }

        PHApplyTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(__unused NSTimer *timer) {
            if (PHLoad().count) PHApplyKnownWebViews();
        }];
    });
}
