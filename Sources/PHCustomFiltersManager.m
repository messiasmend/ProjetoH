#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
@end

@interface PHCustomFiltersTarget : NSObject
+ (instancetype)sharedTarget;
- (void)hide:(id)s;
- (void)manage:(id)s;
@end

static char K1, K2;

static NSString *PHPath(void) {
    NSString *home = NSHomeDirectory();
    NSString *documentsPath = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:documentsPath]) {
        return documentsPath;
    }

    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:home];
    NSString *relativePath = nil;
    while ((relativePath = [enumerator nextObject])) {
        if ([relativePath.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
            return [home stringByAppendingPathComponent:relativePath];
        }
    }

    return documentsPath;
}

static id PHM(void) {
    Class c = NSClassFromString(@"PHOverlayManager");
    return [c respondsToSelector:@selector(sharedManager)] ? [c performSelector:@selector(sharedManager)] : nil;
}

static WKWebView *PHW(void) {
    id manager = PHM();
    return [manager valueForKey:@"highlightedWebView"];
}

static UIViewController *PHI(void) {
    id manager = PHM();
    return [manager valueForKey:@"inspectorViewController"];
}

/*
 * WebFrame custom-filters.json uses the native WebKit Content Blocker
 * representation: an array of { trigger, action } rule dictionaries.
 *
 * V9.9 wrote a private { version, filters } wrapper and selector-only
 * objects. V11 reads both formats for migration, but ALWAYS writes the
 * native array format back to disk.
 */
static NSDictionary *PHNativeHideRule(NSString *selector) {
    return @{
        @"trigger": @{@"url-filter": @".*"},
        @"action": @{
            @"type": @"css-display-none",
            @"selector": selector
        }
    };
}

static NSString *PHSelectorFromRule(NSDictionary *rule) {
    if (![rule isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    NSDictionary *action = rule[@"action"];
    if ([action isKindOfClass:NSDictionary.class]) {
        NSString *selector = action[@"selector"];
        NSString *type = action[@"type"];
        if ([selector isKindOfClass:NSString.class] &&
            selector.length > 0 &&
            (!type || [type isEqualToString:@"css-display-none"])) {
            return selector;
        }
    }

    NSString *legacySelector = rule[@"selector"];
    if ([legacySelector isKindOfClass:NSString.class] && legacySelector.length > 0) {
        return legacySelector;
    }

    return nil;
}

static BOOL PHIsNativeRule(NSDictionary *rule) {
    if (![rule isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSDictionary *action = rule[@"action"];
    NSDictionary *trigger = rule[@"trigger"];

    if (![action isKindOfClass:NSDictionary.class] ||
        ![trigger isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSString *type = action[@"type"];
    NSString *urlFilter = trigger[@"url-filter"];

    return [type isKindOfClass:NSString.class] &&
           [urlFilter isKindOfClass:NSString.class] &&
           type.length > 0 &&
           urlFilter.length > 0;
}

static NSMutableArray *PHNormalizeRules(id root) {
    id candidate = root;

    /* Legacy V9 format: { "version": 1, "filters": [ ... ] } */
    if ([candidate isKindOfClass:NSDictionary.class]) {
        id filters = candidate[@"filters"];
        if ([filters isKindOfClass:NSArray.class]) {
            candidate = filters;
        } else {
            return [NSMutableArray array];
        }
    }

    if (![candidate isKindOfClass:NSArray.class]) {
        return [NSMutableArray array];
    }

    NSMutableArray *rules = [NSMutableArray array];

    for (id item in (NSArray *)candidate) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSDictionary *rule = (NSDictionary *)item;

        if (PHIsNativeRule(rule)) {
            [rules addObject:rule];
            continue;
        }

        /* Migrate V9 selector-only entries without dropping them. */
        NSString *selector = PHSelectorFromRule(rule);
        if (selector.length > 0) {
            [rules addObject:PHNativeHideRule(selector)];
        }
    }

    return rules;
}

static NSMutableArray *PHLoad(void) {
    NSString *path = PHPath();
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data.length) {
        return [NSMutableArray array];
    }

    NSError *jsonError = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data
                                               options:NSJSONReadingMutableContainers
                                                 error:&jsonError];

    if (jsonError || !root) {
        return [NSMutableArray array];
    }

    return PHNormalizeRules(root);
}

static BOOL PHSave(NSArray *rules) {
    NSString *path = PHPath();
    NSString *directory = path.stringByDeletingLastPathComponent;

    NSError *directoryError = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&directoryError];
    if (directoryError) {
        return NO;
    }

    NSMutableArray *nativeRules = [NSMutableArray array];
    for (id item in rules) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSDictionary *rule = (NSDictionary *)item;
        if (PHIsNativeRule(rule)) {
            [nativeRules addObject:rule];
            continue;
        }

        NSString *selector = PHSelectorFromRule(rule);
        if (selector.length > 0) {
            [nativeRules addObject:PHNativeHideRule(selector)];
        }
    }

    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:nativeRules
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&jsonError];
    if (jsonError || !data) {
        return NO;
    }

    NSError *writeError = nil;
    BOOL ok = [data writeToFile:path options:NSDataWritingAtomic error:&writeError];
    return ok && !writeError;
}

