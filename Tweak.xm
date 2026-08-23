#import <UIKit/UIKit.h>
#import "Sources/PHThreeFingerGesture.h"

static PHThreeFingerGesture *PHGestureDetector(void) {
    static PHThreeFingerGesture *detector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        detector = [PHThreeFingerGesture new];
    });
    return detector;
}

%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;
    [PHGestureDetector() processEvent:event];
}

%end

%ctor {
    @autoreleasepool {
        PHGestureDetector();
    }
}
