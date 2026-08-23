#import "PHThreeFingerGesture.h"
#import "PHOverlayManager.h"

static NSTimeInterval const PHThreeFingerHoldInterval = 0.8;
// Temporary activation threshold for the injection test. We will restore the
// reference gesture threshold after confirming the standalone dylib works.
static NSUInteger const PHActivationMinimumTouches = 2;

@interface PHThreeFingerGesture ()
@property (nonatomic, strong, nullable) NSTimer *holdTimer;
@property (nonatomic, assign) BOOL triggered;
@end

@implementation PHThreeFingerGesture

- (void)processEvent:(UIEvent *)event {
    if (![event respondsToSelector:@selector(allTouches)]) {
        return;
    }

    NSSet<UITouch *> *touches = event.allTouches;
    NSUInteger activeTouches = 0;

    for (UITouch *touch in touches) {
        UITouchPhase phase = touch.phase;
        if (phase == UITouchPhaseBegan ||
            phase == UITouchPhaseMoved ||
            phase == UITouchPhaseStationary) {
            activeTouches += 1;
        }
    }

    if (activeTouches >= PHActivationMinimumTouches) {
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
