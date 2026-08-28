#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static const void *PHJSONModeKey = &PHJSONModeKey;
static const void *PHJSONTextKey = &PHJSONTextKey;

static IMP PHOriginalRender = NULL;
static IMP PHOriginalCopy = NULL;
static IMP PHOriginalBack = NULL;
static IMP PHOriginalDetails = NULL;

static BOOL PHIsJSONMode(id obj) {
    return [objc_getAssociatedObject(obj, PHJSONModeKey) boolValue];
}

static void PHSetJSONMode(id obj, BOOL value) {
    objc_setAssociatedObject(obj, PHJSONModeKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIView *PHFindSubviewOfClass(UIView *root, Class cls) {
    if (!root) return nil;
    if ([root isKindOfClass:cls]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = PHFindSubviewOfClass(sub, cls);
        if (found) return found;
    }
    return nil;
}

static UIButton *PHFindButton(UIView *root, NSString *title) {
    if (!root) return nil;
    if ([root isKindOfClass:UIButton.class] && [[((UIButton *)root) titleForState:UIControlStateNormal] isEqualToString:title]) return (UIButton *)root;
    for (UIView *sub in root.subviews) {
        UIButton *found = PHFindButton(sub, title);
        if (found) return found;
    }
    return nil;
}

static UILabel *PHFindContentLabel(UIScrollView *scroll) {
    if (!scroll) return nil;
    for (UIView *sub in scroll.subviews) {
        if ([sub isKindOfClass:UILabel.class]) return (UILabel *)sub;
    }
    return nil;
}

static NSString *PHJSONString(NSString *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *array = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (array.length >= 2) return [array substringWithRange:NSMakeRange(1, array.length - 2)];
    return @"\"\"";
}

static NSString *PHBuildFilterJSON(NSString *selector) {
    return [NSString stringWithFormat:@"{\n  \"action\": {\n    \"selector\": %@,\n    \"type\": \"css-display-none\"\n  },\n  \"trigger\": {\n    \"url-filter\": \".*\"\n  }\n}", PHJSONString(selector ?: @"")];
}

static NSString *PHSelectedElementSelectorJS(void) {
    return @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '';function esc(s){try{return CSS.escape(s)}catch(_){return s.replace(/[^a-zA-Z0-9_-]/g,'\\\\$&')}}function unique(sel){try{return document.querySelectorAll(sel).length===1}catch(_){return false}}function classCandidates(n){if(!n||typeof n.className!=='string')return [];var a=n.className.trim().split(/\\s+/).filter(Boolean);var preferred=a.filter(function(c){return c==='q-page-sticky'||c.indexOf('page-sticky')>=0||c.indexOf('floating')>=0||c.indexOf('component')>=0||c.indexOf('overlay')>=0||c.indexOf('panel')>=0;});var normal=a.filter(function(c){return ['row','col','flex','flex-center','justify-center','items-center','no-wrap','q-focus-helper','q-icon','q-btn','q-btn__content','q-btn-item','non-selectable','notranslate','material-icons','mobile','platform-ios','touch'].indexOf(c)<0;});return preferred.concat(normal.filter(function(c){return preferred.indexOf(c)<0;}));}function findStable(start){var n=start;while(n&&n.nodeType===1&&n!==document.body){if(n!==start&&n.id){var id='[id=\\\"'+esc(n.id)+'\\\"]';if(unique(id))return id;}var cs=classCandidates(n);for(var i=0;i<cs.length;i++){var s='.'+esc(cs[i]);if(unique(s))return s;}n=n.parentElement;}if(start.id){var sid='[id=\\\"'+esc(start.id)+'\\\"]';if(unique(sid))return sid;}var own=classCandidates(start);for(var j=0;j<own.length;j++){var os='.'+esc(own[j]);if(unique(os))return os;}return '';}return findStable(e);})()";
}

static void PHSetJSONContent(id self, NSString *selector) {
    NSString *json = PHBuildFilterJSON(selector ?: @"");
    objc_setAssociatedObject(self, PHJSONTextKey, json, OBJC_ASSOCIATION_COPY_NONATOMIC);

    UIView *view = [self valueForKey:@"view"];
    UIView *panel = view.subviews.firstObject;
    if (!panel) return;

    UIScrollView *scroll = (UIScrollView *)PHFindSubviewOfClass(panel, UIScrollView.class);
    UILabel *content = PHFindContentLabel(scroll);
    if (content) {
        content.text = json;
        content.font = [UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular];
    }
}

static void PHConfigureHierarchyButton(id self) {
    UIView *view = [self valueForKey:@"view"];
    UIButton *button = PHFindButton(view, @"Voltar");
    if (!button) return;

    [button setTitle:@"JSON" forState:UIControlStateNormal];
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(ph_jsonTapped) forControlEvents:UIControlEventTouchUpInside];
}

