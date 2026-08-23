#import "PHOverlayManager.h"

@interface PHInspectorViewController : UIViewController
@property (nonatomic, assign) BOOL selectionMode;
@property (nonatomic, strong, nullable) UIView *selectedView;
@property (nonatomic, strong, nullable) UIView *highlightView;
+ (NSString *)descriptionForView:(UIView *)view;
- (void)showSelectionPrompt;
- (void)showSelectedView:(UIView *)view;
@end

@interface PHOverlayManager ()
@property (nonatomic, weak, nullable) UIViewController *presentingViewController;
@property (nonatomic, strong, nullable) PHInspectorViewController *inspectorViewController;
@property (nonatomic, strong, nullable) UIWindow *inspectorWindow;
@property (nonatomic, assign) BOOL selectionModeActive;
@property (nonatomic, weak, nullable) UIView *highlightedView;
@property (nonatomic, assign) CGFloat previousBorderWidth;
@property (nonatomic, strong, nullable) UIColor *previousBorderColor;
@end

@implementation PHInspectorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    [self showSelectionPrompt];
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (void)clearSubviews {
    for (UIView *view in self.view.subviews.copy) [view removeFromSuperview];
}

- (UIView *)makePanel {
    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.97];
    panel.layer.cornerRadius = 18.0;
    panel.layer.masksToBounds = YES;
    return panel;
}

- (UIButton *)makeCloseButton {
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setTitle:@"Fechar" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    return close;
}

- (void)showSelectionPrompt {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clearSubviews];
        self.selectionMode = YES;
        UILabel *bubble = [self labelWithText:@"🔍  Toque no elemento que deseja inspecionar" font:[UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold] color:UIColor.whiteColor];
        bubble.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
        bubble.layer.cornerRadius = 22.0;
        bubble.layer.masksToBounds = YES;
        bubble.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:bubble];
        [NSLayoutConstraint activateConstraints:@[
            [bubble.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [bubble.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18.0],
            [bubble.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20.0],
            [bubble.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20.0],
            [bubble.heightAnchor constraintEqualToConstant:44.0],
            [bubble.widthAnchor constraintEqualToConstant:330.0]
        ]];
    });
}

- (void)showSelectedView:(UIView *)view {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.selectionMode = NO;
        [self clearSubviews];
        UIView *panel = [self makePanel];
        UILabel *title = [self labelWithText:@"ProjetoH Inspector" font:[UIFont boldSystemFontOfSize:21.0] color:UIColor.whiteColor];
        UILabel *subtitle = [self labelWithText:@"Elemento selecionado" font:[UIFont systemFontOfSize:14.0] color:[UIColor colorWithWhite:0.72 alpha:1.0]];
        NSString *text = [PHInspectorViewController descriptionForView:view];
        UILabel *details = [self labelWithText:text font:[UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular] color:[UIColor colorWithWhite:0.86 alpha:1.0]];
        UIButton *close = [self makeCloseButton];
        UIButton *hierarchy = [UIButton buttonWithType:UIButtonTypeSystem];
        hierarchy.translatesAutoresizingMaskIntoConstraints = NO;
        [hierarchy setTitle:@"Hierarquia" forState:UIControlStateNormal];
        hierarchy.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        [panel addSubview:title]; [panel addSubview:subtitle]; [panel addSubview:details]; [panel addSubview:hierarchy]; [panel addSubview:close]; [self.view addSubview:panel];
        [NSLayoutConstraint activateConstraints:@[
            [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
            [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:12.0],
            [panel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-12.0],
            [panel.widthAnchor constraintEqualToConstant:350.0], [panel.heightAnchor constraintEqualToConstant:430.0],
            [title.topAnchor constraintEqualToAnchor:panel.topAnchor constant:22.0], [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
            [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5.0], [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [details.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:20.0], [details.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0], [details.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [hierarchy.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0], [hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0], [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0]
        ]];
    });
}

+ (NSString *)descriptionForView:(UIView *)view {
    CGRect frame = view.frame;
    return [NSString stringWithFormat:@"Classe: %@\n\nFrame:\n  x: %.1f\n  y: %.1f\n  largura: %.1f\n  altura: %.1f\n\nTag: %ld\nHidden: %@\nAlpha: %.2f\nInteração: %@", NSStringFromClass(view.class), frame.origin.x, frame.origin.y, frame.size.width, frame.size.height, (long)view.tag, view.hidden ? @"SIM" : @"NÃO", view.alpha, view.userInteractionEnabled ? @"SIM" : @"NÃO"];
}

- (void)closeTapped { [[PHOverlayManager sharedManager] dismissOverlay]; }
@end

@implementation PHOverlayManager

+ (instancetype)sharedManager {
    static PHOverlayManager *manager; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [PHOverlayManager new]; });
    return manager;
}

- (void)presentTestOverlayIfNeeded { [self startSelectionMode]; }

