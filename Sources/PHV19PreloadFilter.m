#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V19 preload filter.
 * Generic: no target application identifier is used.
 * Key difference from V18: the runtime hooks are installed synchronously from
 * the constructor, so the app cannot create its first WKWebView before the
 * initWithFrame:configuration: hook is active.
 */

static NSString *PHV19FilterPath(void) {
    static NSString *cached;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *r = nil;
        while ((r = [e nextObject])) {
            if ([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                cached = [home stringByAppendingPathComponent:r];
                break;
            }
        }
        if (!cached.length) cached = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    return cached;
}

static NSArray<NSString *> *PHV19DisplayNoneSelectors(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHV19FilterPath()];
    if (!data) return @[];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    if (![json isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<NSString *> *selectors = [NSMutableArray array];
    for (NSDictionary *filter in (NSArray *)json) {
        if (![filter isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *action = [filter[@"action"] isKindOfClass:NSDictionary.class] ? filter[@"action"] : nil;
        NSString *type = [action[@"type"] isKindOfClass:NSString.class] ? action[@"type"] : nil;
        NSString *selector = [action[@"selector"] isKindOfClass:NSString.class] ? action[@"selector"] : nil;
        if ([type isEqualToString:@"css-display-none"] && selector.length) [selectors addObject:selector];
    }
    return selectors.copy;
}

static NSString *PHV19ScriptForSelectors(NSArray<NSString *> *selectors) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:selectors ?: @[] options:0 error:nil];
    NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[]";

    return [NSString stringWithFormat:
        @"(function(){var s=%@;if(!s.length)return;var id='projetoh-preload-style';function install(){if(document.getElementById(id))return;var st=document.createElement('style');st.id=id;st.setAttribute('data-projetoh-preload','1');st.textContent=s.map(function(x){return x+'{display:none !important;}'}).join('\\n');var p=document.head||document.documentElement;if(p)p.appendChild(st);}try{install();}catch(e){}try{new MutationObserver(function(){try{install();}catch(e){}}).observe(document.documentElement,{childList:true,subtree:true});}catch(e){}})();", json];
}

static void PHV19InjectIntoConfiguration(WKWebViewConfiguration *configuration) {
    if (!configuration) return;
    WKUserContentController *controller = configuration.userContentController;
    if (!controller) return;

    static const void *kPHV19Installed = &kPHV19Installed;
    if ([objc_getAssociatedObject(controller, kPHV19Installed) boolValue]) return;

    NSArray<NSString *> *selectors = PHV19DisplayNoneSelectors();
    if (!selectors.count) return;

    NSString *source = PHV19ScriptForSelectors(selectors);
    WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                    injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                 forMainFrameOnly:NO];
    [controller addUserScript:script];
    objc_setAssociatedObject(controller, kPHV19Installed, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static IMP PHV19OriginalInitWithFrame = NULL;
static IMP PHV19OriginalInitWithCoder = NULL;

static id PHV19InitWithFrameConfiguration(id self, SEL _cmd, CGRect frame, WKWebViewConfiguration *configuration) {
    PHV19InjectIntoConfiguration(configuration);
    return ((id (*)(id, SEL, CGRect, WKWebViewConfiguration *))PHV19OriginalInitWithFrame)(self, _cmd, frame, configuration);
}

static id PHV19InitWithCoder(id self, SEL _cmd, NSCoder *coder) {
    id web = ((id (*)(id, SEL, NSCoder *))PHV19OriginalInitWithCoder)(self, _cmd, coder);
    if (web) PHV19InjectIntoConfiguration([(WKWebView *)web configuration]);
    return web;
}

__attribute__((constructor)) static void PHV19Install(void) {
    /* Deliberately synchronous. Waiting for the main queue can let the host
       construct its first WKWebView before our preload hook is installed. */
    Class cls = WKWebView.class;

    Method frameMethod = class_getInstanceMethod(cls, @selector(initWithFrame:configuration:));
    if (frameMethod) {
        IMP current = method_getImplementation(frameMethod);
        if (current != (IMP)PHV19InitWithFrameConfiguration) {
            PHV19OriginalInitWithFrame = current;
            method_setImplementation(frameMethod, (IMP)PHV19InitWithFrameConfiguration);
        }
    }

    Method coderMethod = class_getInstanceMethod(cls, @selector(initWithCoder:));
    if (coderMethod) {
        IMP current = method_getImplementation(coderMethod);
        if (current != (IMP)PHV19InitWithCoder) {
            PHV19OriginalInitWithCoder = current;
            method_setImplementation(coderMethod, (IMP)PHV19InitWithCoder);
        }
    }
}