static NSString *PHSelected(void) {
    return @"(function(){"
           "var e=document.querySelector('[data-projetoh-selected=\"1\"]');"
           "if(!e)return '{}';"
           "function p(n){"
               "if(n.id)return '#'+CSS.escape(n.id);"
               "var a=[];"
               "while(n&&n.nodeType===1&&n!==document.body){"
                   "var q=n.parentElement;"
                   "if(!q)break;"
                   "var s=[...q.children].filter(x=>x.tagName===n.tagName);"
                   "a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(s.indexOf(n)+1)+')');"
                   "n=q;"
               "}"
               "return a.join(' > ');"
           "}"
           "return JSON.stringify({selector:p(e)});"
           "})()";
}

static void PHApply(void) {
    WKWebView *webView = PHW();
    if (!webView) {
        return;
    }

    NSMutableArray *selectors = [NSMutableArray array];

    for (NSDictionary *rule in PHLoad()) {
        NSDictionary *action = rule[@"action"];
        if (![action isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSString *type = action[@"type"];
        NSString *selector = action[@"selector"];

        if ([type isEqualToString:@"css-display-none"] &&
            [selector isKindOfClass:NSString.class] &&
            selector.length > 0) {
            [selectors addObject:selector];
        }
    }

    NSError *jsonError = nil;
    NSData *selectorData = [NSJSONSerialization dataWithJSONObject:selectors
                                                             options:0
                                                               error:&jsonError];
    if (jsonError || !selectorData) {
        return;
    }

    NSString *selectorJSON = [[NSString alloc] initWithData:selectorData
                                                    encoding:NSUTF8StringEncoding];
    if (!selectorJSON.length) {
        return;
    }

    NSString *javascript = [NSString stringWithFormat:
        @"(function(){"
            "document.querySelectorAll('[data-projetoh-hidden=\"1\"]').forEach(function(e){"
                "e.style.display=e.getAttribute('data-projetoh-prev-display')||'';"
                "e.removeAttribute('data-projetoh-hidden');"
                "e.removeAttribute('data-projetoh-prev-display');"
            "});"
            "(%@).forEach(function(s){"
                "try{"
                    "document.querySelectorAll(s).forEach(function(e){"
                        "e.setAttribute('data-projetoh-hidden','1');"
                        "e.setAttribute('data-projetoh-prev-display',e.style.display||'');"
                        "e.style.display='none';"
                    "});"
                "}catch(x){}"
            "});"
        "})()", selectorJSON];

    [webView evaluateJavaScript:javascript completionHandler:nil];
}

static void PHRestore(NSString *selector) {
    WKWebView *webView = PHW();
    if (!webView || !selector.length) {
        return;
    }

    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[selector]
                                                    options:0
                                                      error:&jsonError];
    if (jsonError || !data) {
        return;
    }

    NSString *selectorJSON = [[NSString alloc] initWithData:data
                                                    encoding:NSUTF8StringEncoding];
    if (!selectorJSON.length) {
        return;
    }

    NSString *javascript = [NSString stringWithFormat:
        @"(%@).forEach(function(s){"
            "try{"
                "document.querySelectorAll(s).forEach(function(e){"
                    "e.style.display=e.getAttribute('data-projetoh-prev-display')||'';"
                    "e.removeAttribute('data-projetoh-hidden');"
                    "e.removeAttribute('data-projetoh-prev-display');"
                "});"
            "}catch(x){}"
        "})", selectorJSON];

    [webView evaluateJavaScript:javascript completionHandler:nil];
}

static void PHHide(void) {
    WKWebView *webView = PHW();
    if (!webView) {
        return;
    }

    [webView evaluateJavaScript:PHSelected() completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) {
            return;
        }

        NSData *resultData = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *selected = [NSJSONSerialization JSONObjectWithData:resultData
                                                                   options:0
                                                                     error:nil];
        NSString *selector = selected[@"selector"];
        if (![selector isKindOfClass:NSString.class] || !selector.length) {
            return;
        }

        NSMutableArray *rules = PHLoad();
        BOOL alreadyExists = NO;

        for (NSDictionary *rule in rules) {
            NSString *existingSelector = PHSelectorFromRule(rule);
            NSDictionary *action = rule[@"action"];
            NSString *type = [action isKindOfClass:NSDictionary.class] ? action[@"type"] : nil;

            if ([existingSelector isEqualToString:selector] &&
                (!type || [type isEqualToString:@"css-display-none"])) {
                alreadyExists = YES;
                break;
            }
        }

        if (!alreadyExists) {
            [rules addObject:PHNativeHideRule(selector)];
            if (!PHSave(rules)) {
                return;
            }
        }

        PHApply();
    }];
}

