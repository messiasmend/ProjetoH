#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V21
 * Generic: no target application identifier is used.
 * The WebFrame custom-filters.json remains the source of truth for hiding.
 */

static NSString *PH21FilterPath(void) {
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

static NSString *PH21MetadataPath(void) {
    return [PH21FilterPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"projetoh-metadata.json"];
}

static NSMutableDictionary *PH21Metadata(void) {
    NSData *d = [NSData dataWithContentsOfFile:PH21MetadataPath()];
    id j = d ? [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil] : nil;
    NSDictionary *e = [j isKindOfClass:NSDictionary.class] && [j[@"elements"] isKindOfClass:NSDictionary.class] ? j[@"elements"] : nil;
    return e ? [e mutableCopy] : [NSMutableDictionary dictionary];
}

static void PH21WriteMetadata(NSDictionary *elements) {
    if (!elements.count) {
        [NSFileManager.defaultManager removeItemAtPath:PH21MetadataPath() error:nil];
        return;
    }
    NSDictionary *root = @{ @"version": @1, @"elements": elements };
    NSData *d = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    if (d) [d writeToFile:PH21MetadataPath() atomically:YES];
}

static NSArray *PH21Filters(void) {
    NSData *d = [NSData dataWithContentsOfFile:PH21FilterPath()];
    id j = d ? [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil] : nil;
    if ([j isKindOfClass:NSDictionary.class]) j = j[@"filters"];
    return [j isKindOfClass:NSArray.class] ? j : @[];
}

static NSString *PH21Selector(NSDictionary *f) {
    if (![f isKindOfClass:NSDictionary.class]) return nil;
    id s = f[@"selector"];
    if ([s isKindOfClass:NSString.class] && s.length) return s;
    NSDictionary *a = [f[@"action"] isKindOfClass:NSDictionary.class] ? f[@"action"] : nil;
    s = a[@"selector"];
    return [s isKindOfClass:NSString.class] && s.length ? s : nil;
}

static NSString *PH21Trim(NSString *s) {
    s = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!s.length) return nil;
    return s.length > 30 ? [[s substringToIndex:30] stringByAppendingString:@"…"] : s;
}

static NSString *PH21Name(NSDictionary *m) {
    NSString *tag = [m[@"tag"] isKindOfClass:NSString.class] ? [m[@"tag"] lowercaseString] : @"";
    if ([tag isEqualToString:@"lottie-player"]) return @"Lottie Player";
    for (NSString *key in @[ @"ariaLabel", @"text", @"title" ]) {
        NSString *v = PH21Trim([m[key] isKindOfClass:NSString.class] ? m[key] : nil);
        if (v.length) return v;
    }
    NSString *v = PH21Trim([m[@"id"] isKindOfClass:NSString.class] ? m[@"id"] : nil);
    if (v.length) return [NSString stringWithFormat:@"#%@", v];
    NSString *classes = [m[@"className"] isKindOfClass:NSString.class] ? m[@"className"] : @"";
    for (NSString *c in [classes componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
        if (!c.length || [c hasPrefix:@"ng-"] || [c hasPrefix:@"css-"] || [c hasPrefix:@"sc-"] || [c hasPrefix:@"jsx-"]) continue;
        if ([c isEqualToString:@"active"] || [c isEqualToString:@"selected"] || [c isEqualToString:@"disabled"]) continue;
        NSString *q = PH21Trim(c);
        if (q.length) return [NSString stringWithFormat:@".%@", q];
    }
    return tag.length ? [tag uppercaseString] : @"Elemento Web";
}

static NSMutableDictionary *PH21Pending = nil;

static void PH21CaptureForWebView(WKWebView *web, void (^completion)(NSString *, NSDictionary *)) {
    if (!web || !completion) return;
    NSString *js = @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}return JSON.stringify({selector:p(e),tag:e.tagName.toLowerCase(),id:e.id||'',className:typeof e.className==='string'?e.className:'',text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,180),ariaLabel:e.getAttribute('aria-label')||'',title:e.getAttribute('title')||''});})()";
    [web evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) return;
        NSData *d = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *m = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        NSString *s = [m[@"selector"] isKindOfClass:NSString.class] ? m[@"selector"] : nil;
        if (!s.length) return;
        NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:m ?: @{}];
        entry[@"name"] = PH21Name(entry);
        if (!PH21Pending) PH21Pending = [NSMutableDictionary dictionary];
        PH21Pending[s] = entry;
        completion(s, entry);
    }];
}

static void PH21SyncSavedMetadata(void) {
    NSArray *filters = PH21Filters();
    NSMutableDictionary *meta = PH21Metadata();
    NSMutableSet *live = [NSMutableSet set];
    for (NSDictionary *f in filters) {
        NSString *s = PH21Selector(f);
        if (s.length) [live addObject:s];
    }
    for (NSString *s in meta.allKeys.copy) if (![live containsObject:s]) [meta removeObjectForKey:s];
    [PH21Pending enumerateKeysAndObjectsUsingBlock:^(NSString *s, NSDictionary *m, BOOL *stop) {
        if ([live containsObject:s]) meta[s] = m;
    }];
    PH21WriteMetadata(meta);
    for (NSString *s in PH21Pending.allKeys.copy) if ([live containsObject:s]) [PH21Pending removeObjectForKey:s];
}

