#import "PHPreciseSelector.h"
#import "PHOverlayManager.h"

@interface PHPreciseSelector ()
@property (nonatomic, assign) BOOL consumed;
@end

@implementation PHPreciseSelector

+ (instancetype)sharedSelector {
    static PHPreciseSelector *selector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ selector = [PHPreciseSelector new]; });
    return selector;
}

- (void)reset { self.consumed = NO; }

- (UIView *)deepestVisibleView:(UIView *)view point:(CGPoint)point {
    if (view == nil || view.hidden || view.alpha <= 0.01) return nil;
    if (![view pointInside:point withEvent:nil]) return nil;
    for (UIView *child in view.subviews.reverseObjectEnumerator) {
        if (child.hidden || child.alpha <= 0.01) continue;
        CGPoint childPoint = [view convertPoint:point toView:child];
        UIView *found = [self deepestVisibleView:child point:childPoint];
        if (found != nil) return found;
    }
    return view;
}

- (UIView *)viewUnderTouch:(UITouch *)touch inspectorWindow:(UIWindow *)inspectorWindow {
    UIWindow *window = touch.window;
    if (window == nil || window == inspectorWindow) return nil;
    CGPoint windowPoint = [touch locationInView:window];
    UIView *root = window.rootViewController.view;
    if (root == nil) return nil;
    CGPoint rootPoint = [root convertPoint:windowPoint fromView:window];
    UIView *deepest = [self deepestVisibleView:root point:rootPoint];
    if (deepest != nil) return deepest;
    return [window hitTest:windowPoint withEvent:nil];
}

- (void)processEvent:(UIEvent *)event inspectorWindow:(UIWindow *)inspectorWindow {
    if (self.consumed || event == nil || ![event respondsToSelector:@selector(allTouches)]) return;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseBegan || touch.window == inspectorWindow) continue;
        UIView *selected = [self viewUnderTouch:touch inspectorWindow:inspectorWindow];
        if (selected == nil) continue;
        self.consumed = YES;
        [[PHOverlayManager sharedManager] selectView:selected];
        return;
    }
}
@end
