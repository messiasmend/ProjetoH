#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V21 filter fix.
 * Generic: no target bundle identifier is used.
 *
 * The native WebFrame format is:
 *   { "action": { "type": "css-display-none", "selector": "..." },
 *     "trigger": { "url-filter": ".*" } }
 *
 * The existing inspector stores selector-only entries and currently builds
 * fragile nth-of-type paths from the deepest clicked node. This shim keeps
 * the existing UI flow, but at Save time asks the selected DOM for a stable
 * selector, preferring a meaningful ancestor class (for example
 * .q-page-sticky) over the generated nth-of-type path.
 */

static NSString *PHV21FilterPath(void) {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *r = nil;
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

static NSDictionary *PHV21NativeFilter(NSDictionary *filter, NSString *selectorOverride) {
    if (![filter isKindOfClass:NSDictionary.class]) return nil;

    NSDictionary *action = [filter[@"action"] isKindOfClass:NSDictionary.class] ? filter[@"action"] : nil;
    NSDictionary *trigger = [filter[@"trigger"] isKindOfClass:NSDictionary.class] ? filter[@"trigger"] : nil;

    NSString *selector = selectorOverride.length ? selectorOverride : nil;
    if (!selector.length) selector = [action[@"selector"] isKindOfClass:NSString.class] ? action[@"selector"] : nil;
    if (!selector.length) selector = [filter[@"selector"] isKindOfClass:NSString.class] ? filter[@"selector"] : nil;
    if (!selector.length) return nil;

    NSString *type = [action[@"type"] isKindOfClass:NSString.class] ? action[@"type"] : @"css-display-none";
    NSString *urlFilter = [trigger[@"url-filter"] isKindOfClass:NSString.class] ? trigger[@"url-filter"] : @".*";

    return @{
        @"action": @{
            @"type": type,
            @"selector": selector
        },
        @"trigger": @{
            @"url-filter": urlFilter
        }
    };
}

static void PHV21NormalizeSavedFilters(NSString *stableSelector) {
    NSString *path = PHV21FilterPath();
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return;

    id root = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    NSArray *filters = nil;
    if ([root isKindOfClass:NSDictionary.class]) filters = [root[@"filters"] isKindOfClass:NSArray.class] ? root[@"filters"] : nil;
    else if ([root isKindOfClass:NSArray.class]) filters = root;
    if (!filters) return;

    NSMutableArray *native = [NSMutableArray arrayWithCapacity:filters.count];
    for (NSUInteger i = 0; i < filters.count; i++) {
        NSDictionary *filter = filters[i];
        NSString *override = (i == filters.count - 1) ? stableSelector : nil;
        NSDictionary *converted = PHV21NativeFilter(filter, override);
        if (converted) [native addObject:converted];
    }

    NSData *out = [NSJSONSerialization dataWithJSONObject:native options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    if (out) [out writeToFile:path atomically:YES];
}

static NSString *PHV21StableSelectorScript(void) {
    return @"(function(){\
var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');\
if(!e)return '';\
function esc(s){try{return CSS.escape(s)}catch(_){return s.replace(/[^a-zA-Z0-9_-]/g,'\\\\$&')}}\
function unique(sel){try{return document.querySelectorAll(sel).length===1}catch(_){return false}}\
function classCandidates(n){\
  if(!n||typeof n.className!=='string')return [];\
  var a=n.className.trim().split(/\\s+/).filter(Boolean);\
  var preferred=a.filter(function(c){return c==='q-page-sticky'||c.indexOf('page-sticky')>=0||c.indexOf('floating')>=0||c.indexOf('component')>=0||c.indexOf('overlay')>=0||c.indexOf('panel')>=0;});\
  var normal=a.filter(function(c){return ['row','col','flex','flex-center','justify-center','items-center','no-wrap','q-focus-helper','q-icon','q-btn','q-btn__content','q-btn-item','non-selectable','notranslate','material-icons','mobile','platform-ios','touch'].indexOf(c)<0;});\
  return preferred.concat(normal.filter(function(c){return preferred.indexOf(c)<0;}));\
}\
function findStable(start){\
  var n=start;\
  while(n&&n.nodeType===1&&n!==document.body){\
    if(n!==start&&n.id){var id='[id=\\\"'+esc(n.id)+'\\\"]';if(unique(id))return id;}\
    var cs=classCandidates(n);\
    for(var i=0;i<cs.length;i++){var s='.'+esc(cs[i]);if(unique(s))return s;}\
    n=n.parentElement;\
  }\
  if(start.id){var sid='[id=\\\"'+esc(start.id)+'\\\"]';if(unique(sid))return sid;}\
  var own=classCandidates(start);\
  for(var j=0;j<own.length;j++){var os='.'+esc(own[j]);if(unique(os))return os;}\
  return '';\
}\
return findStable(e);\
})()";
}

static IMP PHV21OriginalSave = NULL;

static void PHV21SavePendingFilters(id self, SEL _cmd) {
    if (PHV21OriginalSave) {
        ((void (*)(id, SEL))PHV21OriginalSave)(self, _cmd);
    }

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"highlightedWebView"]; } @catch (__unused NSException *e) {}

    if (![webView isKindOfClass:WKWebView.class]) {
        PHV21NormalizeSavedFilters(nil);
        return;
    }

    /* Do not block the WebKit/main thread waiting for JavaScript. The original
     * Save has already completed; we only rewrite the just-saved rule when the
     * DOM returns the stable selector. */
    NSString *script = PHV21StableSelectorScript();
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        NSString *stable = (!error && [result isKindOfClass:NSString.class] && [(NSString *)result length]) ? result : nil;
        PHV21NormalizeSavedFilters(stable);
    }];
}

__attribute__((constructor)) static void PHV21Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHOverlayManager");
        if (!cls) return;

        Method method = class_getInstanceMethod(cls, @selector(savePendingFilters));
        if (!method) return;

        IMP current = method_getImplementation(method);
        if (current == (IMP)PHV21SavePendingFilters) return;

        PHV21OriginalSave = current;
        method_setImplementation(method, (IMP)PHV21SavePendingFilters);
    });
}
