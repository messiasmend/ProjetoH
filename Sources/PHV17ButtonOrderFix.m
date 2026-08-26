#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/*
 * ProjetoH V17 — final physical button layout fix.
 *
 * The inspector does NOT use a UIStackView. The three lower buttons are
 * positioned by Auto Layout constraints on their common panel. V17 therefore
 * fixes the actual constraints instead of renaming buttons or changing their
 * target/actions.
 *
 * Required physical order:
 *   Ocultos | Ocultar | Salvar
 *
 * The existing V15 behavior is intentionally preserved. V17 only enforces
 * the physical positions after the final render has completed.
 */

static IMP PHV17OriginalRender = NULL;

static void PHV17FindButtons(UIView *root, UIButton **hide, UIButton **hidden, UIButton **save) {
    if (!root) return;
    for (UIView *v in [root.subviews copy]) {
        if ([v isKindOfClass:UIButton.class]) {
            UIButton *b = (UIButton *)v;
            NSString *title = [b titleForState:UIControlStateNormal] ?: @"";
            if ([title isEqualToString:@"Ocultar"]) *hide = b;
            else if ([title isEqualToString:@"Ocultos"]) *hidden = b;
            else if ([title isEqualToString:@"Salvar"]) *save = b;
        }
        PHV17FindButtons(v, hide, hidden, save);
    }
}

static BOOL PHV17IsHorizontalPositionConstraint(NSLayoutConstraint *c, UIButton *button) {
    if (!c || !button) return NO;
    NSLayoutAttribute a = c.firstAttribute;
    NSLayoutAttribute b = c.secondAttribute;
    BOOL horizontal = (a == NSLayoutAttributeLeading || a == NSLayoutAttributeTrailing || a == NSLayoutAttributeCenterX);
    BOOL horizontalSecond = (b == NSLayoutAttributeLeading || b == NSLayoutAttributeTrailing || b == NSLayoutAttributeCenterX);
    if (!horizontal && !horizontalSecond) return NO;
    return c.firstItem == button || c.secondItem == button;
}

static void PHV17RemoveHorizontalPositionConstraints(UIButton *button, UIView *panel) {
    if (!button || !panel) return;

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    [constraints addObjectsFromArray:panel.constraints];
    [constraints addObjectsFromArray:button.constraints];

    for (NSLayoutConstraint *c in constraints) {
        if (PHV17IsHorizontalPositionConstraint(c, button)) {
            c.active = NO;
        }
    }
}

static void PHV17Apply(UIViewController *controller) {
    if (!controller.view) return;

    UIButton *hide = nil;
    UIButton *hidden = nil;
    UIButton *save = nil;
    PHV17FindButtons(controller.view, &hide, &hidden, &save);

    if (!hide || !hidden || !save) return;
    if (hide.superview != hidden.superview || hide.superview != save.superview) return;

    UIView *panel = hide.superview;
    if (!panel.translatesAutoresizingMaskIntoConstraints) {
        // Expected inspector panel. Continue; this also avoids assumptions
        // about a concrete panel class.
    }

    // Remove ONLY the horizontal position constraints for these three buttons.
    // Width and bottom constraints remain untouched.
    PHV17RemoveHorizontalPositionConstraints(hide, panel);
    PHV17RemoveHorizontalPositionConstraints(hidden, panel);
    PHV17RemoveHorizontalPositionConstraints(save, panel);

    // Enforce the physical positions by semantic button identity.
    // Do not modify titles, targets, or actions.
    [NSLayoutConstraint activateConstraints:@[
        [hidden.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [hide.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
        [save.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0]
    ]];

    [panel setNeedsLayout];
    [controller.view setNeedsLayout];
    [panel layoutIfNeeded];
}

static void PHV17Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PHV17OriginalRender) {
        ((void (*)(id, SEL, BOOL))PHV17OriginalRender)(self, _cmd, hierarchyMode);
    }

    // V13/V15 rebuild the inspector synchronously, while some presentation
    // paths dispatch the render onto the main queue. Two passes ensure the
    // physical constraints are applied after that rebuild.
    dispatch_async(dispatch_get_main_queue(), ^{
        PHV17Apply((UIViewController *)self);
        dispatch_async(dispatch_get_main_queue(), ^{
            PHV17Apply((UIViewController *)self);
        });
    });
}

__attribute__((constructor)) static void PHV17Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            Class cls = NSClassFromString(@"PHInspectorViewController");
            if (!cls) return;

            SEL renderSEL = @selector(render:);
            Method render = class_getInstanceMethod(cls, renderSEL);
            if (!render) return;

            IMP current = method_getImplementation(render);
            if (current == (IMP)PHV17Render) return;

            PHV17OriginalRender = current;
            method_setImplementation(render, (IMP)PHV17Render);
        });
    });
}
