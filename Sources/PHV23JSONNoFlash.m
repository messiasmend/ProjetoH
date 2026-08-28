#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@class PHInspectorViewController;

static const void *PHNoFlashWantsJSONKey = &PHNoFlashWantsJSONKey;
static IMP PHNoFlashOriginalButton = NULL;
static IMP PHNoFlashOriginalHierarchy = NULL;
static IMP PHNoFlashOriginalBack = NULL;
static IMP PHNoFlashOriginalDetails = NULL;

static BOOL PHNoFlashWantsJSON(id obj) {
    return [objc_getAssociatedObject(obj, PHNoFlashWantsJSONKey) boolValue];
}

static void PHNoFlashSetWantsJSON(id obj, BOOL value) {
    objc_setAssociatedObject(obj, PHNoFlashWantsJSONKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIButton *PHNoFlashButton(id self, SEL _cmd, NSString *title, SEL action) {
    // The original render: method creates its left button before the later
    // JSON UI hook gets a chance to rename it. That creates a visible
    // Voltar -> JSON flash. Intercept the button at creation time instead.
    if (PHNoFlashWantsJSON(self) && action == @selector(backTapped)) {
        title = @"JSON";
        action = @selector(ph_jsonTapped);
    }
    if (PHNoFlashOriginalButton) {
        return ((UIButton *(*)(id, SEL, NSString *, SEL))PHNoFlashOriginalButton)(self, _cmd, title, action);
    }
    return nil;
}

static void PHNoFlashHierarchy(id self, SEL _cmd) {
    // Set this BEFORE the original hierarchyTapped reaches showHierarchy ->
    // render:YES. Therefore render: creates JSON directly on its first pass.
    PHNoFlashSetWantsJSON(self, YES);
    if (PHNoFlashOriginalHierarchy) {
        ((void (*)(id, SEL))PHNoFlashOriginalHierarchy)(self, _cmd);
    }
}

static void PHNoFlashBack(id self, SEL _cmd) {
    PHNoFlashSetWantsJSON(self, NO);
    if (PHNoFlashOriginalBack) {
        ((void (*)(id, SEL))PHNoFlashOriginalBack)(self, _cmd);
    }
}

static void PHNoFlashDetails(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    PHNoFlashSetWantsJSON(self, NO);
    if (PHNoFlashOriginalDetails) {
        ((void (*)(id, SEL, NSString *, NSString *))PHNoFlashOriginalDetails)(self, _cmd, details, subtitle);
    }
}

@interface PHV23JSONNoFlash : NSObject
@end

@implementation PHV23JSONNoFlash

+ (void)load {
    Class target = NSClassFromString(@"PHInspectorViewController");
    if (!target) return;

    Method button = class_getInstanceMethod(target, @selector(button:action:));
    if (button) {
        PHNoFlashOriginalButton = method_getImplementation(button);
        method_setImplementation(button, (IMP)PHNoFlashButton);
    }

    Method hierarchy = class_getInstanceMethod(target, @selector(hierarchyTapped));
    if (hierarchy) {
        PHNoFlashOriginalHierarchy = method_getImplementation(hierarchy);
        method_setImplementation(hierarchy, (IMP)PHNoFlashHierarchy);
    }

    Method back = class_getInstanceMethod(target, @selector(backTapped));
    if (back) {
        PHNoFlashOriginalBack = method_getImplementation(back);
        method_setImplementation(back, (IMP)PHNoFlashBack);
    }

    Method details = class_getInstanceMethod(target, @selector(showInspectorDetails:subtitle:));
    if (details) {
        PHNoFlashOriginalDetails = method_getImplementation(details);
        method_setImplementation(details, (IMP)PHNoFlashDetails);
    }
}

@end