static id PH21CurrentWebView(id self) {
    @try { return [self valueForKey:@"highlightedWebView"]; } @catch (__unused NSException *e) { return nil; }
}
static id PH21Inspector(id self) {
    @try { return [self valueForKey:@"inspectorViewController"]; } @catch (__unused NSException *e) { return nil; }
}

static void PH21Swizzle(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original), b = class_getInstanceMethod(cls, replacement);
    if (a && b) method_exchangeImplementations(a, b);
}

@interface NSObject (PHV21)
- (void)ph21_hideSelectedElement;
- (void)ph21_savePendingFilters;
- (void)ph21_showHiddenElements;
- (void)ph21_render:(BOOL)hierarchyMode;
@end

@implementation NSObject (PHV21)

- (void)ph21_hideSelectedElement {
    WKWebView *web = PH21CurrentWebView(self);
    PH21CaptureForWebView(web, ^(__unused NSString *selector, __unused NSDictionary *entry) {
        // Capture only. The original hide action remains responsible for writing the native WebFrame filter.
    });
    [self ph21_hideSelectedElement];
}

- (void)ph21_savePendingFilters {
    [self ph21_savePendingFilters];
    // Metadata is synchronized once, immediately after the existing Save flow.
    PH21SyncSavedMetadata();
}

- (void)ph21_showHiddenElements {
    NSArray *filters = PH21Filters();
    UIViewController *vc = PH21Inspector(self);
    if (!vc) { [self ph21_showHiddenElements]; return; }

    NSMutableDictionary *meta = PH21Metadata();
    NSMutableDictionary *counts = [NSMutableDictionary dictionary];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Elementos ocultos"
        message:[NSString stringWithFormat:@"%lu item(ns) salvo(s) em custom-filters.json", (unsigned long)filters.count]
        preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *f in filters) {
        NSString *selector = PH21Selector(f); if (!selector.length) continue;
        NSString *name = PH21Name(meta[selector]);
        if (!name.length) name = @"Elemento Web";
        NSInteger n = [counts[name] integerValue] + 1; counts[name] = @(n);
        if (n > 1) {
            NSString *suffix = [NSString stringWithFormat:@" #%ld", (long)n];
            NSUInteger maxBase = 30 > suffix.length ? 30 - suffix.length : 1;
            NSString *base = name.length > maxBase ? [[name substringToIndex:maxBase] stringByAppendingString:@"…"] : name;
            name = [NSString stringWithFormat:@"%@%@", base, suffix];
        }
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@", name] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSMutableArray *cur = [PH21Filters() mutableCopy];
            NSIndexSet *idx = [cur indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger i, BOOL *stop) { return [PH21Selector(item) isEqualToString:selector]; }];
            [cur removeObjectsAtIndexes:idx];
            // The original WebFrame filter file format is preserved by the host's Save/Remove flow.
            // Do not inject a second, competing filter format here.
            [self ph21_render:NO];
            PH21SyncSavedMetadata();
        }]];
    }
    if (filters.count) [a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self ph21_render:NO];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = vc.view;
    a.popoverPresentationController.sourceRect = vc.view.bounds;
    [vc presentViewController:a animated:YES completion:nil];
}

- (void)ph21_render:(BOOL)hierarchyMode {
    [self ph21_render:hierarchyMode];
    UIViewController *vc = PH21Inspector(self);
    if (!vc) return;
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *v in vc.view.subviews) {
        if ([v isKindOfClass:UIButton.class]) [buttons addObject:v];
        for (UIView *s in v.subviews) if ([s isKindOfClass:UIButton.class]) [buttons addObject:s];
    }
    UIButton *hide = nil, *hidden = nil;
    for (UIButton *b in buttons) {
        NSString *t = [b titleForState:UIControlStateNormal];
        if ([t isEqualToString:@"Ocultar"]) hide = b;
        else if ([t isEqualToString:@"Ocultos"]) hidden = b;
    }
    if (hide && hidden) {
        [hide removeTarget:vc action:@selector(hideTapped) forControlEvents:UIControlEventTouchUpInside];
        [hidden removeTarget:vc action:@selector(hiddenTapped) forControlEvents:UIControlEventTouchUpInside];
        [hide setTitle:@"Ocultos" forState:UIControlStateNormal];
        [hidden setTitle:@"Ocultar" forState:UIControlStateNormal];
        [hide addTarget:vc action:@selector(hiddenTapped) forControlEvents:UIControlEventTouchUpInside];
        [hidden addTarget:vc action:@selector(hideTapped) forControlEvents:UIControlEventTouchUpInside];
    }
}
@end

__attribute__((constructor)) static void PHV21Init(void) {
    PH21Pending = [NSMutableDictionary dictionary];
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHOverlayManager");
        if (!cls) return;
        PH21Swizzle(cls, @selector(hideSelectedElement), @selector(ph21_hideSelectedElement));
        PH21Swizzle(cls, @selector(savePendingFilters), @selector(ph21_savePendingFilters));
        PH21Swizzle(cls, @selector(showHiddenElements), @selector(ph21_showHiddenElements));
        PH21Swizzle(NSClassFromString(@"PHInspectorViewController"), @selector(render:), @selector(ph21_render:));
    });
}