static void PHConfigureJSONScreen(id self) {
    UIView *view = [self valueForKey:@"view"];
    UIView *panel = view.subviews.firstObject;
    if (!panel) return;

    UILabel *subtitle = nil;
    for (UIView *sub in panel.subviews) {
        if ([sub isKindOfClass:UILabel.class] && [((UILabel *)sub).text isEqualToString:@"Elemento Web selecionado"]) {
            subtitle = (UILabel *)sub;
            break;
        }
    }
    if (subtitle) subtitle.text = @"Filtro JSON";

    objc_setAssociatedObject(self, PHJSONTextKey, @"", OBJC_ASSOCIATION_COPY_NONATOMIC);

    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"highlightedWebView"]; } @catch (__unused NSException *exception) {}
    if (![webView isKindOfClass:WKWebView.class]) {
        @try { webView = (WKWebView *)PHFindSubviewOfClass([self valueForKey:@"view"], WKWebView.class); } @catch (__unused NSException *exception) {}
    }

    if (![webView isKindOfClass:WKWebView.class]) {
        PHSetJSONContent(self, @"");
        return;
    }

    [webView evaluateJavaScript:PHSelectedElementSelectorJS() completionHandler:^(id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *selector = (!error && [result isKindOfClass:NSString.class]) ? (NSString *)result : @"";
            /* Deliberately do not fall back to currentDetails/detailsBeforeHierarchy.
             * Those strings are the hierarchy text, not the selected DOM selector. */
            PHSetJSONContent(self, selector);
        });
    }];

    UIButton *left = PHFindButton(panel, @"Hierarquia");
    if (!left) left = PHFindButton(panel, @"Voltar");
    if (left) {
        [left setTitle:@"Voltar" forState:UIControlStateNormal];
        [left removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [left addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    }
}

static void PHRenderHook(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PHOriginalRender) {
        BOOL jsonMode = PHIsJSONMode(self);
        ((void (*)(id, SEL, BOOL))PHOriginalRender)(self, _cmd, jsonMode ? NO : hierarchyMode);

        if (jsonMode) {
            PHConfigureJSONScreen(self);
        } else if (hierarchyMode) {
            PHConfigureHierarchyButton(self);
        }
    }
}

static void PHCopyHook(id self, SEL _cmd) {
    if (PHIsJSONMode(self)) {
        NSString *json = objc_getAssociatedObject(self, PHJSONTextKey);
        UIPasteboard.generalPasteboard.string = json ?: @"";
        return;
    }
    if (PHOriginalCopy) ((void (*)(id, SEL))PHOriginalCopy)(self, _cmd);
}

static void PHBackHook(id self, SEL _cmd) {
    if (PHIsJSONMode(self)) PHSetJSONMode(self, NO);
    if (PHOriginalBack) ((void (*)(id, SEL))PHOriginalBack)(self, _cmd);
}

static void PHDetailsHook(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    PHSetJSONMode(self, NO);
    if (PHOriginalDetails) ((void (*)(id, SEL, NSString *, NSString *))PHOriginalDetails)(self, _cmd, details, subtitle);
}

@interface PHV22JSONBridge : NSObject
@end

@implementation PHV22JSONBridge

- (void)ph_jsonTapped {
    PHSetJSONMode(self, YES);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(render:), NO);
}

+ (void)load {
    Class target = NSClassFromString(@"PHInspectorViewController");
    if (!target) return;

    Method render = class_getInstanceMethod(target, @selector(render:));
    if (render) {
        PHOriginalRender = method_getImplementation(render);
        method_setImplementation(render, (IMP)PHRenderHook);
    }

    Method copy = class_getInstanceMethod(target, @selector(copyTapped));
    if (copy) {
        PHOriginalCopy = method_getImplementation(copy);
        method_setImplementation(copy, (IMP)PHCopyHook);
    }

    Method back = class_getInstanceMethod(target, @selector(backTapped));
    if (back) {
        PHOriginalBack = method_getImplementation(back);
        method_setImplementation(back, (IMP)PHBackHook);
    }

    Method details = class_getInstanceMethod(target, @selector(showInspectorDetails:subtitle:));
    if (details) {
        PHOriginalDetails = method_getImplementation(details);
        method_setImplementation(details, (IMP)PHDetailsHook);
    }

    Method jsonTap = class_getInstanceMethod(self, @selector(ph_jsonTapped));
    if (jsonTap) {
        class_addMethod(target, @selector(ph_jsonTapped), method_getImplementation(jsonTap), method_getTypeEncoding(jsonTap));
    }
}
@end
