#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V15 compatibility layer.
 * Generic: no target application identifier is used.
 * It refines the existing V13 manager without replacing its core behavior.
 */

static NSString *PH15FilterPath(void) {
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *r;
        while ((r = [e nextObject])) {
            if ([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                path = [home stringByAppendingPathComponent:r]; break;
            }
        }
        if (!path.length) path = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    return path;
}

static NSString *PH15MetadataPath(void) {
    return [PH15FilterPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"projetoh-metadata.json"];
}

static NSMutableDictionary *PH15Metadata(void) {
    NSData *d = [NSData dataWithContentsOfFile:PH15MetadataPath()];
    id j = d ? [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil] : nil;
    NSDictionary *e = [j isKindOfClass:NSDictionary.class] && [j[@"elements"] isKindOfClass:NSDictionary.class] ? j[@"elements"] : nil;
    return e ? [e mutableCopy] : [NSMutableDictionary dictionary];
}

static void PH15WriteMetadata(NSDictionary *elements) {
    if (!elements.count) {
        [NSFileManager.defaultManager removeItemAtPath:PH15MetadataPath() error:nil];
        return;
    }
    NSDictionary *root = @{ @"version": @1, @"elements": elements };
    NSData *d = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    if (d) [d writeToFile:PH15MetadataPath() atomically:YES];
}

static NSArray *PH15Filters(void) {
    NSData *d = [NSData dataWithContentsOfFile:PH15FilterPath()];
    id j = d ? [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil] : nil;
    if ([j isKindOfClass:NSDictionary.class]) j = j[@"filters"];
    return [j isKindOfClass:NSArray.class] ? j : @[];
}

static NSString *PH15Selector(NSDictionary *f) {
    if (![f isKindOfClass:NSDictionary.class]) return nil;
    id s = f[@"selector"];
    if ([s isKindOfClass:NSString.class] && [s length]) return s;
    NSDictionary *a = [f[@"action"] isKindOfClass:NSDictionary.class] ? f[@"action"] : nil;
    s = a[@"selector"];
    return [s isKindOfClass:NSString.class] && [s length] ? s : nil;
}

static void PH15WriteFilters(NSArray *filters) {
    NSString *path = PH15FilterPath();
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *d = [NSJSONSerialization dataWithJSONObject:@{ @"version": @1, @"filters": filters ?: @[] } options:0 error:nil];
    if (d) [d writeToFile:path atomically:YES];
}

static NSString *PH15Trim(NSString *s) {
    s = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!s.length) return nil;
    return s.length > 30 ? [[s substringToIndex:30] stringByAppendingString:@"…"] : s;
}

static NSString *PH15Name(NSDictionary *m) {
    NSString *tag = [m[@"tag"] isKindOfClass:NSString.class] ? [m[@"tag"] lowercaseString] : @"";
    if ([tag isEqualToString:@"lottie-player"]) return @"Lottie Player";
    for (NSString *key in @[ @"ariaLabel", @"text", @"title" ]) {
        NSString *v = PH15Trim([m[key] isKindOfClass:NSString.class] ? m[key] : nil);
        if (v.length) return v;
    }
    NSString *v = PH15Trim([m[@"id"] isKindOfClass:NSString.class] ? m[@"id"] : nil);
    if (v.length) return [NSString stringWithFormat:@"#%@", v];
    NSString *classes = [m[@"className"] isKindOfClass:NSString.class] ? m[@"className"] : @"";
    for (NSString *c in [classes componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
        if (!c.length || [c hasPrefix:@"ng-"] || [c hasPrefix:@"css-"] || [c hasPrefix:@"sc-"] || [c hasPrefix:@"jsx-"]) continue;
        if ([c isEqualToString:@"active"] || [c isEqualToString:@"selected"] || [c isEqualToString:@"disabled"]) continue;
        NSString *q = PH15Trim(c);
        if (q.length) return [NSString stringWithFormat:@".%@", q];
    }
    return tag.length ? [tag uppercaseString] : @"Elemento Web";
}

static NSMutableDictionary *PH15Pending = nil;

static void PH15CaptureForWebView(WKWebView *web, void (^completion)(NSString *, NSDictionary *)) {
    if (!web || !completion) return;
    NSString *js = @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}return JSON.stringify({selector:p(e),tag:e.tagName.toLowerCase(),id:e.id||'',className:typeof e.className==='string'?e.className:'',text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,180),ariaLabel:e.getAttribute('aria-label')||'',title:e.getAttribute('title')||''});})()";
    [web evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) return;
        NSData *d = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *m = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        NSString *s = [m[@"selector"] isKindOfClass:NSString.class] ? m[@"selector"] : nil;
        if (!s.length) return;
        NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:m ?: @{}];
        entry[@"name"] = PH15Name(entry);
        if (!PH15Pending) PH15Pending = [NSMutableDictionary dictionary];
        PH15Pending[s] = entry;
        completion(s, entry);
    }];
}

static void PH15Restore(WKWebView *web, NSString *selector) {
    if (!web || !selector.length) return;
    NSData *d = [NSJSONSerialization dataWithJSONObject:@[selector] options:0 error:nil];
    NSString *j = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display');})}catch(e){}});", j ?: @"[]"];
    [web evaluateJavaScript:js completionHandler:nil];
}

