#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V18 preload layer.
 * Generic: no target application identifier is used.
 * Installs saved CSS-display-none filters as a WKUserScript at DocumentStart,
 * so filtered elements are hidden before the page becomes visibly interactive.
 */

static NSString *PH18FilterPath(void) {
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *r;
        while ((r = [e nextObject])) {
            if ([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                path = [home stringByAppendingPathComponent:r];
                break;
            }
        }
        if (!path.length) path = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    return path;
}

static NSArray<NSString *> *PH18CSSSelectors(void) {
    NSData *d = [NSData dataWithContentsOfFile:PH18FilterPath()];
    id json = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
    if (![json isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<NSString *> *selectors = [NSMutableArray array];
    for (id item in (NSArray *)json) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *action = [item[@"action"] isKindOfClass:NSDictionary.class] ? item[@"action"] : nil;
        NSString *type = [action[@"type"] isKindOfClass:NSString.class] ? action[@"type"] : nil;
        NSString *selector = [action[@"selector"] isKindOfClass:NSString.class] ? action[@"selector"] : nil;
        if ([type isEqualToString:@"css-display-none"] && selector.length) {
            [selectors addObject:selector];
        }
    }
    return selectors.copy;
}

static NSString *PH18PreloadJavaScript(void) {
    NSArray<NSString *> *selectors = PH18CSSSelectors();
    if (!selectors.count) return nil;

    NSData *selectorJSON = [NSJSONSerialization dataWithJSONObject:selectors options:0 error:nil];
    NSString *json = selectorJSON ? [[NSString alloc] initWithData:selectorJSON encoding:NSUTF8StringEncoding] : nil;
    if (!json.length) return nil;

    return [NSString stringWithFormat:
        @"(function(){try{var s=%@;if(!s||!s.length)return;var css=s.map(function(x){return x+'{display:none !important;}';}).join('\\n');var st=document.createElement('style');st.id='projetoh-v18-preload';st.type='text/css';st.textContent=css;(document.documentElement||document.head||document).appendChild(st);}catch(e){}})();",
        json];
}

static void PH18InstallOnWebView(WKWebView *web) {
    if (!web) return;
    WKUserContentController *controller = web.configuration.userContentController;
    if (!controller) return;

    NSString *source = PH18PreloadJavaScript();
    if (!source.length) return;

    WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                forMainFrameOnly:NO];
    [controller addUserScript:script];
}

static void PH18Swizzle(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original);
    Method b = class_getInstanceMethod(cls, replacement);
    if (!a || !b) return;
    method_exchangeImplementations(a, b);
}

@interface WKWebView (PHV18Preload)
- (instancetype)ph18_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration;
- (instancetype)ph18_initWithCoder:(NSCoder *)coder;
@end

@implementation WKWebView (PHV18Preload)

- (instancetype)ph18_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    WKWebView *web = [self ph18_initWithFrame:frame configuration:configuration];
    PH18InstallOnWebView(web);
    return web;
}

- (instancetype)ph18_initWithCoder:(NSCoder *)coder {
    WKWebView *web = [self ph18_initWithCoder:coder];
    PH18InstallOnWebView(web);
    return web;
}

@end

__attribute__((constructor)) static void PHV18Init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        PH18Swizzle(WKWebView.class,
                    @selector(initWithFrame:configuration:),
                    @selector(ph18_initWithFrame:configuration:));
        PH18Swizzle(WKWebView.class,
                    @selector(initWithCoder:),
                    @selector(ph18_initWithCoder:));
    });
}
