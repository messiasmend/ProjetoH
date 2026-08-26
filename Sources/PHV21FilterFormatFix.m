#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/* ProjetoH filter-format compatibility fix.
 * Generic: no target application identifier is used.
 * The existing inspector saves selector-only entries. WebFrame's native
 * custom-filters.json format requires action + trigger entries. This patch
 * converts the saved entries immediately after the existing Save flow.
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

static NSDictionary *PHV21NativeFilter(NSDictionary *filter) {
    if (![filter isKindOfClass:NSDictionary.class]) return nil;

    NSDictionary *action = [filter[@"action"] isKindOfClass:NSDictionary.class] ? filter[@"action"] : nil;
    NSDictionary *trigger = [filter[@"trigger"] isKindOfClass:NSDictionary.class] ? filter[@"trigger"] : nil;

    NSString *selector = [action[@"selector"] isKindOfClass:NSString.class] ? action[@"selector"] : nil;
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

static void PHV21NormalizeSavedFilters(void) {
    NSString *path = PHV21FilterPath();
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return;

    id root = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    NSArray *filters = nil;
    if ([root isKindOfClass:NSDictionary.class]) filters = [root[@"filters"] isKindOfClass:NSArray.class] ? root[@"filters"] : nil;
    else if ([root isKindOfClass:NSArray.class]) filters = root;
    if (!filters) return;

    NSMutableArray *native = [NSMutableArray arrayWithCapacity:filters.count];
    for (NSDictionary *filter in filters) {
        NSDictionary *converted = PHV21NativeFilter(filter);
        if (converted) [native addObject:converted];
    }

    NSData *out = [NSJSONSerialization dataWithJSONObject:native options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    if (out) [out writeToFile:path atomically:YES];
}

static IMP PHV21OriginalSave = NULL;

static void PHV21SavePendingFilters(id self, SEL _cmd) {
    if (PHV21OriginalSave) {
        ((void (*)(id, SEL))PHV21OriginalSave)(self, _cmd);
    }

    // The original save is synchronous; normalize immediately so the native
    // WebFrame filter engine receives the same structure as a manual filter.
    PHV21NormalizeSavedFilters();
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
