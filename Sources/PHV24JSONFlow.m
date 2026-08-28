#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* WebHider 1.5: keep the no-flash behavior, but bind the JSON button
   directly to the inspector controller after the original button is created. */
static const void *PHWantsJSONKey = &PHWantsJSONKey;
static const void *PHJSONModeKey = &PHJSONModeKey;
static IMP PHOriginalButton15 = NULL;
static IMP PHOriginalHierarchy15 = NULL;
static IMP PHOriginalBack15 = NULL;

static BOOL PHWantsJSON(id obj) { return [objc_getAssociatedObject(obj, PHWantsJSONKey) boolValue]; }
static void PHSetWantsJSON(id obj, BOOL value) { objc_setAssociatedObject(obj, PHWantsJSONKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static const void *PHSharedJSONKey(void) { return (const void *)NSClassFromString(@"PHInspectorViewController"); }

static void PHJSONTapped15(id self, SEL _cmd) {
    objc_setAssociatedObject(self, PHSharedJSONKey(), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, @selector(render:), YES);
}

static UIButton *PHButton15(id self, SEL _cmd, NSString *title, SEL action) {
    BOOL replace = PHWantsJSON(self) && action == @selector(backTapped);
    NSString *finalTitle = replace ? @"JSON" : title;
    SEL finalAction = replace ? @selector(ph_jsonTapped15) : action;
    UIButton *button = nil;
    if (PHOriginalButton15) button = ((UIButton *(*)(id, SEL, NSString *, SEL))PHOriginalButton15)(self, _cmd, finalTitle, finalAction);
    if (replace && button) {
        /* Do not rely on the inspector's internal target/action wiring. */
        [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [button setTitle:@"JSON" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(ph_jsonTapped15) forControlEvents:UIControlEventTouchUpInside];
    }
    return button;
}

static void PHHierarchy15(id self, SEL _cmd) {
    PHSetWantsJSON(self, YES);
    if (PHOriginalHierarchy15) ((void (*)(id, SEL))PHOriginalHierarchy15)(self, _cmd);
}

static void PHBack15(id self, SEL _cmd) {
    PHSetWantsJSON(self, NO);
    objc_setAssociatedObject(self, PHSharedJSONKey(), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (PHOriginalBack15) ((void (*)(id, SEL))PHOriginalBack15)(self, _cmd);
}

@interface PHV24JSONFlow : NSObject @end
@implementation PHV24JSONFlow
+ (void)load {
    Class target = NSClassFromString(@"PHInspectorViewController");
    if (!target) return;

    class_addMethod(target, @selector(ph_jsonTapped15), (IMP)PHJSONTapped15, "v@:");

    Method button = class_getInstanceMethod(target, @selector(button:action:));
    if (button) {
        PHOriginalButton15 = method_getImplementation(button);
        method_setImplementation(button, (IMP)PHButton15);
    }
    Method hierarchy = class_getInstanceMethod(target, @selector(hierarchyTapped));
    if (hierarchy) {
        PHOriginalHierarchy15 = method_getImplementation(hierarchy);
        method_setImplementation(hierarchy, (IMP)PHHierarchy15);
    }
    Method back = class_getInstanceMethod(target, @selector(backTapped));
    if (back) {
        PHOriginalBack15 = method_getImplementation(back);
        method_setImplementation(back, (IMP)PHBack15);
    }
}
@end
