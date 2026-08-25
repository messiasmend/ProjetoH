#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

// ProjetoH V14: generic metadata bridge. It does not target any application bundle.
static NSMutableDictionary<NSString *, NSDictionary *> *PHV14PendingMetadata(void) {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary dictionary]; });
    return d;
}

static NSString *PHV14FilterPath(void) {
    static NSString *cached;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *rel;
        while ((rel = [e nextObject])) {
            if ([rel.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                cached = [home stringByAppendingPathComponent:rel];
                break;
            }
        }
        if (!cached.length) cached = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    return cached;
}

static NSString *PHV14MetadataPath(void) {
    return [PHV14FilterPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"projetoh-metadata.json"];
}

static NSArray *PHV14Filters(void) {
    NSData *d = [NSData dataWithContentsOfFile:PHV14FilterPath()];
    id j = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
    if ([j isKindOfClass:NSDictionary.class] && [j[@"filters"] isKindOfClass:NSArray.class]) j = j[@"filters"];
    return [j isKindOfClass:NSArray.class] ? j : @[];
}

static NSString *PHV14Selector(NSDictionary *f) {
    id a = f[@"action"];
    if ([a isKindOfClass:NSDictionary.class] && [a[@"selector"] isKindOfClass:NSString.class]) return a[@"selector"];
    return [f[@"selector"] isKindOfClass:NSString.class] ? f[@"selector"] : nil;
}

static void PHV14WriteMetadataFromPending(void) {
    NSMutableDictionary *elements = [NSMutableDictionary dictionary];
    NSData *old = [NSData dataWithContentsOfFile:PHV14MetadataPath()];
    id oldJSON = old ? [NSJSONSerialization JSONObjectWithData:old options:NSJSONReadingMutableContainers error:nil] : nil;
    if ([oldJSON isKindOfClass:NSDictionary.class] && [oldJSON[@"elements"] isKindOfClass:NSDictionary.class]) [elements addEntriesFromDictionary:oldJSON[@"elements"]];

    for (NSDictionary *f in PHV14Filters()) {
        NSString *sel = PHV14Selector(f);
        NSDictionary *meta = sel ? PHV14PendingMetadata()[sel] : nil;
        if (sel.length && meta) elements[sel] = meta;
    }
    if (!elements.count) {
        [NSFileManager.defaultManager removeItemAtPath:PHV14MetadataPath() error:nil];
        return;
    }
    NSDictionary *root = @{ @"version": @1, @"elements": elements };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
    if (data) [data writeToFile:PHV14MetadataPath() atomically:YES];
}

static void PHV14CaptureSelectedWebElement(id manager) {
    WKWebView *web = nil;
    @try { web = [manager valueForKey:@"highlightedWebView"]; } @catch (__unused NSException *e) {}
    if (!web) return;
    NSString *js = @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}return JSON.stringify({selector:p(e),name:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,60)||e.getAttribute('aria-label')||e.getAttribute('title')||(e.id?'#'+e.id:(e.tagName||'').toLowerCase()==='lottie-player'?'Lottie Player':(e.tagName||'').toLowerCase()),tag:(e.tagName||'').toLowerCase(),text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,180),id:e.id||'',className:typeof e.className==='string'?e.className:'',ariaLabel:e.getAttribute('aria-label')||'',title:e.getAttribute('title')||''});})()";
    [web evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) return;
        NSData *d = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *info = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        NSString *sel = [info[@"selector"] isKindOfClass:NSString.class] ? info[@"selector"] : nil;
        if (!sel.length) return;
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        for (NSString *k in @[@"name",@"tag",@"text",@"id",@"className",@"ariaLabel",@"title"]) if ([info[k] isKindOfClass:NSString.class] && [info[k] length]) entry[k]=info[k];
        if (!entry[@"name"]) entry[@"name"] = @"Elemento";
        PHV14PendingMetadata()[sel] = entry;
    }];
}

static void PHV14Swizzle(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original), b = class_getInstanceMethod(cls, replacement);
    if (!a || !b) return;
    method_exchangeImplementations(a,b);
}

@interface NSObject (PHV14MetadataBridge)
- (void)phv14_hideSelectedElement;
@end
@implementation NSObject (PHV14MetadataBridge)
- (void)phv14_hideSelectedElement {
    PHV14CaptureSelectedWebElement(self);
    [self phv14_hideSelectedElement];
}
@end

__attribute__((constructor)) static void PHV14MetadataInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHOverlayManager");
        if (!cls) return;
        PHV14Swizzle(cls, @selector(hideSelectedElement), @selector(phv14_hideSelectedElement));
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(__unused NSTimer *t) {
            if (!PHV14PendingMetadata().count) return;
            PHV14WriteMetadataFromPending();
            NSArray *filters = PHV14Filters();
            NSMutableSet *live = [NSMutableSet set];
            for (NSDictionary *f in filters) { NSString *sel = PHV14Selector(f); if (sel.length) [live addObject:sel]; }
            NSArray *keys = PHV14PendingMetadata().allKeys.copy;
            for (NSString *key in keys) if ([live containsObject:key]) [PHV14PendingMetadata() removeObjectForKey:key];
            NSString *mp = PHV14MetadataPath();
            NSData *md = [NSData dataWithContentsOfFile:mp];
            id mj = md ? [NSJSONSerialization JSONObjectWithData:md options:NSJSONReadingMutableContainers error:nil] : nil;
            if ([mj isKindOfClass:NSDictionary.class] && [mj[@"elements"] isKindOfClass:NSDictionary.class]) {
                NSMutableDictionary *elements = [mj[@"elements"] mutableCopy];
                for (NSString *key in elements.allKeys.copy) if (![live containsObject:key]) [elements removeObjectForKey:key];
                if (elements.count) {
                    NSDictionary *root = @{ @"version": @1, @"elements": elements };
                    NSData *out = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
                    if (out) [out writeToFile:mp atomically:YES];
                } else { [NSFileManager.defaultManager removeItemAtPath:mp error:nil]; }
            }
        }];
    });
}
