#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* WebHider 2.0: single owner for Hierarquia -> JSON -> Voltar.
   The hierarchy button is changed during button creation, so the original
   "Voltar" button is never rendered and there is no visual flash. */
static const void *PH26WantsJSONKey = &PH26WantsJSONKey;
static const void *PH26JSONScreenKey = &PH26JSONScreenKey;
static const void *PH26JSONTextKey = &PH26JSONTextKey;
static IMP PH26OriginalButton = NULL;
static IMP PH26OriginalHierarchy = NULL;
static IMP PH26OriginalRender = NULL;
static IMP PH26OriginalBack = NULL;
static IMP PH26OriginalDetails = NULL;

static BOOL PH26WantsJSON(id obj) { return [objc_getAssociatedObject(obj, PH26WantsJSONKey) boolValue]; }
static void PH26SetWantsJSON(id obj, BOOL value) { objc_setAssociatedObject(obj, PH26WantsJSONKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static BOOL PH26JSONScreen(id obj) { return [objc_getAssociatedObject(obj, PH26JSONScreenKey) boolValue]; }
static void PH26SetJSONScreen(id obj, BOOL value) { objc_setAssociatedObject(obj, PH26JSONScreenKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

static NSString *PH26JSONString(NSString *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *array = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return array.length >= 2 ? [array substringWithRange:NSMakeRange(1, array.length - 2)] : @"\"\"";
}

static NSString *PH26FilterJSON(NSString *selector) {
    return [NSString stringWithFormat:@"{\n  \"action\": {\n    \"selector\": %@,\n    \"type\": \"css-display-none\"\n  },\n  \"trigger\": {\n    \"url-filter\": \".*\"\n  }\n}", PH26JSONString(selector ?: @"")];
}

static NSString *PH26SelectorJS(void) {
    return @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '';function esc(s){try{return CSS.escape(s)}catch(_){return s.replace(/[^a-zA-Z0-9_-]/g,'\\\\$&')}}function unique(s){try{return document.querySelectorAll(s).length===1}catch(_){return false}}function classes(n){if(!n||typeof n.className!=='string')return [];return n.className.trim().split(/\\s+/).filter(function(c){return c&&['row','col','flex','flex-center','justify-center','items-center','no-wrap','q-focus-helper','q-icon','q-btn','q-btn__content','q-btn-item','non-selectable','notranslate','material-icons'].indexOf(c)<0})}var n=e;while(n&&n.nodeType===1&&n!==document.body){if(n.id){var id='[id=\\\"'+esc(n.id)+'\\\"]';if(unique(id))return id}var cs=classes(n);for(var i=0;i<cs.length;i++){var c='.'+esc(cs[i]);if(unique(c))return c}n=n.parentElement}if(e.id){var eid='[id=\\\"'+esc(e.id)+'\\\"]';if(unique(eid))return eid}var own=classes(e);for(var j=0;j<own.length;j++){var oc='.'+esc(own[j]);if(unique(oc))return oc}return e.tagName?e.tagName.toLowerCase():''})()";
}

static void PH26SetJSONText(id self, NSString *selector) {
    NSString *json = PH26FilterJSON(selector ?: @"");
    objc_setAssociatedObject(self, PH26JSONTextKey, json, OBJC_ASSOCIATION_COPY_NONATOMIC);
    @try { [self setValue:json forKey:@"currentDetails"]; [self setValue:@"Filtro JSON" forKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}
}

static void PH26RenderJSON(id self) {
    PH26SetWantsJSON(self, YES);
    PH26SetJSONScreen(self, YES);
    if (PH26OriginalRender) ((void (*)(id, SEL, BOOL))PH26OriginalRender)(self, @selector(render:), YES);
    UIView *root = ((UIViewController *)self).view;
    for (UIView *v in root.subviews) for (UIView *sub in v.subviews)
        if ([sub isKindOfClass:UILabel.class] && [((UILabel *)sub).text isEqualToString:@"Hierarquia DOM"])
            ((UILabel *)sub).text = @"Filtro JSON";
}

static void PH26JSONTapped(id self, SEL _cmd) {
    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"highlightedWebView"]; } @catch (__unused NSException *e) {}
    if (![webView isKindOfClass:WKWebView.class]) {
        UIView *root = ((UIViewController *)self).view;
        NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
        while (stack.count && !webView) {
            UIView *v = stack.lastObject; [stack removeLastObject];
            if ([v isKindOfClass:WKWebView.class]) { webView = (WKWebView *)v; break; }
            [stack addObjectsFromArray:v.subviews];
        }
    }
    if (!webView) { PH26SetJSONText(self, @""); PH26RenderJSON(self); return; }
    [webView evaluateJavaScript:PH26SelectorJS() completionHandler:^(id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *selector = (!error && [result isKindOfClass:NSString.class]) ? result : @"";
            PH26SetJSONText(self, selector);
            PH26RenderJSON(self);
        });
    }];
}

