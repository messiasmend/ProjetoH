#import "PHOverlayManager.h"

@interface PHInspectorViewController : UIViewController
@end

@implementation PHInspectorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.view.backgroundColor = UIColor.clearColor;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *backdrop = [[UIVisualEffectView alloc] initWithEffect:blur];
    backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:backdrop];

    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.98];
    panel.layer.cornerRadius = 18.0;
    panel.layer.masksToBounds = YES;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"ProjetoH Inspector";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:21.0];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Inspector de Elementos";
    subtitle.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    subtitle.font = [UIFont systemFontOfSize:14.0];

    UISegmentedControl *tabs = [[UISegmentedControl alloc] initWithItems:@[@"Elemento", @"Hierarquia"]];
    tabs.translatesAutoresizingMaskIntoConstraints = NO;
    tabs.selectedSegmentIndex = 0;

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.backgroundColor = [UIColor colorWithWhite:0.13 alpha:1.0];
    content.layer.cornerRadius = 12.0;

    UILabel *placeholder = [UILabel new];
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    placeholder.text = @"ProjetoH ativo\n\nA GUI está funcionando.\nA inspeção de UIView será adicionada\nna próxima etapa.";
    placeholder.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
    placeholder.font = [UIFont systemFontOfSize:14.0];
    placeholder.numberOfLines = 0;
    placeholder.textAlignment = NSTextAlignmentCenter;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setTitle:@"Fechar" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];

    [content addSubview:placeholder];
    [panel addSubview:title];
    [panel addSubview:subtitle];
    [panel addSubview:tabs];
    [panel addSubview:content];
    [panel addSubview:close];
    [self.view addSubview:panel];

    [NSLayoutConstraint activateConstraints:@[
        [backdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [panel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [panel.widthAnchor constraintEqualToConstant:340.0],
        [panel.heightAnchor constraintEqualToConstant:390.0],
        [title.topAnchor constraintEqualToAnchor:panel.topAnchor constant:22.0],
        [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [tabs.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:18.0],
        [tabs.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20.0],
        [tabs.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0],
        [content.topAnchor constraintEqualToAnchor:tabs.bottomAnchor constant:14.0],
        [content.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20.0],
        [content.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0],
        [content.bottomAnchor constraintEqualToAnchor:close.topAnchor constant:-14.0],
        [placeholder.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [placeholder.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [placeholder.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:15.0],
        [placeholder.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-15.0],
        [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0],
        [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0]
    ]];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface PHOverlayManager ()
@property (nonatomic, weak, nullable) UIViewController *presentingViewController;
@property (nonatomic, strong, nullable) PHInspectorViewController *inspectorViewController;
@end

@implementation PHOverlayManager

+ (instancetype)sharedManager {
    static PHOverlayManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [PHOverlayManager new];
    });
    return manager;
}

- (void)presentTestOverlayIfNeeded {
    [self presentInspectorIfNeeded];
}

- (UIViewController *)topViewControllerFrom:(UIViewController *)root {
    UIViewController *current = root;

    while (current.presentedViewController != nil && !current.presentedViewController.isBeingDismissed) {
        current = current.presentedViewController;
    }

    if ([current isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = [(UINavigationController *)current visibleViewController];
        if (visible != nil && visible != current) {
            return [self topViewControllerFrom:visible];
        }
    }

    if ([current isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = [(UITabBarController *)current selectedViewController];
        if (selected != nil && selected != current) {
            return [self topViewControllerFrom:selected];
        }
    }

    return current;
}

- (UIWindow *)activeKeyWindow {
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if (![candidate isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *scene = (UIWindowScene *)candidate;
        if (scene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }

        for (UIWindow *window in scene.windows.reverseObjectEnumerator) {
            if (window.isKeyWindow && !window.hidden && window.alpha > 0.0) {
                return window;
            }
        }

        for (UIWindow *window in scene.windows.reverseObjectEnumerator) {
            if (!window.hidden && window.alpha > 0.0 && window.rootViewController != nil) {
                return window;
            }
        }
    }

    return nil;
}

- (void)presentInspectorIfNeeded {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.inspectorViewController.presentingViewController != nil ||
            self.inspectorViewController.presentedViewController != nil) {
            return;
        }

        UIWindow *window = [self activeKeyWindow];
        UIViewController *root = window.rootViewController;
        if (root == nil) {
            return;
        }

        UIViewController *presenter = [self topViewControllerFrom:root];
        if (presenter == nil || presenter.view.window == nil || presenter.isBeingDismissed) {
            return;
        }

        PHInspectorViewController *inspector = [PHInspectorViewController new];
        self.presentingViewController = presenter;
        self.inspectorViewController = inspector;

        [presenter presentViewController:inspector animated:YES completion:nil];
    });
}

- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *inspector = self.inspectorViewController;
        if (inspector.presentingViewController != nil) {
            [inspector dismissViewControllerAnimated:YES completion:nil];
        }
        self.inspectorViewController = nil;
        self.presentingViewController = nil;
    });
}

@end
