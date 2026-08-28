#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

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
    /* While hierarchy is being rendered, replace the original left/back
       button before UIKit can display it. This removes the Voltar flash. */
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
    /* Do not clear WantsJSON during the internal details call used by the
       JSON transition. The JSON UI hook owns the separate JSON state. */
    if (!objc_getAssociatedObject(self, NSSelectorFromString(@"ph_jsonTapped"))) {
        /* no-op: marker intentionally not used as state */
    }
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
