#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* Same associated-object key used by PHV22JSONUI.m. A selector is a
   process-wide Objective-C identifier, so both files address the same state. */
static const void *PHJSONModeSharedKey = (const void *)@selector(ph_jsonModeMarker);
static const void *PHNoFlashWantsJSONKey = &PHNoFlashWantsJSONKey;
static IMP PHNoFlashOriginalButton = NULL;
static IMP PHNoFlashOriginalHierarchy = NULL;
static IMP PHNoFlashOriginalBack = NULL;

static BOOL PHNoFlashWantsJSON(id obj) {
    return [objc_getAssociatedObject(obj, PHNoFlashWantsJSONKey) boolValue];
}
static void PHNoFlashSetWantsJSON(id obj, BOOL value) {
    objc_setAssociatedObject(obj, PHNoFlashWantsJSONKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void PHNoFlashJSONTapped(id self, SEL _cmd) {
    /* This implementation lives in the no-flash hook itself. It therefore
       does not depend on +load ordering between the two source files. */
    objc_setAssociatedObject(self, PHJSONModeSharedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(render:), YES);
}

static UIButton *PHNoFlashButton(id self, SEL _cmd, NSString *title, SEL action) {
    /* Replace the original back button before UIKit can display it. */
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
    if (PHNoFlashOriginalHierarchy) ((void (*)(id, SEL))PHNoFlashOriginalHierarchy)(self, _cmd);
}

static void PHNoFlashBack(id self, SEL _cmd) {
    PHNoFlashSetWantsJSON(self, NO);
    objc_setAssociatedObject(self, PHJSONModeSharedKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (PHNoFlashOriginalBack) ((void (*)(id, SEL))PHNoFlashOriginalBack)(self, _cmd);
}

@interface PHV23JSONNoFlash : NSObject
@end

@implementation PHV23JSONNoFlash

+ (void)load {
    Class target = NSClassFromString(@"PHInspectorViewController");
    if (!target) return;

    Method jsonTap = class_getInstanceMethod(self, @selector(ph_jsonTapped));
    if (jsonTap) {
        class_addMethod(target, @selector(ph_jsonTapped), method_getImplementation(jsonTap), method_getTypeEncoding(jsonTap));
    }

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
}

@end
