#import "PHThreeFingerGesture.h"
#import "PHOverlayManager.h"

static NSTimeInterval const PHThreeFingerHoldInterval = 0.8;

@interface PHThreeFingerGesture ()
@property (nonatomic, strong, nullable) NSTimer *holdTimer;
@property (nonatomic, assign) BOOL triggered;
@end

@implementation PHThreeFingerGesture

- (void)processEvent:(UIEvent *)event {
    if (![event respondsToSelector:@selector(allTouches)]) {
        return;
    }

    // The reference implementation evaluates the UIEvent after the
    // application's original sendEvent: has completed. Keep that behavior
    // and use the touch phase as the qualification filter rather than a
    // UIGestureRecognizer abstraction.
    NSSet<UITouch *> *touches = event.allTouches;
    NSUInteger qualifyingTouches = 0;

    for (UITouch *touch in touches) {
        // Match the reference's phase-based qualification (phase > 2).
        // This includes stationary/ended/cancelled states and deliberately
        // does not replace the mechanism with a tap recognizer.
        if (touch.phase > UITouchPhaseMoved) {
            qualifyingTouches += 1;
        }
    }

    if (qualifyingTouches >= 3) {
        [self armIfNeeded];
    } else {
        [self cancelHoldAndResetTrigger];
    }
}

- (void)armIfNeeded {
    if (self.triggered || self.holdTimer != nil) {
        return;
    }

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self armIfNeeded];
        });
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.holdTimer = [NSTimer timerWithTimeInterval:PHThreeFingerHoldInterval
                                              repeats:NO
                                                block:^(__unused NSTimer *timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf handleHoldTimerFired];
    }];

    [[NSRunLoop mainRunLoop] addTimer:self.holdTimer
                              forMode:NSRunLoopCommonModes];
}

- (void)handleHoldTimerFired {
    self.holdTimer = nil;

    if (self.triggered) {
        return;
    }

    self.triggered = YES;
    [[PHOverlayManager sharedManager] presentTestOverlayIfNeeded];
}

- (void)cancelHoldAndResetTrigger {
    [self cancelTimer];
    self.triggered = NO;
}

- (void)cancelTimer {
    [self.holdTimer invalidate];
    self.holdTimer = nil;
}

- (void)reset {
    [self cancelHoldAndResetTrigger];
}

@end
