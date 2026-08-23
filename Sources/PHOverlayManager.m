#import "PHOverlayManager.h"

@interface PHOverlayWindow : UIWindow
@end

@implementation PHOverlayWindow
@end

@interface PHInspectorViewController : UIViewController
@end

@implementation PHInspectorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;

    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.97];
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
    placeholder.text = @"Nenhum elemento selecionado\n\nA seleção e a hierarquia serão adicionadas\nna próxima etapa.";
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
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PHOverlayCloseRequested" object:nil];
}

@end

@interface PHOverlayManager ()
@property (nonatomic, strong, nullable) PHOverlayWindow *window;
@property (nonatomic, strong, nullable) id closeObserver;
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

- (void)presentInspectorIfNeeded {
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
        window.rootViewController = [PHInspectorViewController new];

        self.closeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"PHOverlayCloseRequested"
                                                                                  object:nil
                                                                                   queue:[NSOperationQueue mainQueue]
                                                                              usingBlock:^(__unused NSNotification *note) {
            [self dismissOverlay];
        }];

        self.window = window;
        [window makeKeyAndVisible];
    });
}

- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.closeObserver != nil) {
            [[NSNotificationCenter defaultCenter] removeObserver:self.closeObserver];
            self.closeObserver = nil;
        }
        [self.window resignKeyWindow];
        self.window.hidden = YES;
        self.window.rootViewController = nil;
        self.window = nil;
    });
}

@end
