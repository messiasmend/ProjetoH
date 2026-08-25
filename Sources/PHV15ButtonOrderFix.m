#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
- (void)render:(BOOL)hierarchyMode;
@end

static void PHV15FindButtons(UIView *view, UIButton **ocultar, UIButton **ocultos) {
    if (!view) return;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal] ?: @"";
            if ([title isEqualToString:@"Ocultar"]) *ocultar = button;
            else if ([title isEqualToString:@"Ocultos"]) *ocultos = button;
        }
        PHV15FindButtons(subview, ocultar, ocultos);
    }
}

static void PHV15ApplyButtonOrder(PHInspectorViewController *controller) {
    UIButton *ocultar = nil;
    UIButton *ocultos = nil;
    PHV15FindButtons(controller.view, &ocultar, &ocultos);
    if (!ocultar || !ocultos || ocultar.superview != ocultos.superview) return;

    UIView *panel = ocultar.superview;
    for (NSLayoutConstraint *constraint in panel.constraints.copy) {
        if (constraint.firstItem == ocultar && constraint.firstAttribute == NSLayoutAttributeLeading) {
            constraint.active = NO;
        }
        if (constraint.firstItem == ocultos && constraint.firstAttribute == NSLayoutAttributeCenterX) {
            constraint.active = NO;
        }
    }

    [NSLayoutConstraint activateConstraints:@[
        [ocultos.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [ocultar.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor]
    ]];
}

static void PHV15RenderSwizzled(PHInspectorViewController *self, BOOL hierarchyMode) {
    Method originalMethod = class_getInstanceMethod(NSClassFromString(@"PHInspectorViewController"), @selector(render:));
    IMP originalIMP = method_getImplementation(originalMethod);
    ((void (*)(id, SEL, BOOL))originalIMP)(self, @selector(render:), hierarchyMode);
    dispatch_async(dispatch_get_main_queue(), ^{
        PHV15ApplyButtonOrder(self);
    });
}

__attribute__((constructor)) static void PHV15InstallButtonOrderFix(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;
        Method render = class_getInstanceMethod(cls, @selector(render:));
        if (!render) return;
        IMP current = method_getImplementation(render);
        if (current == (IMP)PHV15RenderSwizzled) return;
        method_setImplementation(render, (IMP)PHV15RenderSwizzled);
    });
}
