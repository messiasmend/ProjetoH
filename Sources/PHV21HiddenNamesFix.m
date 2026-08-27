#import "PHOverlayManager.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface PHOverlayManager (PHV21HiddenNamesFix)
- (void)phv21_fix_showHiddenElements;
@end

static NSString *PHV21FilterPath(void) {
    static NSString *cachedPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *relative = nil;
        while ((relative = [e nextObject])) {
            if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                cachedPath = [home stringByAppendingPathComponent:relative];
                break;
            }
        }
        if (!cachedPath.length) cachedPath = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    return cachedPath;
}

static NSMutableArray *PHV21LoadFilters(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHV21FilterPath()];
    if (!data) return [NSMutableArray array];
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    return [json isKindOfClass:NSArray.class] ? [json mutableCopy] : [NSMutableArray array];
}

static BOOL PHV21WriteFilters(NSArray *filters) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"version": @1, @"filters": filters ?: @[] } options:0 error:nil];
    return data && [data writeToFile:PHV21FilterPath() atomically:YES];
}

static NSString *PHV21SelectorFromFilter(NSDictionary *filter) {
    if (![filter isKindOfClass:NSDictionary.class]) return nil;
    NSString *selector = filter[@"selector"];
    if ([selector isKindOfClass:NSString.class] && selector.length) return selector;
    NSDictionary *action = filter[@"action"];
    selector = [action isKindOfClass:NSDictionary.class] ? action[@"selector"] : nil;
    return ([selector isKindOfClass:NSString.class] && selector.length) ? selector : nil;
}

static void PHV21RestoreSelector(WKWebView *webView, NSString *selector) {
    if (!webView || !selector.length) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[selector] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display');})}catch(e){}});", json];
    [webView evaluateJavaScript:script completionHandler:nil];
}

@implementation PHOverlayManager (PHV21HiddenNamesFix)

- (void)phv21_fix_showHiddenElements {
    NSArray *filters = PHV21LoadFilters();
    UIViewController *vc = [self valueForKey:@"inspectorViewController"];
    if (!vc) return;

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Elementos ocultos"
        message:[NSString stringWithFormat:@"%lu item(ns) em custom-filters.json", (unsigned long)filters.count]
        preferredStyle:UIAlertControllerStyleAlert];

    __weak PHOverlayManager *weakSelf = self;
    for (NSDictionary *filter in filters) {
        NSString *selector = PHV21SelectorFromFilter(filter);
        if (!selector.length) continue;
        NSString *shortS = selector.length > 90 ? [[selector substringToIndex:90] stringByAppendingString:@"…"] : selector;
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@", shortS]
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                PHOverlayManager *strongSelf = weakSelf;
                NSMutableArray *cur = PHV21LoadFilters();
                NSIndexSet *idx = [cur indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger i, BOOL *stop) {
                    return [PHV21SelectorFromFilter(item) isEqualToString:selector];
                }];
                [cur removeObjectsAtIndexes:idx];
                PHV21WriteFilters(cur);
                PHV21RestoreSelector([strongSelf valueForKey:@"highlightedWebView"], selector);
            }]];
    }

    if (filters.count) {
        [a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            PHOverlayManager *strongSelf = weakSelf;
            WKWebView *web = [strongSelf valueForKey:@"highlightedWebView"];
            for (NSDictionary *filter in PHV21LoadFilters()) PHV21RestoreSelector(web, PHV21SelectorFromFilter(filter));
            PHV21WriteFilters(@[]);
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

@end

__attribute__((constructor)) static void PHV21HiddenNamesFixInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Method original = class_getInstanceMethod(PHOverlayManager.class, @selector(showHiddenElements));
            Method replacement = class_getInstanceMethod(PHOverlayManager.class, @selector(phv21_fix_showHiddenElements));
            if (original && replacement) method_exchangeImplementations(original, replacement);
        });
    });
}