static void PH15SyncSavedMetadata(void) {
    NSArray *filters = PH15Filters();
    NSMutableDictionary *meta = PH15Metadata();
    NSMutableSet *live = [NSMutableSet set];
    for (NSDictionary *f in filters) {
        NSString *s = PH15Selector(f);
        if (s.length) [live addObject:s];
    }
    for (NSString *s in meta.allKeys.copy) if (![live containsObject:s]) [meta removeObjectForKey:s];
    [PH15Pending enumerateKeysAndObjectsUsingBlock:^(NSString *s, NSDictionary *m, BOOL *stop) {
        if ([live containsObject:s]) meta[s] = m;
    }];
    PH15WriteMetadata(meta);
    for (NSString *s in PH15Pending.allKeys.copy) if ([live containsObject:s]) [PH15Pending removeObjectForKey:s];
}

static id PH15CurrentWebView(id self) {
    @try { return [self valueForKey:@"highlightedWebView"]; } @catch (__unused NSException *e) { return nil; }
}
static id PH15Inspector(id self) {
    @try { return [self valueForKey:@"inspectorViewController"]; } @catch (__unused NSException *e) { return nil; }
}

static void PH15Swizzle(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original), b = class_getInstanceMethod(cls, replacement);
    if (a && b) method_exchangeImplementations(a, b);
}

@interface NSObject (PHV15)
- (void)ph15_hideSelectedElement;
- (void)ph15_savePendingFilters;
- (void)ph15_showHiddenElements;
- (void)ph15_render:(BOOL)hierarchyMode;
@end

@implementation NSObject (PHV15)

- (void)ph15_hideSelectedElement {
    WKWebView *web = PH15CurrentWebView(self);
    PH15CaptureForWebView(web, ^(__unused NSString *selector, __unused NSDictionary *entry) {
        // Pending metadata is memory-only. It is persisted only after the existing Save flow has actually written the filter.
    });
    [self ph15_hideSelectedElement];
}

- (void)ph15_savePendingFilters {
    [self ph15_savePendingFilters];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PH15SyncSavedMetadata();
    });
}

- (void)ph15_showHiddenElements {
    NSArray *filters = PH15Filters();
    UIViewController *vc = PH15Inspector(self);
    if (!vc) { [self ph15_showHiddenElements]; return; }

    NSMutableDictionary *meta = PH15Metadata();
    NSMutableDictionary *counts = [NSMutableDictionary dictionary];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Elementos ocultos"
        message:[NSString stringWithFormat:@"%lu item(ns) salvo(s) em custom-filters.json", (unsigned long)filters.count]
        preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *f in filters) {
        NSString *selector = PH15Selector(f); if (!selector.length) continue;
        NSString *name = PH15Name(meta[selector]);
        if (!name.length) name = @"Elemento Web";
        NSInteger n = [counts[name] integerValue] + 1; counts[name] = @(n);
        if (n > 1) {
            NSString *suffix = [NSString stringWithFormat:@" #%ld", (long)n];
            NSUInteger maxBase = 30 > suffix.length ? 30 - suffix.length : 1;
            NSString *base = name.length > maxBase ? [[name substringToIndex:maxBase] stringByAppendingString:@"…"] : name;
            name = [NSString stringWithFormat:@"%@%@", base, suffix];
        }
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@", name] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSMutableArray *cur = [PH15Filters() mutableCopy];
            NSIndexSet *idx = [cur indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger i, BOOL *stop) { return [PH15Selector(item) isEqualToString:selector]; }];
            [cur removeObjectsAtIndexes:idx];
            PH15WriteFilters(cur);
            [meta removeObjectForKey:selector]; PH15WriteMetadata(meta);
            if (PH15Pending) { [PH15Pending removeObjectForKey:selector]; }
            PH15Restore(PH15CurrentWebView(self), selector);
            [self ph15_render:NO];
        }]];
    }
    if (filters.count) [a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        for (NSDictionary *f in PH15Filters()) PH15Restore(PH15CurrentWebView(self), PH15Selector(f));
        PH15WriteFilters(@[]); PH15WriteMetadata(@{}); [PH15Pending removeAllObjects];
        [self ph15_render:NO];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = vc.view;
    a.popoverPresentationController.sourceRect = vc.view.bounds;
    [vc presentViewController:a animated:YES completion:nil];
}

- (void)ph15_render:(BOOL)hierarchyMode {
    [self ph15_render:hierarchyMode];
    // The existing V13 layout puts Ocultar on the left and Ocultos in the center. Swap titles and actions so the actual controls become: Ocultos | Ocultar | Salvar.
    UIViewController *vc = PH15Inspector(self);
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

__attribute__((constructor)) static void PHV15Init(void) {
    PH15Pending = [NSMutableDictionary dictionary];
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHOverlayManager");
        if (!cls) return;
        PH15Swizzle(cls, @selector(hideSelectedElement), @selector(ph15_hideSelectedElement));
        PH15Swizzle(cls, @selector(savePendingFilters), @selector(ph15_savePendingFilters));
        PH15Swizzle(cls, @selector(showHiddenElements), @selector(ph15_showHiddenElements));
        PH15Swizzle(NSClassFromString(@"PHInspectorViewController"), @selector(render:), @selector(ph15_render:));
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(__unused NSTimer *t){ PH15SyncSavedMetadata(); }];
    });
}
