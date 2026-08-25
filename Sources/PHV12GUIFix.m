#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char PHV12GUIFixSaveKey;

static UIViewController *PHV12GUIFixInspector(void) {
    Class c = NSClassFromString(@"PHOverlayManager");
    if (!c || ![c respondsToSelector:@selector(sharedManager)]) return nil;
    id manager = [c performSelector:@selector(sharedManager)];
    return [manager valueForKey:@"inspectorViewController"];
}

static id PHV12GUITarget(void) {
    Class c = NSClassFromString(@"PHV12Target");
    if (!c || ![c respondsToSelector:@selector(shared)]) return nil;
    return [c performSelector:@selector(shared)];
}

static UIButton *PHV12GUIButton(NSString *title, id target, SEL action) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void PHV12GUIUpdateSaveState(void) {
    UIViewController *vc = PHV12GUIFixInspector();
    UIButton *save = objc_getAssociatedObject(vc, &PHV12GUIFixSaveKey);
    if (!save) return;
    Class targetClass = NSClassFromString(@"PHV12Target");
    id target = targetClass ? [targetClass performSelector:@selector(shared)] : nil;
    (void)target;
    // PHV12Target keeps its pending selectors in a private static array.
    // The button is intentionally always tappable; the target safely ignores
    // Save when there are no pending changes. This avoids duplicating state.
    save.enabled = YES;
    save.alpha = 1.0;
}

static void PHV12GUIRebuildButtons(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = PHV12GUIFixInspector();
        if (!vc || !vc.view) return;

        UIView *panel = nil;
        for (UIView *v in vc.view.subviews.reverseObjectEnumerator) {
            if ([v isKindOfClass:UIView.class] && fabs(v.bounds.size.width - 350.0) < 4.0 && fabs(v.bounds.size.height - 430.0) < 8.0) {
                panel = v;
                break;
            }
        }
        if (!panel) return;

        // The V12 logic adds its buttons after the original inspector buttons.
        // Remove every button from the panel first so no old constraints/layout
        // can leave overlapping controls behind.
        for (UIView *v in panel.subviews.copy) {
            if ([v isKindOfClass:UIButton.class]) [v removeFromSuperview];
        }

        // Give the panel a little more vertical room for two clean action rows.
        for (NSLayoutConstraint *c in panel.superview.constraints.copy) {
            if ((c.firstItem == panel && c.firstAttribute == NSLayoutAttributeHeight) ||
                (c.secondItem == panel && c.secondAttribute == NSLayoutAttributeHeight)) {
                if (fabs(c.constant - 430.0) < 2.0) c.constant = 470.0;
            }
        }
        for (NSLayoutConstraint *c in panel.constraints.copy) {
            if ((c.firstItem == panel && c.firstAttribute == NSLayoutAttributeHeight) ||
                (c.secondItem == panel && c.secondAttribute == NSLayoutAttributeHeight)) {
                if (fabs(c.constant - 430.0) < 2.0) c.constant = 470.0;
            }
        }

        id target = PHV12GUITarget();
        if (!target) return;

        UIButton *hierarchy = PHV12GUIButton(@"Hierarquia", vc, @selector(hierarchyTapped));
        UIButton *copy = PHV12GUIButton(@"Copiar", vc, @selector(copyTapped));
        UIButton *close = PHV12GUIButton(@"Fechar", vc, @selector(closeTapped));
        UIButton *hide = PHV12GUIButton(@"Ocultar", target, @selector(hide));
        UIButton *hidden = PHV12GUIButton(@"Ocultos", target, @selector(manage));
        UIButton *save = PHV12GUIButton(@"Salvar", target, @selector(save));

        UIStackView *row1 = [[UIStackView alloc] initWithArrangedSubviews:@[hierarchy, copy, close]];
        row1.translatesAutoresizingMaskIntoConstraints = NO;
        row1.axis = UILayoutConstraintAxisHorizontal;
        row1.alignment = UIStackViewAlignmentCenter;
        row1.distribution = UIStackViewDistributionFillEqually;
        row1.spacing = 2.0;

        UIStackView *row2 = [[UIStackView alloc] initWithArrangedSubviews:@[hide, hidden, save]];
        row2.translatesAutoresizingMaskIntoConstraints = NO;
        row2.axis = UILayoutConstraintAxisHorizontal;
        row2.alignment = UIStackViewAlignmentCenter;
        row2.distribution = UIStackViewDistributionFillEqually;
        row2.spacing = 2.0;

        [panel addSubview:row1];
        [panel addSubview:row2];
        [NSLayoutConstraint activateConstraints:@[
            [row1.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [row1.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [row1.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-58.0],
            [row1.heightAnchor constraintEqualToConstant:34.0],
            [row2.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [row2.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [row2.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0],
            [row2.heightAnchor constraintEqualToConstant:34.0]
        ]];

        objc_setAssociatedObject(vc, &PHV12GUIFixSaveKey, save, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        PHV12GUIUpdateSaveState();
    });
}

static void (*PHV12GUIOrigShow)(id, SEL, NSString *) = NULL;
static void PHV12GUIShow(id self, SEL cmd, NSString *details) {
    if (PHV12GUIOrigShow) PHV12GUIOrigShow(self, cmd, details);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PHV12GUIRebuildButtons();
    });
}

static void (*PHV12GUIOrigHide)(id, SEL) = NULL;
static void PHV12GUIHide(id self, SEL cmd) {
    if (PHV12GUIOrigHide) PHV12GUIOrigHide(self, cmd);
    dispatch_async(dispatch_get_main_queue(), ^{ PHV12GUIUpdateSaveState(); });
}

static void (*PHV12GUIOrigSave)(id, SEL) = NULL;
static void PHV12GUISave(id self, SEL cmd) {
    if (PHV12GUIOrigSave) PHV12GUIOrigSave(self, cmd);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PHV12GUIUpdateSaveState();
    });
}

__attribute__((constructor)) static void PHV12GUIFixInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Class inspector = NSClassFromString(@"PHInspectorViewController");
            Method show = class_getInstanceMethod(inspector, @selector(showSelectedWebElement:));
            if (show) {
                PHV12GUIOrigShow = (void (*)(id, SEL, NSString *))method_getImplementation(show);
                method_setImplementation(show, (IMP)PHV12GUIShow);
            }

            Class target = NSClassFromString(@"PHV12Target");
            Method hide = class_getInstanceMethod(target, @selector(hide));
            if (hide) {
                PHV12GUIOrigHide = (void (*)(id, SEL))method_getImplementation(hide);
                method_setImplementation(hide, (IMP)PHV12GUIHide);
            }
            Method save = class_getInstanceMethod(target, @selector(save));
            if (save) {
                PHV12GUIOrigSave = (void (*)(id, SEL))method_getImplementation(save);
                method_setImplementation(save, (IMP)PHV12GUISave);
            }
        });
    });
}
