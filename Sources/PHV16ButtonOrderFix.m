#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/*
 * ProjetoH V16
 *
 * Finalizes the inspector button semantics after the V13 render and V15
 * compatibility layer have run.
 *
 * Required second row:
 *   Ocultos | Ocultar | Salvar
 *
 * The V13 renderer creates the controls in the physical positions:
 *   Ocultar | Ocultos | Salvar
 * The V15 patch attempts to swap their titles/actions, but its inspector
 * lookup can miss because the render receiver is already the inspector.
 * V16 works directly on that receiver and performs the swap after render.
 *
 * No bundle identifier is referenced.
 */

static IMP PHV16OriginalRender = NULL;

static void PHV16FindButtons(UIView *root, UIButton **hide, UIButton **hidden, UIButton **save) {
    if (!root) return;
    for (UIView *v in [root.subviews copy]) {
        if ([v isKindOfClass:UIButton.class]) {
            UIButton *b = (UIButton *)v;
            NSString *title = [b titleForState:UIControlStateNormal] ?: @"";
            if ([title isEqualToString:@"Ocultar"]) *hide = b;
            else if ([title isEqualToString:@"Ocultos"]) *hidden = b;
            else if ([title isEqualToString:@"Salvar"]) *save = b;
        }
        PHV16FindButtons(v, hide, hidden, save);
    }
}

static void PHV16Apply(PHInspectorViewController *controller) {
    if (!controller.view) return;

    UIButton *hide = nil;
    UIButton *hidden = nil;
    UIButton *save = nil;
    PHV16FindButtons(controller.view, &hide, &hidden, &save);

    if (!hide || !hidden || !save) return;
    if (hide.superview != hidden.superview || hide.superview != save.superview) return;

    /*
     * The desired visual order uses the existing physical positions.
     * Therefore only the semantic labels/actions need to be exchanged.
     * If the V15 patch already did this, the titles are already correct and
     * this block becomes a no-op.
     */
    NSString *hideTitle = [hide titleForState:UIControlStateNormal] ?: @"";
    NSString *hiddenTitle = [hidden titleForState:UIControlStateNormal] ?: @"";

    if ([hideTitle isEqualToString:@"Ocultar"] &&
        [hiddenTitle isEqualToString:@"Ocultos"]) {
        [hide removeTarget:controller
                    action:@selector(hideTapped)
          forControlEvents:UIControlEventTouchUpInside];
        [hidden removeTarget:controller
                       action:@selector(hiddenTapped)
             forControlEvents:UIControlEventTouchUpInside];

        [hide setTitle:@"Ocultos" forState:UIControlStateNormal];
        [hidden setTitle:@"Ocultar" forState:UIControlStateNormal];

        [hide addTarget:controller
                 action:@selector(hiddenTapped)
       forControlEvents:UIControlEventTouchUpInside];
        [hidden addTarget:controller
                   action:@selector(hideTapped)
         forControlEvents:UIControlEventTouchUpInside];
    }

    [controller.view setNeedsLayout];
    [controller.view layoutIfNeeded];
}

static void PHV16RenderSwizzled(PHInspectorViewController *self,
                                SEL _cmd,
                                BOOL hierarchyMode) {
    if (PHV16OriginalRender) {
        ((void (*)(id, SEL, BOOL))PHV16OriginalRender)(self, _cmd, hierarchyMode);
    }

    /*
     * V13 creates the actual inspector asynchronously on the main queue.
     * This pass is deliberately scheduled after the original render call.
     * A second pass handles the case where the V15 layer queues its own
     * post-render work immediately after the original render returns.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        PHV16Apply(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            PHV16Apply(self);
        });
    });
}

__attribute__((constructor)) static void PHV16Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;

        Method render = class_getInstanceMethod(cls, @selector(render:));
        if (!render) return;

        IMP current = method_getImplementation(render);
        if (current == (IMP)PHV16RenderSwizzled) return;

        /*
         * Because this source is compiled after PHV15Patch.m in the Makefile,
         * its constructor is queued after the V15 constructor. Thus current
         * normally points at the V15 implementation and V16 wraps it rather
         * than bypassing it.
         */
        PHV16OriginalRender = current;
        method_setImplementation(render, (IMP)PHV16RenderSwizzled);
    });
}
