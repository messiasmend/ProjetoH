#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP PHV17OriginalRender = NULL;

static UIButton *PHV17FindButton(UIView *root, NSString *title) {
    if (!root) return nil;
    if ([root isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)root;
        NSString *current = [button titleForState:UIControlStateNormal] ?: @"";
        if ([current isEqualToString:title]) return button;
    }
    for (UIView *child in [root.subviews copy]) {
        UIButton *result = PHV17FindButton(child, title);
        if (result) return result;
    }
    return nil;
}

static void PHV17Reorder(UIViewController *controller) {
    UIView *root = controller.view;
    if (!root) return;

    UIButton *ocultar = PHV17FindButton(root, @"Ocultar");
    UIButton *ocultos = PHV17FindButton(root, @"Ocultos");
    UIButton *salvar = PHV17FindButton(root, @"Salvar");
    if (!ocultar || !ocultos || !salvar) return;

    // Physical order is controlled by Auto Layout. Keep titles, targets and
    // actions untouched; replace only the horizontal placement constraints.
    UIView *panel = ocultar.superview;
    if (panel != ocultos.superview || panel != salvar.superview) return;

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    for (NSLayoutConstraint *c in [panel.constraints copy]) {
        BOOL horizontal = (c.firstAttribute == NSLayoutAttributeLeading ||
                           c.firstAttribute == NSLayoutAttributeTrailing ||
                           c.firstAttribute == NSLayoutAttributeCenterX);
        BOOL involvesButtons = (c.firstItem == ocultar || c.secondItem == ocultar ||
                                c.firstItem == ocultos || c.secondItem == ocultos ||
                                c.firstItem == salvar || c.secondItem == salvar);
        if (horizontal && involvesButtons) [constraints addObject:c];
    }
    if (constraints.count) [panel removeConstraints:constraints];

    ocultos.translatesAutoresizingMaskIntoConstraints = NO;
    ocultar.translatesAutoresizingMaskIntoConstraints = NO;
    salvar.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [ocultos.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
        [ocultar.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
        [salvar.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18]
    ]];

    [panel setNeedsLayout];
    [panel layoutIfNeeded];
}

static void PHV17Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PHV17OriginalRender) {
        ((void (*)(id, SEL, BOOL))PHV17OriginalRender)(self, _cmd, hierarchyMode);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        PHV17Reorder((UIViewController *)self);
        dispatch_async(dispatch_get_main_queue(), ^{
            PHV17Reorder((UIViewController *)self);
        });
    });
}

__attribute__((constructor))
static void PHV17Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;

        Method method = class_getInstanceMethod(cls, @selector(render:));
        if (!method) return;

        IMP current = method_getImplementation(method);
        if (current == (IMP)PHV17Render) return;

        PHV17OriginalRender = current;
        method_setImplementation(method, (IMP)PHV17Render);
    });
}
