#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V18 preload filter.
 * Generic: no target application identifier is used.
 * Saved css-display-none filters are injected at DocumentStart, before page content is visibly interactive.
 */

static NSString *PH18FilterPath(void) {
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

static NSArray<NSString *> *PH18DisplayNoneSelectors(void) {
    NSData *data = [NSData dataWithContentsOfFile:PH18FilterPath()];
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

static NSString *PH18ScriptForSelectors(NSArray<NSString *> *selectors) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:selectors ?: @[] options:0 error:nil];
    NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[]";
    return [NSString stringWithFormat:
        @"(function(){var s=%@;if(!s.length)return;var id='projetoh-preload-style';function apply(){var old=document.getElementById(id);if(old)old.remove();var st=document.createElement('style');st.id=id;st.setAttribute('data-projetoh-preload','1');st.textContent=s.map(function(x){return x+'{display:none !important;}'}).join('\\n');(document.head||document.documentElement).appendChild(st);}try{apply();}catch(e){};try{new MutationObserver(function(){if(!document.getElementById(id))try{apply();}catch(e){}}).observe(document.documentElement,{childList:true,subtree:true});}catch(e){}})();", json];
}

static void PH18InjectIntoConfiguration(WKWebViewConfiguration *configuration) {
    if (!configuration) return;
    NSArray<NSString *> *selectors = PH18DisplayNoneSelectors();
    if (!selectors.count) return;
    WKUserContentController *controller = configuration.userContentController;
    if (!controller) return;

    static const void *kPH18Installed = &kPH18Installed;
    if ([objc_getAssociatedObject(controller, kPH18Installed) boolValue]) return;

    NSString *source = PH18ScriptForSelectors(selectors);
    WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                    injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                 forMainFrameOnly:NO];
    [controller addUserScript:script];
    objc_setAssociatedObject(controller, kPH18Installed, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static IMP PH18OriginalInitWithFrame = NULL;
static IMP PH18OriginalInitWithCoder = NULL;

static id PH18InitWithFrameConfiguration(id self, SEL _cmd, CGRect frame, WKWebViewConfiguration *configuration) {
    PH18InjectIntoConfiguration(configuration);
    return ((id (*)(id, SEL, CGRect, WKWebViewConfiguration *))PH18OriginalInitWithFrame)(self, _cmd, frame, configuration);
}

static id PH18InitWithCoder(id self, SEL _cmd, NSCoder *coder) {
    id web = ((id (*)(id, SEL, NSCoder *))PH18OriginalInitWithCoder)(self, _cmd, coder);
    if (web) PH18InjectIntoConfiguration([(WKWebView *)web configuration]);
    return web;
}

__attribute__((constructor)) static void PHV18Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = WKWebView.class;

        SEL frameSEL = @selector(initWithFrame:configuration:);
        Method frameMethod = class_getInstanceMethod(cls, frameSEL);
        if (frameMethod) {
            IMP current = method_getImplementation(frameMethod);
            if (current != (IMP)PH18InitWithFrameConfiguration) {
                PH18OriginalInitWithFrame = current;
                method_setImplementation(frameMethod, (IMP)PH18InitWithFrameConfiguration);
            }
        }

        SEL coderSEL = @selector(initWithCoder:);
        Method coderMethod = class_getInstanceMethod(cls, coderSEL);
        if (coderMethod) {
            IMP current = method_getImplementation(coderMethod);
            if (current != (IMP)PH18InitWithCoder) {
                PH18OriginalInitWithCoder = current;
                method_setImplementation(coderMethod, (IMP)PH18InitWithCoder);
            }
        }
    });
}