static NSString *PHFriendlyName(NSDictionary *rule) {
    NSString *selector = PHSelectorFromRule(rule);

    if (!selector.length) {
        return @"Elemento oculto";
    }

    if ([selector isEqualToString:@"[id=header]"] ||
        [selector isEqualToString:@"#header"]) {
        return @"Cabeçalho";
    }

    if ([selector isEqualToString:@".q-page-sticky"]) {
        return @"Elementos fixos";
    }

    NSArray *parts = [selector componentsSeparatedByString:@">"];
    NSString *last = [parts.lastObject stringByTrimmingCharactersInSet:
                      NSCharacterSet.whitespaceAndNewlineCharacterSet];

    NSRange pseudo = [last rangeOfString:@":"];
    if (pseudo.location != NSNotFound) {
        last = [last substringToIndex:pseudo.location];
    }

    NSRange idRange = [last rangeOfString:@"#"];
    if (idRange.location != NSNotFound && idRange.location + 1 < last.length) {
        return [NSString stringWithFormat:@"Elemento #%@",
                [last substringFromIndex:idRange.location + 1]];
    }

    NSRange classRange = [last rangeOfString:@"."];
    if (classRange.location != NSNotFound && classRange.location + 1 < last.length) {
        return [NSString stringWithFormat:@"Elemento .%@",
                [last substringFromIndex:classRange.location + 1]];
    }

    if ([last caseInsensitiveCompare:@"img"] == NSOrderedSame) {
        return @"Imagem";
    }

    if ([last caseInsensitiveCompare:@"lottie-player"] == NSOrderedSame) {
        return @"Lottie Player";
    }

    if (last.length == 2 &&
        [last.lowercaseString hasPrefix:@"h"] &&
        [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[last characterAtIndex:1]]) {
        return [NSString stringWithFormat:@"Título (%@)", [last uppercaseString]];
    }

    if ([last caseInsensitiveCompare:@"p"] == NSOrderedSame) {
        return @"Texto";
    }

    if ([last caseInsensitiveCompare:@"main"] == NSOrderedSame) {
        return @"Conteúdo principal";
    }

    if ([last caseInsensitiveCompare:@"section"] == NSOrderedSame) {
        return @"Seção";
    }

    if ([last caseInsensitiveCompare:@"table"] == NSOrderedSame) {
        return @"Tabela";
    }

    if ([last caseInsensitiveCompare:@"button"] == NSOrderedSame) {
        return @"Botão";
    }

    if ([last caseInsensitiveCompare:@"center"] == NSOrderedSame) {
        return @"Área central";
    }

    if (last.length > 0 && last.length < 40) {
        return [NSString stringWithFormat:@"Elemento <%@>", last];
    }

    return @"Elemento oculto";
}

