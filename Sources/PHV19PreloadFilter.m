#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V20 preload filter.
 * Generic: no target application identifier is used.
 * Test mode: deliberately leaves the page unfiltered for 3 seconds,
 * then installs the saved css-display-none rules. This isolates whether
 * the visible element is coming from the page before our filter activates.
 */

static NSString *PHV20FilterPath(void) {
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

static NSArray<NSString *> *PHV20DisplayNoneSelectors(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHV20FilterPath()];
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

static NSString *PHV20ScriptForSelectors(NSArray<NSString *> *selectors) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:selectors ?: @[] options:0 error:nil];
    NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[]";

    return [NSString stringWithFormat:
        @"(function(){var s=%@;if(!s.length)return;var id='projetoh-preload-style';function install(){if(document.getElementById(id))return;var st=document.createElement('style');st.id=id;st.setAttribute('data-projetoh-preload','1');st.textContent=s.map(function(x){return x+'{display:none !important;}'}).join('\\n');var p=document.head||document.documentElement;if(p)p.appendChild(st);}setTimeout(function(){try{install();}catch(e){}try{new MutationObserver(function(){try{install();}catch(e){}}).observe(document.documentElement,{childList:true,subtree:true});}catch(e){}},3000);})();", json];
}

static void PHV20InjectIntoConfiguration(WKWebViewConfiguration *configuration) {
    if (!configuration) return;
    WKUserContentController *controller = configuration.userContentController;
    if (!controller) return;

    static const void *kPHV20Installed = &kPHV20Installed;
    if ([objc_getAssociatedObject(controller, kPHV20Installed) boolValue]) return;

    NSArray<NSString *> *selectors = PHV20DisplayNoneSelectors();
    if (!selectors.count) return;

    NSString *source = PHV20ScriptForSelectors(selectors);
    WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                    injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                 forMainFrameOnly:NO];
    [controller addUserScript:script];
    objc_setAssociatedObject(controller, kPHV20Installed, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void PHV20PrepareWebView(WKWebView *web) {
    if (!web) return;
    PHV20InjectIntoConfiguration(web.configuration);
}

static IMP PHV20OriginalInitWithFrameConfiguration = NULL;
static IMP PHV20OriginalInitWithCoder = NULL;
static IMP PHV20OriginalLoadRequest = NULL;
static IMP PHV20OriginalLoadHTML = NULL;
static IMP PHV20OriginalLoadFile = NULL;
static IMP PHV20OriginalLoadData = NULL;

static id PHV20InitWithFrameConfiguration(id self, SEL _cmd, CGRect frame, WKWebViewConfiguration *configuration) {
    PHV20InjectIntoConfiguration(configuration);
    return ((id (*)(id, SEL, CGRect, WKWebViewConfiguration *))PHV20OriginalInitWithFrameConfiguration)(self, _cmd, frame, configuration);
}

static id PHV20InitWithCoder(id self, SEL _cmd, NSCoder *coder) {
    id web = ((id (*)(id, SEL, NSCoder *))PHV20OriginalInitWithCoder)(self, _cmd, coder);
    if (web) PHV20PrepareWebView((WKWebView *)web);
    return web;
}

static WKNavigation *PHV20LoadRequest(id self, SEL _cmd, NSURLRequest *request) {
    PHV20PrepareWebView((WKWebView *)self);
    return ((WKNavigation *(*)(id, SEL, NSURLRequest *))PHV20OriginalLoadRequest)(self, _cmd, request);
}

static WKNavigation *PHV20LoadHTML(id self, SEL _cmd, NSString *string, NSURL *baseURL) {
    PHV20PrepareWebView((WKWebView *)self);
    return ((WKNavigation *(*)(id, SEL, NSString *, NSURL *))PHV20OriginalLoadHTML)(self, _cmd, string, baseURL);
}

static WKNavigation *PHV20LoadFile(id self, SEL _cmd, NSURL *URL, NSURL *readURL) {
    PHV20PrepareWebView((WKWebView *)self);
    return ((WKNavigation *(*)(id, SEL, NSURL *, NSURL *))PHV20OriginalLoadFile)(self, _cmd, URL, readURL);
}

static WKNavigation *PHV20LoadData(id self, SEL _cmd, NSData *data, NSString *MIMEType, NSString *encoding, NSURL *baseURL) {
    PHV20PrepareWebView((WKWebView *)self);
    return ((WKNavigation *(*)(id, SEL, NSData *, NSString *, NSString *, NSURL *))PHV20OriginalLoadData)(self, _cmd, data, MIMEType, encoding, baseURL);
}

__attribute__((constructor)) static void PHV20Install(void) {
    Class cls = WKWebView.class;

    Method m = class_getInstanceMethod(cls, @selector(initWithFrame:configuration:));
    if (m) {
        PHV20OriginalInitWithFrameConfiguration = method_getImplementation(m);
        method_setImplementation(m, (IMP)PHV20InitWithFrameConfiguration);
    }

    m = class_getInstanceMethod(cls, @selector(initWithCoder:));
    if (m) {
        PHV20OriginalInitWithCoder = method_getImplementation(m);
        method_setImplementation(m, (IMP)PHV20InitWithCoder);
    }

    m = class_getInstanceMethod(cls, @selector(loadRequest:));
    if (m) {
        PHV20OriginalLoadRequest = method_getImplementation(m);
        method_setImplementation(m, (IMP)PHV20LoadRequest);
    }

    m = class_getInstanceMethod(cls, @selector(loadHTMLString:baseURL:));
    if (m) {
        PHV20OriginalLoadHTML = method_getImplementation(m);
        method_setImplementation(m, (IMP)PHV20LoadHTML);
    }

    m = class_getInstanceMethod(cls, @selector(loadFileURL:allowingReadAccessToURL:));
    if (m) {
        PHV20OriginalLoadFile = method_getImplementation(m);
        method_setImplementation(m, (IMP)PHV20LoadFile);
    }

    m = class_getInstanceMethod(cls, @selector(loadData:MIMEType:textEncodingName:baseURL:));
    if (m) {
        PHV20OriginalLoadData = method_getImplementation(m);
        method_setImplementation(m, (IMP)PHV20LoadData);
    }
}
