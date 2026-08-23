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

static void PHUIApplicationSendEvent(id self, SEL _cmd, UIEvent *event) {
    if (PHOriginalUIApplicationSendEvent != NULL) {
        PHOriginalUIApplicationSendEvent(self, _cmd, event);
    }

    [PHGestureDetector() processEvent:event];
}

static void PHInstallSendEventHook(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class applicationClass = objc_getClass("UIApplication");
        if (applicationClass == Nil) {
            return;
        }

        SEL selector = @selector(sendEvent:);
        Method method = class_getInstanceMethod(applicationClass, selector);
        if (method == NULL) {
            return;
        }

        IMP original = method_getImplementation(method);
        if (original == NULL) {
            return;
        }

        PHOriginalUIApplicationSendEvent = (void (*)(id, SEL, UIEvent *))original;
        method_setImplementation(method, (IMP)PHUIApplicationSendEvent);
    });
}

%ctor {
    @autoreleasepool {
        PHGestureDetector();
        PHInstallSendEventHook();
    }
}