static void PHManage(void) {
    UIViewController *viewController = PHI();
    if (!viewController) {
        return;
    }

    NSArray *rules = PHLoad();
    NSMutableArray *hideRules = [NSMutableArray array];

    for (NSDictionary *rule in rules) {
        NSDictionary *action = rule[@"action"];
        if (![action isKindOfClass:NSDictionary.class]) {
            continue;
        }

        if ([action[@"type"] isEqualToString:@"css-display-none"] &&
            [action[@"selector"] isKindOfClass:NSString.class] &&
            [action[@"selector"] length] > 0) {
            [hideRules addObject:rule];
        }
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Elementos ocultos"
                                            message:[NSString stringWithFormat:
                                                      @"%lu item(ns) em custom-filters.json",
                                                      (unsigned long)hideRules.count]
                                     preferredStyle:UIAlertControllerStyleAlert];

    for (NSDictionary *rule in hideRules) {
        NSString *selector = rule[@"action"][ @"selector"];
        NSString *name = PHFriendlyName(rule);

        [alert addAction:
            [UIAlertAction actionWithTitle:
                [NSString stringWithFormat:@"Reativar: %@", name]
                                    style:UIAlertActionStyleDefault
                                  handler:^(__unused UIAlertAction *button) {
            NSMutableArray *currentRules = PHLoad();
            NSMutableArray *remaining = [NSMutableArray array];

            for (NSDictionary *currentRule in currentRules) {
                NSString *currentSelector = PHSelectorFromRule(currentRule);
                NSDictionary *currentAction = currentRule[@"action"];
                NSString *currentType =
                    [currentAction isKindOfClass:NSDictionary.class] ?
                    currentAction[@"type"] : nil;

                BOOL sameHideRule =
                    [currentSelector isEqualToString:selector] &&
                    (!currentType || [currentType isEqualToString:@"css-display-none"]);

                if (!sameHideRule) {
                    [remaining addObject:currentRule];
                }
            }

            if (PHSave(remaining)) {
                PHRestore(selector);
            }
        }]];
    }

    if (hideRules.count) {
        [alert addAction:
            [UIAlertAction actionWithTitle:@"Reativar todos"
                                      style:UIAlertActionStyleDestructive
                                    handler:^(__unused UIAlertAction *button) {
            NSMutableArray *currentRules = PHLoad();

            for (NSDictionary *rule in currentRules) {
                NSDictionary *action = rule[@"action"];
                if ([action isKindOfClass:NSDictionary.class] &&
                    [action[@"type"] isEqualToString:@"css-display-none"]) {
                    NSString *selector = action[@"selector"];
                    if ([selector isKindOfClass:NSString.class] && selector.length) {
                        PHRestore(selector);
                    }
                }
            }

            NSMutableArray *remaining = [NSMutableArray array];
            for (NSDictionary *rule in currentRules) {
                NSDictionary *action = rule[@"action"];
                BOOL isHideRule =
                    [action isKindOfClass:NSDictionary.class] &&
                    [action[@"type"] isEqualToString:@"css-display-none"];

                if (!isHideRule) {
                    [remaining addObject:rule];
                }
            }

            PHSave(remaining);
        }]];
    }

    [alert addAction:
        [UIAlertAction actionWithTitle:@"Fechar"
                                  style:UIAlertActionStyleCancel
                                handler:nil]];

    [viewController presentViewController:alert animated:YES completion:nil];
}

@implementation PHCustomFiltersTarget

+ (instancetype)sharedTarget {
    static id target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [self new];
    });
    return target;
}

- (void)hide:(id)sender {
    PHHide();
}

- (void)manage:(id)sender {
    PHManage();
}

@end

static void PHAdd(void) {
    UIViewController *viewController = PHI();
    if (!viewController) {
        return;
    }

    UIButton *oldHide = objc_getAssociatedObject(viewController, &K1);
    if (oldHide) {
        [oldHide removeFromSuperview];
    }

    UIButton *oldManage = objc_getAssociatedObject(viewController, &K2);
    if (oldManage) {
        [oldManage removeFromSuperview];
    }

    [viewController.view layoutIfNeeded];

    UIView *panel = nil;
    for (UIView *subview in viewController.view.subviews.reverseObjectEnumerator) {
        if (subview != viewController.view &&
            fabs(subview.bounds.size.width - 350.0) < 2.0 &&
            fabs(subview.bounds.size.height - 430.0) < 2.0) {
            panel = subview;
            break;
        }
    }

    UIView *host = panel ?: viewController.view;
    CGRect bounds = host.bounds;

    UIButton *hideButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButton *manageButton = [UIButton buttonWithType:UIButtonTypeSystem];

    hideButton.frame = CGRectMake(MAX(18.0, bounds.size.width - 192.0),
                                  bounds.size.height - 54.0,
                                  82.0,
                                  30.0);

    manageButton.frame = CGRectMake(MAX(108.0, bounds.size.width - 100.0),
                                    bounds.size.height - 54.0,
                                    82.0,
                                    30.0);

    hideButton.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleTopMargin;

    manageButton.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleTopMargin;

    [hideButton setTitle:@"Ocultar" forState:UIControlStateNormal];
    hideButton.titleLabel.font =
        [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];

    [manageButton setTitle:@"Ocultos" forState:UIControlStateNormal];
    manageButton.titleLabel.font =
        [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];

    [hideButton addTarget:PHCustomFiltersTarget.sharedTarget
                    action:@selector(hide:)
          forControlEvents:UIControlEventTouchUpInside];

    [manageButton addTarget:PHCustomFiltersTarget.sharedTarget
                      action:@selector(manage:)
            forControlEvents:UIControlEventTouchUpInside];

    [host addSubview:hideButton];
    [host addSubview:manageButton];

    objc_setAssociatedObject(viewController, &K1, hideButton,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(viewController, &K2, manageButton,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void (*Orig)(id, SEL, NSString *);

static void Hook(id self, SEL cmd, NSString *data) {
    if (Orig) {
        Orig(self, cmd, data);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        PHAdd();
    });
}

__attribute__((constructor))
static void Init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c = NSClassFromString(@"PHInspectorViewController");
        Method method = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        if (!method) {
            return;
        }

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Orig = (void (*)(id, SEL, NSString *))method_getImplementation(method);
            method_setImplementation(method, (IMP)Hook);
        });
    });
}
