#import "PHOverlayManager.h"

@interface PHOverlayWindow : UIWindow
@end

@implementation PHOverlayWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [super pointInside:point withEvent:event];
}

@end

@interface PHOverlayManager ()
@property (nonatomic, strong, nullable) PHOverlayWindow *window;
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.window != nil) {
            return;
        }

        UIWindowScene *scene = nil;
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if (candidate.activationState == UISceneActivationStateForegroundActive &&
                [candidate isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)candidate;
                break;
            }
        }

        if (scene == nil) {
            return;
        }

        PHOverlayWindow *window = [[PHOverlayWindow alloc] initWithWindowScene:scene];
        window.frame = scene.coordinateSpace.bounds;
        window.windowLevel = UIWindowLevelAlert + 1.0;
        window.backgroundColor = UIColor.clearColor;

        UIViewController *controller = [UIViewController new];
        controller.view.backgroundColor = UIColor.clearColor;

        UIView *panel = [UIView new];
        panel.translatesAutoresizingMaskIntoConstraints = NO;
        panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
        panel.layer.cornerRadius = 16.0;
        panel.layer.masksToBounds = YES;

        UILabel *title = [UILabel new];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        title.text = @"ProjetoH";
        title.textColor = UIColor.whiteColor;
        title.font = [UIFont boldSystemFontOfSize:20.0];

        UILabel *status = [UILabel new];
        status.translatesAutoresizingMaskIntoConstraints = NO;
        status.text = @"3 dedos detectados — V1";
        status.textColor = UIColor.whiteColor;
        status.numberOfLines = 0;

        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        close.translatesAutoresizingMaskIntoConstraints = NO;
        [close setTitle:@"Fechar" forState:UIControlStateNormal];
        [close addTarget:self action:@selector(dismissOverlay) forControlEvents:UIControlEventTouchUpInside];

        [panel addSubview:title];
        [panel addSubview:status];
        [panel addSubview:close];
        [controller.view addSubview:panel];

        [NSLayoutConstraint activateConstraints:@[
            [panel.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
            [panel.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
            [panel.widthAnchor constraintEqualToConstant:300.0],
            [panel.heightAnchor constraintEqualToConstant:180.0],
            [title.topAnchor constraintEqualToAnchor:panel.topAnchor constant:22.0],
            [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
            [status.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14.0],
            [status.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
            [status.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0],
            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0]
        ]];

        window.rootViewController = controller;
        self.window = window;
        [window makeKeyAndVisible];
    });
}

- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.window resignKeyWindow];
        self.window.hidden = YES;
        self.window.rootViewController = nil;
        self.window = nil;
    });
}

@end
