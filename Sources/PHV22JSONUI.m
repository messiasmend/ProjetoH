#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static const void *PHJSONModeKey = &PHJSONModeKey;
static const void *PHJSONTextKey = &PHJSONTextKey;

static BOOL PHIsJSONMode(id obj) {
    return [objc_getAssociatedObject(obj, PHJSONModeKey) boolValue];
}

static void PHSetJSONMode(id obj, BOOL value) {
    objc_setAssociatedObject(obj, PHJSONModeKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIView *PHFindSubviewOfClass(UIView *root, Class cls) {
    if ([root isKindOfClass:cls]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = PHFindSubviewOfClass(sub, cls);
        if (found) return found;
    }
    return nil;
}

static UIButton *PHFindButton(UIView *root, NSString *title) {
    if ([root isKindOfClass:UIButton.class] && [[((UIButton *)root) titleForState:UIControlStateNormal] isEqualToString:title]) return (UIButton *)root;
    for (UIView *sub in root.subviews) {
        UIButton *found = PHFindButton(sub, title);
        if (found) return found;
    }
    return nil;
}

static UILabel *PHFindContentLabel(UIScrollView *scroll) {
    for (UIView *sub in scroll.subviews) {
        if ([sub isKindOfClass:UILabel.class]) return (UILabel *)sub;
    }
    return nil;
}

static NSString *PHSelectorFromHierarchy(NSString *details) {
    NSArray<NSString *> *lines = [details componentsSeparatedByString:@"\n"];
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        while (line.length) {
            NSString *first = [line substringToIndex:1];
            if ([first isEqualToString:@"▶"] || [first isEqualToString:@"↳"] || [first isEqualToString:@"├"] || [first isEqualToString:@"└"] || [first isEqualToString:@"│"] || [first isEqualToString:@"─"] || [first isEqualToString:@"→"]) {
                line = [[line substringFromIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            } else {
                break;
            }
        }
        if (!line.length) continue;
        if ([line isEqualToString:@"Hierarquia DOM"]) continue;
        if ([line hasPrefix:@"Classe:"] || [line hasPrefix:@"Rect:"] || [line hasPrefix:@"Tag:"] || [line hasPrefix:@"Hidden:"] || [line hasPrefix:@"Alpha:"]) continue;
        return line;
    }
    return @"";
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
    UIScrollView *scroll = (UIScrollView *)PHFindSubviewOfClass(panel, UIScrollView.class);
    UILabel *subtitle = nil;
    for (UIView *sub in panel.subviews) {
        if ([sub isKindOfClass:UILabel.class] && [((UILabel *)sub).text isEqualToString:@"Elemento Web selecionado"]) {
            subtitle = (UILabel *)sub;
            break;
        }
    }
    if (subtitle) subtitle.text = @"Filtro JSON";
    NSString *details = [self valueForKey:@"currentDetails"];
    NSString *selector = PHSelectorFromHierarchy(details);
    if (!selector.length) selector = PHSelectorFromHierarchy([self valueForKey:@"detailsBeforeHierarchy"]);
    NSString *json = PHBuildFilterJSON(selector);
    UILabel *content = PHFindContentLabel(scroll);
    if (content) {
        content.text = json;
        content.font = [UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular];
    }
    UIButton *left = PHFindButton(panel, @"Hierarquia");
    if (!left) left = PHFindButton(panel, @"Voltar");
    if (left) {
        [left setTitle:@"Voltar" forState:UIControlStateNormal];
        [left removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [left addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    objc_setAssociatedObject(self, PHJSONTextKey, json, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@interface PHV22JSONBridge : NSObject
@end

@implementation PHV22JSONBridge

- (void)ph_render_json:(BOOL)hierarchyMode {
    BOOL jsonMode = PHIsJSONMode(self);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(ph_render_json:), jsonMode ? NO : hierarchyMode);
    if (jsonMode) PHConfigureJSONScreen(self);
    else if (hierarchyMode) PHConfigureHierarchyButton(self);
}

- (void)ph_jsonTapped {
    PHSetJSONMode(self, YES);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(render:), NO);
}

- (void)ph_copyTapped {
    if (PHIsJSONMode(self)) {
        NSString *json = objc_getAssociatedObject(self, PHJSONTextKey);
        UIPasteboard.generalPasteboard.string = json ?: @"";
        return;
    }
    ((void (*)(id, SEL))objc_msgSend)(self, @selector(ph_copyTapped));
}

- (void)ph_backTapped {
    if (PHIsJSONMode(self)) PHSetJSONMode(self, NO);
    ((void (*)(id, SEL))objc_msgSend)(self, @selector(ph_backTapped));
}

- (void)ph_showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle {
    PHSetJSONMode(self, NO);
    ((void (*)(id, SEL, NSString *, NSString *))objc_msgSend)(self, @selector(ph_showInspectorDetails:subtitle:), details, subtitle);
}

+ (void)load {
    Class target = NSClassFromString(@"PHInspectorViewController");
    if (!target) return;
    Class bridge = self;

    Method render = class_getInstanceMethod(target, @selector(render:));
    Method bridgeRender = class_getInstanceMethod(bridge, @selector(ph_render_json:));
    class_addMethod(target, @selector(ph_render_json:), method_getImplementation(bridgeRender), method_getTypeEncoding(bridgeRender));
    method_exchangeImplementations(render, class_getInstanceMethod(target, @selector(ph_render_json:)));

    Method jsonTap = class_getInstanceMethod(bridge, @selector(ph_jsonTapped));
    class_addMethod(target, @selector(ph_jsonTapped), method_getImplementation(jsonTap), method_getTypeEncoding(jsonTap));

    Method copy = class_getInstanceMethod(target, @selector(copyTapped));
    Method bridgeCopy = class_getInstanceMethod(bridge, @selector(ph_copyTapped));
    class_addMethod(target, @selector(ph_copyTapped), method_getImplementation(bridgeCopy), method_getTypeEncoding(bridgeCopy));
    method_exchangeImplementations(copy, class_getInstanceMethod(target, @selector(ph_copyTapped)));

    Method back = class_getInstanceMethod(target, @selector(backTapped));
    Method bridgeBack = class_getInstanceMethod(bridge, @selector(ph_backTapped));
    class_addMethod(target, @selector(ph_backTapped), method_getImplementation(bridgeBack), method_getTypeEncoding(bridgeBack));
    method_exchangeImplementations(back, class_getInstanceMethod(target, @selector(ph_backTapped)));

    Method details = class_getInstanceMethod(target, @selector(showInspectorDetails:subtitle:));
    Method bridgeDetails = class_getInstanceMethod(bridge, @selector(ph_showInspectorDetails:subtitle:));
    class_addMethod(target, @selector(ph_showInspectorDetails:subtitle:), method_getImplementation(bridgeDetails), method_getTypeEncoding(bridgeDetails));
    method_exchangeImplementations(details, class_getInstanceMethod(target, @selector(ph_showInspectorDetails:subtitle:)));
}
@end
