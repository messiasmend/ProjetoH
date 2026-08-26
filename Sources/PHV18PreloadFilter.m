#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

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
    NSNumber *installed = objc_getAssociatedObject(controller, kPH18Installed);
    if (installed.boolValue) return;

    NSString *source = PH18ScriptForSelectors(selectors);
    WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                    injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                 forMainFrameOnly:NO];
    [controller addUserScript:script];
    objc_setAssociatedObject(controller, kPH18Installed, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static IMP PH18OriginalInit = NULL;

static id PH18InitWithFrameConfiguration(id self, SEL _cmd, CGRect frame, WKWebViewConfiguration *configuration) {
    PH18InjectIntoConfiguration(configuration);
    return ((id (*)(id, SEL, CGRect, WKWebViewConfiguration *))PH18OriginalInit)(self, _cmd, frame, configuration);
}

__attribute__((constructor)) static void PHV18Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = WKWebView.class;
        SEL sel = @selector(initWithFrame:configuration:);
        Method method = class_getInstanceMethod(cls, sel);
        if (!method) return;
        IMP current = method_getImplementation(method);
        if (current == (IMP)PH18InitWithFrameConfiguration) return;
        PH18OriginalInit = current;
        method_setImplementation(method, (IMP)PH18InitWithFrameConfiguration);
    });
}
