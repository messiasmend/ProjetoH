#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Sources/PHThreeFingerGesture.h"
#import "Sources/PHOverlayManager.h"
#import "Sources/PHPreciseSelector.h"

static PHThreeFingerGesture *PHGestureDetector(void) {
    static PHThreeFingerGesture *detector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ detector = [PHThreeFingerGesture new]; });
    return detector;
}

static void (*PHOriginalUIApplicationSendEvent)(id, SEL, UIEvent *);
static void (*PHOriginalUIWindowSendEvent)(id, SEL, UIEvent *);

static void PHProcessEventBeforeOriginal(UIEvent *event) {
    if (event == nil) return;
    UIWindow *inspectorWindow = [PHOverlayManager sharedManager].inspectorWindow;
    [[PHPreciseSelector sharedSelector] processEvent:event inspectorWindow:inspectorWindow];
}

static void PHProcessEventAfterOriginal(UIEvent *event) {
    if (event == nil) return;
    [PHGestureDetector() processEvent:event];
}

static void PHUIApplicationSendEvent(id self, SEL _cmd, UIEvent *event) {
    PHProcessEventBeforeOriginal(event);
    if (PHOriginalUIApplicationSendEvent != NULL) PHOriginalUIApplicationSendEvent(self, _cmd, event);
    PHProcessEventAfterOriginal(event);
}

static void PHUIWindowSendEvent(id self, SEL _cmd, UIEvent *event) {
    PHProcessEventBeforeOriginal(event);
    if (PHOriginalUIWindowSendEvent != NULL) PHOriginalUIWindowSendEvent(self, _cmd, event);
    PHProcessEventAfterOriginal(event);
}

static BOOL PHInstallHook(Class cls, SEL selector, IMP replacement, void (**originalStorage)(id, SEL, UIEvent *)) {
    if (cls == Nil) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL) return NO;
    IMP original = method_getImplementation(method);
    if (original == NULL || original == replacement) return NO;
    *originalStorage = (void (*)(id, SEL, UIEvent *))original;
    method_setImplementation(method, replacement);
    return YES;
}

static void PHInstallSendEventHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selector = @selector(sendEvent:);
        Class applicationClass = objc_getClass("UIApplication");
        Class windowClass = objc_getClass("UIWindow");
        PHInstallHook(applicationClass, selector, (IMP)PHUIApplicationSendEvent, &PHOriginalUIApplicationSendEvent);
        PHInstallHook(windowClass, selector, (IMP)PHUIWindowSendEvent, &PHOriginalUIWindowSendEvent);
    });
}

%ctor {
    @autoreleasepool {
        PHGestureDetector();
        [PHPreciseSelector sharedSelector];
        dispatch_async(dispatch_get_main_queue(), ^{ PHInstallSendEventHooks(); });
    }
}