static UIButton *PH26Button(id self, SEL _cmd, NSString *title, SEL action) {
    if (PH26WantsJSON(self) && !PH26JSONScreen(self) && action == @selector(backTapped)) {
        title = @"JSON";
        action = @selector(ph_jsonTapped26);
    } else if (PH26JSONScreen(self) && action == @selector(backTapped)) {
        title = @"Voltar";
        action = @selector(backTapped);
    }
    if (PH26OriginalButton) return ((UIButton *(*)(id, SEL, NSString *, SEL))PH26OriginalButton)(self, _cmd, title, action);
    return nil;
}

static void PH26Hierarchy(id self, SEL _cmd) {
    PH26SetJSONScreen(self, NO);
    PH26SetWantsJSON(self, YES);
    if (PH26OriginalHierarchy) ((void (*)(id, SEL))PH26OriginalHierarchy)(self, _cmd);
}

static void PH26Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PH26OriginalRender) ((void (*)(id, SEL, BOOL))PH26OriginalRender)(self, _cmd, hierarchyMode);
}

static void PH26Back(id self, SEL _cmd) {
    PH26SetJSONScreen(self, NO);
    PH26SetWantsJSON(self, NO);
    if (PH26OriginalBack) ((void (*)(id, SEL))PH26OriginalBack)(self, _cmd);
}

static void PH26Details(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    PH26SetJSONScreen(self, NO);
    PH26SetWantsJSON(self, NO);
    if (PH26OriginalDetails) ((void (*)(id, SEL, NSString *, NSString *))PH26OriginalDetails)(self, _cmd, details, subtitle);
}

@interface PHV26JSONFlowFinal : NSObject @end
@implementation PHV26JSONFlowFinal
+ (void)load {
    Class target = NSClassFromString(@"PHInspectorViewController");
    if (!target) return;
    class_addMethod(target, @selector(ph_jsonTapped26), (IMP)PH26JSONTapped, "v@:");
    Method button = class_getInstanceMethod(target, @selector(button:action:));
    if (button) { PH26OriginalButton = method_getImplementation(button); method_setImplementation(button, (IMP)PH26Button); }
    Method hierarchy = class_getInstanceMethod(target, @selector(hierarchyTapped));
    if (hierarchy) { PH26OriginalHierarchy = method_getImplementation(hierarchy); method_setImplementation(hierarchy, (IMP)PH26Hierarchy); }
    Method render = class_getInstanceMethod(target, @selector(render:));
    if (render) { PH26OriginalRender = method_getImplementation(render); method_setImplementation(render, (IMP)PH26Render); }
    Method back = class_getInstanceMethod(target, @selector(backTapped));
    if (back) { PH26OriginalBack = method_getImplementation(back); method_setImplementation(back, (IMP)PH26Back); }
    Method details = class_getInstanceMethod(target, @selector(showInspectorDetails:subtitle:));
    if (details) { PH26OriginalDetails = method_getImplementation(details); method_setImplementation(details, (IMP)PH26Details); }
}
@end
