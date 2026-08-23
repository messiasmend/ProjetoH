#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Sources/PHThreeFingerGesture.h"

static PHThreeFingerGesture *PHGestureDetector(void) {
    static PHThreeFingerGesture *detector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        detector = [PHThreeFingerGesture new];
    });
    return detector;
}

static void (*PHOriginalUIApplicationSendEvent)(id, SEL, UIEvent *);
static void (*PHOriginalUIWindowSendEvent)(id, SEL, UIEvent *);

static void PHProcessEvent(UIEvent *event) {
    if (event != nil) {
        [PHGestureDetector() processEvent:event];
    }
}

static void PHUIApplicationSendEvent(id self, SEL _cmd, UIEvent *event) {
    if (PHOriginalUIApplicationSendEvent != NULL) {
        PHOriginalUIApplicationSendEvent(self, _cmd, event);
    }

    PHProcessEvent(event);
}

static void PHUIWindowSendEvent(id self, SEL _cmd, UIEvent *event) {
    if (PHOriginalUIWindowSendEvent != NULL) {
        PHOriginalUIWindowSendEvent(self, _cmd, event);
    }

    PHProcessEvent(event);
}

static BOOL PHInstallHook(Class cls, SEL selector, IMP replacement, void (**originalStorage)(id, SEL, UIEvent *)) {
    if (cls == Nil) {
        return NO;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL) {
        return NO;
    }

    IMP original = method_getImplementation(method);
    if (original == NULL || original == replacement) {
        return NO;
    }

    *originalStorage = (void (*)(id, SEL, UIEvent *))original;
    method_setImplementation(method, replacement);
    return YES;
}

static void PHInstallSendEventHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class applicationClass = objc_getClass("UIApplication");
        Class windowClass = objc_getClass("UIWindow");
        SEL selector = @selector(sendEvent:);

        PHInstallHook(applicationClass,
                      selector,
                      (IMP)PHUIApplicationSendEvent,
                      &PHOriginalUIApplicationSendEvent);

        PHInstallHook(windowClass,
                      selector,
                      (IMP)PHUIWindowSendEvent,
                      &PHOriginalUIWindowSendEvent);
    });
}

%ctor {
    @autoreleasepool {
        PHGestureDetector();

        // UIKit classes can be initialized very early during dylib loading.
        // Defer installation to the main queue so the classes and UIApplication
        // lifecycle are settled before we alter their implementations.
        dispatch_async(dispatch_get_main_queue(), ^{
            PHInstallSendEventHooks();
        });
    }
}