- (UIViewController *)topViewControllerFrom:(UIViewController *)root {
    UIViewController *current = root;
    while (current.presentedViewController != nil && !current.isBeingDismissed) current = current.presentedViewController;
    if ([current isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = [(UINavigationController *)current visibleViewController];
        if (visible != nil && visible != current) return [self topViewControllerFrom:visible];
    }
    if ([current isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = [(UITabBarController *)current selectedViewController];
        if (selected != nil && selected != current) return [self topViewControllerFrom:selected];
    }
    return current;
}

- (UIWindow *)activeKeyWindow {
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if (![candidate isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *scene = (UIWindowScene *)candidate;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in scene.windows.reverseObjectEnumerator) if (window.isKeyWindow && !window.hidden && window.alpha > 0.0) return window;
        for (UIWindow *window in scene.windows.reverseObjectEnumerator) if (!window.hidden && window.alpha > 0.0 && window.rootViewController != nil) return window;
    }
    return nil;
}

- (void)installInspectorWindowIfNeeded {
    if (self.inspectorWindow != nil) return;
    UIWindow *appWindow = [self activeKeyWindow];
    if (appWindow == nil || appWindow.windowScene == nil) return;
    PHInspectorViewController *controller = [PHInspectorViewController new];
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:appWindow.windowScene];
    window.frame = appWindow.bounds;
    window.windowLevel = UIWindowLevelAlert + 1.0;
    window.backgroundColor = UIColor.clearColor;
    window.rootViewController = controller;
    window.hidden = NO;
    /* The inspector must never become the hit-test target while selection is active. */
    window.userInteractionEnabled = NO;
    self.inspectorViewController = controller;
    self.inspectorWindow = window;
}

- (void)presentInspectorIfNeeded { [self startSelectionMode]; }

- (void)startSelectionMode {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self installInspectorWindowIfNeeded];
        if (self.inspectorWindow == nil) return;
        self.selectionModeActive = YES;
        [self.inspectorViewController showSelectionPrompt];
        self.inspectorWindow.userInteractionEnabled = NO;
    });
}

/* Recursive selector used instead of UIView hitTest:. hitTest: ignores views
   that have userInteractionEnabled == NO, which is exactly what happens with
   many UIImageView/UILabel elements. Inspector selection must still be able
   to select those visual elements. */
- (UIView *)deepestViewFrom:(UIView *)view point:(CGPoint)point {
    if (view == nil || view.hidden || view.alpha <= 0.01) return nil;
    if (![view pointInside:point withEvent:nil]) return nil;

    for (UIView *subview in view.subviews.reverseObjectEnumerator) {
        CGPoint subPoint = [subview convertPoint:point fromView:view];
        UIView *deepest = [self deepestViewFrom:subview point:subPoint];
        if (deepest != nil) return deepest;
    }
    return view;
}

- (UIView *)deepestViewAtPoint:(CGPoint)point inWindow:(UIWindow *)window {
    if (window == nil || window.hidden || window.alpha <= 0.0) return nil;
    return [self deepestViewFrom:window point:point];
}

- (void)processInspectionEvent:(UIEvent *)event {
    if (!self.selectionModeActive || event == nil || ![event respondsToSelector:@selector(allTouches)]) return;

    UITouch *candidate = nil;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase == UITouchPhaseBegan && touch.window != self.inspectorWindow) {
            candidate = touch;
            break;
        }
    }
    if (candidate == nil) return;

    /* Resolve the selection against the real application window. The inspector
       window is above it but is interaction-disabled during selection. */
    UIWindow *window = candidate.window;
    if (window == nil || window == self.inspectorWindow) return;

    CGPoint point = [candidate locationInView:window];
    UIView *selected = [self deepestViewAtPoint:point inWindow:window];
    if (selected == nil) selected = candidate.view;
    if (selected == nil || selected.window == self.inspectorWindow) return;

    [self selectView:selected];
}

- (void)selectView:(UIView *)view {
    if (view == nil) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.selectionModeActive = NO;
        if (self.highlightedView != nil) {
            self.highlightedView.layer.borderWidth = self.previousBorderWidth;
            self.highlightedView.layer.borderColor = self.previousBorderColor.CGColor;
        }
        self.highlightedView = view;
        self.previousBorderWidth = view.layer.borderWidth;
        self.previousBorderColor = view.layer.borderColor ? [UIColor colorWithCGColor:view.layer.borderColor] : nil;
        view.layer.borderWidth = 2.0;
        view.layer.borderColor = [UIColor systemBlueColor].CGColor;
        self.inspectorWindow.userInteractionEnabled = YES;
        [self.inspectorViewController showSelectedView:view];
    });
}

- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.highlightedView != nil) {
            self.highlightedView.layer.borderWidth = self.previousBorderWidth;
            self.highlightedView.layer.borderColor = self.previousBorderColor.CGColor;
        }
        self.selectionModeActive = NO;
        self.inspectorWindow.hidden = YES;
        self.inspectorWindow = nil;
        self.inspectorViewController = nil;
        self.highlightedView = nil;
        self.previousBorderColor = nil;
        self.previousBorderWidth = 0.0;
    });
}
@end
