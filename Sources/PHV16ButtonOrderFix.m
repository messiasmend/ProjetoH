#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

static void PHV16Apply(UIViewController *controller) {
    if (!controller.view) return;

    UIButton *hide = nil;
    UIButton *hidden = nil;
    UIButton *save = nil;
    PHV16FindButtons(controller.view, &hide, &hidden, &save);
    if (!hide || !hidden || !save) return;

    if (hide.superview != hidden.superview || hide.superview != save.superview) return;

    // V13 creates: Ocultar | Ocultos | Salvar.
    // V16 changes only the semantic labels/actions so the physical order
    // becomes: Ocultos | Ocultar | Salvar. No layout reordering is needed.
    NSString *hideTitle = [hide titleForState:UIControlStateNormal] ?: @"";
    NSString *hiddenTitle = [hidden titleForState:UIControlStateNormal] ?: @"";

    if ([hideTitle isEqualToString:@"Ocultar"] &&
        [hiddenTitle isEqualToString:@"Ocultos"]) {
        [hide removeTarget:controller action:@selector(hideTapped)
          forControlEvents:UIControlEventTouchUpInside];
        [hidden removeTarget:controller action:@selector(hiddenTapped)
            forControlEvents:UIControlEventTouchUpInside];

        [hide setTitle:@"Ocultos" forState:UIControlStateNormal];
        [hidden setTitle:@"Ocultar" forState:UIControlStateNormal];

        [hide addTarget:controller action:@selector(hiddenTapped)
       forControlEvents:UIControlEventTouchUpInside];
        [hidden addTarget:controller action:@selector(hideTapped)
         forControlEvents:UIControlEventTouchUpInside];
    }

    [controller.view setNeedsLayout];
    [controller.view layoutIfNeeded];
}

static void PHV16RenderSwizzled(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PHV16OriginalRender) {
        ((void (*)(id, SEL, BOOL))PHV16OriginalRender)(self, _cmd, hierarchyMode);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        PHV16Apply((UIViewController *)self);
        dispatch_async(dispatch_get_main_queue(), ^{
            PHV16Apply((UIViewController *)self);
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

        PHV16OriginalRender = current;
        method_setImplementation(render, (IMP)PHV16RenderSwizzled);
    });
}
