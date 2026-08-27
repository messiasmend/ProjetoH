#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

/* ProjetoH V21 — generic.
 * Preserve WebFrame's original selection/hide/save behavior.
 * V21 adds only: global URL scope + metadata. No periodic timer.
 */
static NSString *PH21FilterPath(void){static NSString*p;static dispatch_once_t once;dispatch_once(&once,^{NSString*h=NSHomeDirectory();NSDirectoryEnumerator*e=[NSFileManager.defaultManager enumeratorAtPath:h];NSString*r;while((r=[e nextObject]))if([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]){p=[h stringByAppendingPathComponent:r];break;}if(!p.length)p=[h stringByAppendingPathComponent:@"Documents/custom-filters.json"];});return p;}
static NSString *PH21MetadataPath(void){return [PH21FilterPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"projetoh-metadata.json"];}
static NSMutableDictionary *PH21FilterRoot(void){NSData*d=[NSData dataWithContentsOfFile:PH21FilterPath()];id j=d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil;return [j isKindOfClass:NSDictionary.class]?[j mutableCopy]:[NSMutableDictionary dictionary];}
static NSArray *PH21Filters(void){id f=PH21FilterRoot()[@"filters"];return [f isKindOfClass:NSArray.class]?f:@[];}
static BOOL PH21WriteFilters(NSArray*f){NSMutableDictionary*r=PH21FilterRoot();r[@"filters"]=f?:@[];if(!r[@"version"])r[@"version"]=@1;NSData*d=[NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];return d&&[d writeToFile:PH21FilterPath() atomically:YES;}
static NSString *PH21Selector(NSDictionary*f){if(![f isKindOfClass:NSDictionary.class])return nil;id s=f[@"selector"];if([s isKindOfClass:NSString.class]&&[s length])return s;NSDictionary*a=[f[@"action"] isKindOfClass:NSDictionary.class]?f[@"action"]:nil;s=a[@"selector"];return [s isKindOfClass:NSString.class]&&[s length]?s:nil;}
static NSMutableDictionary *PH21Metadata(void){NSData*d=[NSData dataWithContentsOfFile:PH21MetadataPath()];id j=d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil;NSDictionary*e=[j isKindOfClass:NSDictionary.class]&&[j[@"elements"] isKindOfClass:NSDictionary.class]?j[@"elements"]:nil;return e?[e mutableCopy]:[NSMutableDictionary dictionary];}
static void PH21WriteMetadata(NSDictionary*e){if(!e.count){[NSFileManager.defaultManager removeItemAtPath:PH21MetadataPath() error:nil];return;}NSDictionary*r=@{@"version":@1,@"elements":e};NSData*d=[NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];if(d)[d writeToFile:PH21MetadataPath() atomically:YES];}
static NSString *PH21Name(NSDictionary*m){NSString*t=[m[@"tag"] isKindOfClass:NSString.class]?[m[@"tag"] lowercaseString]:@"";if([t isEqualToString:@"lottie-player"])return @"Lottie Player";for(NSString*k in @[@"ariaLabel",@"text",@"title"]){NSString*v=[m[k] isKindOfClass:NSString.class]?m[k]:nil;if(v.length){v=[v stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(v.length)return v.length>30?[[v substringToIndex:30]stringByAppendingString:@"…"]:v;}}NSString*v=[m[@"id"] isKindOfClass:NSString.class]?m[@"id"]:nil;return v.length?[NSString stringWithFormat:@"#%@",v]:t.length?[t uppercaseString]:@"Elemento Web";}
static NSMutableDictionary*PH21Pending;
static id PH21CurrentWebView(id self){@try{return [self valueForKey:@"highlightedWebView"]; }@catch(__unused NSException*e){return nil;}}
static id PH21Inspector(id self){@try{return [self valueForKey:@"inspectorViewController"]; }@catch(__unused NSException*e){return nil;}}
static void PH21Swizzle(Class c,SEL a,SEL b){if(!c)return;Method x=class_getInstanceMethod(c,a),y=class_getInstanceMethod(c,b);if(x&&y)method_exchangeImplementations(x,y);}

/* Capture only metadata. The original WebFrame hide method remains authoritative. */
static void PH21CaptureSelected(WKWebView*web){if(!web)return;NSString*js=@"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}return JSON.stringify({selector:p(e),tag:e.tagName.toLowerCase(),id:e.id||'',className:typeof e.className==='string'?e.className:'',text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,180),ariaLabel:e.getAttribute('aria-label')||'',title:e.getAttribute('title')||''});})()";[web evaluateJavaScript:js completionHandler:^(id result,__unused NSError*error){if(![result isKindOfClass:NSString.class])return;NSData*d=[(NSString*)result dataUsingEncoding:NSUTF8StringEncoding];NSDictionary*m=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;NSString*s=[m[@"selector"] isKindOfClass:NSString.class]?m[@"selector"]:nil;if(s.length){if(!PH21Pending)PH21Pending=[NSMutableDictionary dictionary];PH21Pending[s]=m;}}];}

/* Only widen the URL trigger. Never rewrite selector/action or other filter fields. */
static void PH21MakeFiltersGlobal(void){NSArray*old=PH21Filters();if(!old.count)return;NSMutableArray*out=[NSMutableArray arrayWithCapacity:old.count];BOOL changed=NO;for(id obj in old){if(![obj isKindOfClass:NSDictionary.class]){[out addObject:obj];continue;}NSMutableDictionary*f=[obj mutableCopy];NSMutableDictionary*trigger=[f[@"trigger"] isKindOfClass:NSDictionary.class]?[f[@"trigger"] mutableCopy]:nil;if(trigger){id u=trigger[@"url-filter"];if([u isKindOfClass:NSString.class]&&![(NSString*)u isEqualToString:@".*"]){trigger[@"url-filter"]=@".*";f[@"trigger"]=trigger;changed=YES;}}[out addObject:f];}if(changed)PH21WriteFilters(out);}
static void PH21SyncSavedMetadata(void){NSArray*f=PH21Filters();NSMutableDictionary*m=PH21Metadata();NSMutableSet*live=[NSMutableSet set];for(NSDictionary*x in f){NSString*s=PH21Selector(x);if(s.length)[live addObject:s];}for(NSString*s in m.allKeys.copy)if(![live containsObject:s])[m removeObjectForKey:s];[PH21Pending enumerateKeysAndObjectsUsingBlock:^(NSString*s,NSDictionary*v,BOOL*stop){if([live containsObject:s])m[s]=v;}];PH21WriteMetadata(m);}

@interface NSObject(PHV21)- (void)ph21_hideSelectedElement;- (void)ph21_savePendingFilters;- (void)ph21_showHiddenElements;@end
@implementation NSObject(PHV21)

- (void)ph21_hideSelectedElement {
    /* IMPORTANT: invoke WebFrame first. This preserves the proven zero-delay hide path. */
    [self ph21_hideSelectedElement];
    /* Metadata capture is secondary and cannot block/interfere with hiding. */
    PH21CaptureSelected(PH21CurrentWebView(self));
}

- (void)ph21_savePendingFilters {
    /* Let the original WebFrame save happen first, unchanged. */
    [self ph21_savePendingFilters];
    /* One main-queue turn only: no periodic timer and no 2-second polling. */
    dispatch_async(dispatch_get_main_queue(), ^{
        PH21MakeFiltersGlobal();
        PH21SyncSavedMetadata();
    });
}

- (void)ph21_showHiddenElements {
    NSArray*f=PH21Filters();UIViewController*vc=PH21Inspector(self);if(!vc){[self ph21_showHiddenElements];return;}NSMutableDictionary*m=PH21Metadata();UIAlertController*a=[UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu item(ns) salvo(s) em custom-filters.json",(unsigned long)f.count] preferredStyle:UIAlertControllerStyleActionSheet];for(NSDictionary*x in f){NSString*s=PH21Selector(x);if(!s.length)continue;NSString*n=PH21Name(m[s]);[a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@",n] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction*z){NSMutableArray*c=[PH21Filters() mutableCopy];NSIndexSet*i=[c indexesOfObjectsPassingTest:^BOOL(NSDictionary*q,NSUInteger j,BOOL*stop){return [PH21Selector(q)isEqualToString:s];}];[c removeObjectsAtIndexes:i];PH21WriteFilters(c);[PH21Pending removeObjectForKey:s];PH21SyncSavedMetadata();}]];}if(f.count)[a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction*z){PH21WriteFilters(@[]);[PH21Pending removeAllObjects];PH21SyncSavedMetadata();}]];[a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=vc.view;a.popoverPresentationController.sourceRect=vc.view.bounds;[vc presentViewController:a animated:YES completion:nil];}
@end

__attribute__((constructor))static void PHV21Init(void){PH21Pending=[NSMutableDictionary dictionary];dispatch_async(dispatch_get_main_queue(),^{Class c=NSClassFromString(@"PHOverlayManager");if(!c)return;PH21Swizzle(c,@selector(hideSelectedElement),@selector(ph21_hideSelectedElement));PH21Swizzle(c,@selector(savePendingFilters),@selector(ph21_savePendingFilters));PH21Swizzle(c,@selector(showHiddenElements),@selector(ph21_showHiddenElements));});}
