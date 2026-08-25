#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

#pragma mark - V13 state

static NSMutableArray<NSDictionary *> *PHV13Pending = nil;

static NSString *PHV13FilterPath(void) {
    static NSString *cachedPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *relative = nil;
        while ((relative = [e nextObject])) {
            if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                cachedPath = [home stringByAppendingPathComponent:relative];
                break;
            }
        }
        if (!cachedPath.length) cachedPath = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachedPath]) {
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *relative = nil;
        while ((relative = [e nextObject])) {
            if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                cachedPath = [home stringByAppendingPathComponent:relative];
                break;
            }
        }
    }
    return cachedPath;
}

static NSArray *PHV13LoadFilters(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHV13FilterPath()];
    if (!data) return @[];
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    return [json isKindOfClass:NSArray.class] ? json : @[];
}

static NSDictionary *PHV13NormalizedFilter(NSDictionary *filter) {
    if (![filter isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *action = filter[@"action"];
    NSDictionary *trigger = filter[@"trigger"];
    NSString *selector = [action isKindOfClass:NSDictionary.class] ? action[@"selector"] : nil;
    if (![selector isKindOfClass:NSString.class] || !selector.length) selector = filter[@"selector"];
    if (![selector isKindOfClass:NSString.class] || !selector.length) return nil;

    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"trigger"] = ([trigger isKindOfClass:NSDictionary.class] && trigger[@"url-filter"]) ? trigger : @{ @"url-filter": @".*" };
    out[@"action"] = @{
        @"type": ([action isKindOfClass:NSDictionary.class] && [action[@"type"] isKindOfClass:NSString.class]) ? action[@"type"] : @"css-display-none",
        @"selector": selector
    };
    return out;
}

static NSMutableArray *PHV13NormalizedFilters(void) {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *filter in PHV13LoadFilters()) {
        NSDictionary *normalized = PHV13NormalizedFilter(filter);
        if (normalized) [result addObject:normalized];
    }
    return result;
}

static BOOL PHV13WriteFilters(NSArray *filters) {
    NSString *path = PHV13FilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:filters ?: @[] options:NSJSONWritingPrettyPrinted error:nil];
    return data && [data writeToFile:path atomically:YES];
}

static NSString *PHV13SelectorLabel(NSString *selector) {
    if (!selector.length) return @"Elemento";
    NSString *s = [selector stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([s hasPrefix:@"#"]) {
        NSString *value = [s substringFromIndex:1];
        NSRange end = [value rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" .>#"]];
        if (end.location != NSNotFound) value = [value substringToIndex:end.location];
        return [NSString stringWithFormat:@"ID: %@", value];
    }
    NSArray *parts = [s componentsSeparatedByString:@" > "];
    NSString *last = parts.lastObject ?: s;
    NSRange pseudo = [last rangeOfString:@":nth-of-type("];
    if (pseudo.location != NSNotFound) last = [last substringToIndex:pseudo.location];
    if (last.length) {
        if ([last hasPrefix:@"."]) return [NSString stringWithFormat:@"Classe: %@", [last substringFromIndex:1]];
        NSRange dot = [last rangeOfString:@"."];
        if (dot.location != NSNotFound) last = [last substringToIndex:dot.location];
        return [NSString stringWithFormat:@"Elemento: %@", last];
    }
    return s.length > 70 ? [[s substringToIndex:70] stringByAppendingString:@"…"] : s;
}

static void PHV13HideSelector(WKWebView *webView, NSString *selector) {
    if (!webView || !selector.length) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[selector] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';})}catch(e){}});", json];
    [webView evaluateJavaScript:script completionHandler:nil];
}

static void PHV13RestoreSelector(WKWebView *webView, NSString *selector) {
    if (!webView || !selector.length) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[selector] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display');})}catch(e){}});", json];
    [webView evaluateJavaScript:script completionHandler:nil];
}

static void PHV13ApplyFiltersToWebView(WKWebView *webView) {
    if (!webView) return;
    NSMutableArray *selectors = [NSMutableArray array];
    for (NSDictionary *filter in PHV13NormalizedFilters()) {
        NSString *selector = filter[@"action"][@"selector"];
        if (selector.length) [selectors addObject:selector];
    }
    if (!selectors.count) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:selectors options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){if(e.getAttribute('data-projetoh-hidden')!=='1'){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';}})}catch(e){}});", json];
    [webView evaluateJavaScript:script completionHandler:nil];
}

static id PHV13Manager(void) {
    Class c = NSClassFromString(@"PHOverlayManager");
    return c && [c respondsToSelector:@selector(sharedManager)] ? [c performSelector:@selector(sharedManager)] : nil;
}

static UIViewController *PHV13Inspector(void) {
    id manager = PHV13Manager();
    return [manager valueForKey:@"inspectorViewController"];
}

#pragma mark - Clean GUI

static UIButton *PHV13Button(NSString *title, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.72;
    button.titleLabel.numberOfLines = 1;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static void PHV13Render(id self, SEL cmd, BOOL hierarchyMode) {
    (void)cmd;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

        UIView *panel = [UIView new];
        panel.translatesAutoresizingMaskIntoConstraints = NO;
        panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.97];
        panel.layer.cornerRadius = 20.0;
        panel.layer.masksToBounds = YES;
        [self.view addSubview:panel];

        NSString *details = [self valueForKey:@"currentDetails"] ?: @"";
        NSString *subtitleText = hierarchyMode ? @"Hierarquia DOM" : ([self valueForKey:@"currentSubtitle"] ?: @"Elemento Web selecionado");

        UILabel *title = [UILabel new];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        title.text = @"ProjetoH Inspector";
        title.font = [UIFont boldSystemFontOfSize:21.0];
        title.textColor = UIColor.whiteColor;

        UILabel *subtitle = [UILabel new];
        subtitle.translatesAutoresizingMaskIntoConstraints = NO;
        subtitle.text = subtitleText;
        subtitle.font = [UIFont systemFontOfSize:14.0];
        subtitle.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];

        UIScrollView *scroll = [UIScrollView new];
        scroll.translatesAutoresizingMaskIntoConstraints = NO;
        scroll.backgroundColor = [UIColor colorWithWhite:0.055 alpha:1.0];
        scroll.layer.cornerRadius = 12.0;
        scroll.alwaysBounceVertical = YES;

        UILabel *content = [UILabel new];
        content.translatesAutoresizingMaskIntoConstraints = NO;
        content.text = details;
        content.font = [UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular];
        content.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];
        content.numberOfLines = 0;
        [scroll addSubview:content];

        UIButton *hierarchy = PHV13Button(hierarchyMode ? @"Voltar" : @"Hierarquia", self, hierarchyMode ? @selector(backTapped) : @selector(hierarchyTapped));
        UIButton *copy = PHV13Button(@"Copiar", self, @selector(copyTapped));
        UIButton *close = PHV13Button(@"Fechar", self, @selector(closeTapped));
        UIButton *hide = PHV13Button(@"Ocultar", self, @selector(hideTapped));
        UIButton *hidden = PHV13Button(@"Ocultos", self, @selector(hiddenTapped));
        UIButton *save = PHV13Button(@"Salvar", self, @selector(saveTapped));
        save.enabled = PHV13Pending.count > 0;

        UIStackView *row1 = [[UIStackView alloc] initWithArrangedSubviews:@[hierarchy, copy, close]];
        row1.translatesAutoresizingMaskIntoConstraints = NO;
        row1.axis = UILayoutConstraintAxisHorizontal;
        row1.alignment = UIStackViewAlignmentCenter;
        row1.distribution = UIStackViewDistributionFillEqually;
        row1.spacing = 8.0;

        UIStackView *row2 = [[UIStackView alloc] initWithArrangedSubviews:@[hide, hidden, save]];
        row2.translatesAutoresizingMaskIntoConstraints = NO;
        row2.axis = UILayoutConstraintAxisHorizontal;
        row2.alignment = UIStackViewAlignmentCenter;
        row2.distribution = UIStackViewDistributionFillEqually;
        row2.spacing = 8.0;

        [panel addSubview:title];
        [panel addSubview:subtitle];
        [panel addSubview:scroll];
        [panel addSubview:row1];
        [panel addSubview:row2];

        [NSLayoutConstraint activateConstraints:@[
            [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
            [panel.widthAnchor constraintEqualToConstant:360.0],
            [panel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-24.0],
            [panel.heightAnchor constraintEqualToConstant:520.0],

            [title.topAnchor constraintEqualToAnchor:panel.topAnchor constant:22.0],
            [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
            [title.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],

            [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5.0],
            [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

            [scroll.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:16.0],
            [scroll.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [scroll.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [scroll.bottomAnchor constraintEqualToAnchor:row1.topAnchor constant:-12.0],

            [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16.0],
            [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16.0],
            [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16.0],
            [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16.0],
            [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32.0],

            [row1.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [row1.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [row1.bottomAnchor constraintEqualToAnchor:row2.topAnchor constant:-10.0],
            [row1.heightAnchor constraintEqualToConstant:38.0],

            [row2.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [row2.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [row2.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0],
            [row2.heightAnchor constraintEqualToConstant:38.0]
        ]];
    });
}

#pragma mark - Hide without saving

static void PHV13HideSelectedElement(id self, SEL cmd) {
    (void)cmd;
    WKWebView *webView = [self valueForKey:@"highlightedWebView"];
    if (!webView) return;

    NSString *script = @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}var label=(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,80);if(!label&&e.id)label='#'+e.id;if(!label)label=e.tagName.toLowerCase();return JSON.stringify({selector:p(e),label:label,tag:e.tagName.toLowerCase(),id:e.id||'',className:typeof e.className==='string'?e.className:'',text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,80)});})()";
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) return;
        NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *info = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *selector = info[@"selector"];
        if (!selector.length) return;

        BOOL exists = NO;
        for (NSDictionary *item in PHV13Pending) if ([item[@"selector"] isEqualToString:selector]) { exists = YES; break; }
        if (!exists) {
            NSString *label = [info[@"label"] isKindOfClass:NSString.class] ? info[@"label"] : PHV13SelectorLabel(selector);
            [PHV13Pending addObject:@{ @"selector": selector, @"label": label.length ? label : PHV13SelectorLabel(selector) }];
        }
        PHV13HideSelector(webView, selector);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *vc = PHV13Inspector();
            if (vc) {
                BOOL hierarchy = [[vc valueForKey:@"showingHierarchy"] boolValue];
                [vc performSelector:@selector(render:) withObject:@(hierarchy)];
            }
        });
    }];
}

#pragma mark - Save with confirmation

static void PHV13SavePendingFilters(id self, SEL cmd) {
    (void)cmd;
    if (!PHV13Pending.count) return;
    UIViewController *vc = PHV13Inspector();
    if (!vc) return;

    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Salvar alterações?" message:[NSString stringWithFormat:@"%lu elemento(s) serão gravados no custom-filters.json.", (unsigned long)PHV13Pending.count] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Salvar" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSMutableArray *filters = PHV13NormalizedFilters();
        for (NSDictionary *pending in [PHV13Pending copy]) {
            NSString *selector = pending[@"selector"];
            if (!selector.length) continue;
            BOOL exists = NO;
            for (NSDictionary *filter in filters) {
                if ([filter[@"action"][@"selector"] isEqualToString:selector]) { exists = YES; break; }
            }
            if (!exists) {
                [filters addObject:@{
                    @"trigger": @{ @"url-filter": @".*" },
                    @"action": @{ @"type": @"css-display-none", @"selector": selector }
                }];
            }
        }
        if (PHV13WriteFilters(filters)) {
            [PHV13Pending removeAllObjects];
            WKWebView *webView = [self valueForKey:@"highlightedWebView"];
            PHV13ApplyFiltersToWebView(webView);
            UIViewController *inspector = PHV13Inspector();
            if (inspector) {
                BOOL hierarchy = [[inspector valueForKey:@"showingHierarchy"] boolValue];
                [inspector performSelector:@selector(render:) withObject:@(hierarchy)];
            }
        }
    }]];
    [vc presentViewController:confirm animated:YES completion:nil];
}

#pragma mark - Hidden elements manager

static void PHV13ShowHiddenElements(id self, SEL cmd) {
    (void)cmd;
    UIViewController *vc = PHV13Inspector();
    if (!vc) return;
    NSArray *saved = PHV13NormalizedFilters();
    WKWebView *webView = [self valueForKey:@"highlightedWebView"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu salvo(s) • %lu pendente(s)", (unsigned long)saved.count, (unsigned long)PHV13Pending.count] preferredStyle:UIAlertControllerStyleAlert];

    for (NSDictionary *pending in [PHV13Pending copy]) {
        NSString *selector = pending[@"selector"] ?: @"";
        NSString *label = pending[@"label"] ?: PHV13SelectorLabel(selector);
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Desfazer: %@", label] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            PHV13RestoreSelector(webView, selector);
            [PHV13Pending removeObject:pending];
            UIViewController *inspector = PHV13Inspector();
            if (inspector) {
                BOOL hierarchy = [[inspector valueForKey:@"showingHierarchy"] boolValue];
                [inspector performSelector:@selector(render:) withObject:@(hierarchy)];
            }
        }]];
    }

    for (NSDictionary *filter in saved) {
        NSString *selector = filter[@"action"][@"selector"] ?: @"";
        NSString *label = PHV13SelectorLabel(selector);
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@", label] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSMutableArray *cur = PHV13NormalizedFilters();
            NSIndexSet *indexes = [cur indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
                return [item[@"action"][@"selector"] isEqualToString:selector];
            }];
            [cur removeObjectsAtIndexes:indexes];
            PHV13WriteFilters(cur);
            PHV13RestoreSelector(webView, selector);
            UIViewController *inspector = PHV13Inspector();
            if (inspector) {
                BOOL hierarchy = [[inspector valueForKey:@"showingHierarchy"] boolValue];
                [inspector performSelector:@selector(render:) withObject:@(hierarchy)];
            }
        }]];
    }

    if (saved.count) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Reativar todos os salvos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            for (NSDictionary *filter in PHV13NormalizedFilters()) PHV13RestoreSelector(webView, filter[@"action"][@"selector"]);
            PHV13WriteFilters(@[]);
            UIViewController *inspector = PHV13Inspector();
            if (inspector) {
                BOOL hierarchy = [[inspector valueForKey:@"showingHierarchy"] boolValue];
                [inspector performSelector:@selector(render:) withObject:@(hierarchy)];
            }
        }]];
    }

    if (!saved.count && !PHV13Pending.count) {
        alert.message = @"Nenhum elemento oculto.";
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Apply saved WebFrame filters

static void PHV13ApplyKnownWebViews(id self, SEL cmd) {
    (void)self; (void)cmd;
    if (!PHV13NormalizedFilters().count) return;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha <= 0) continue;
            NSMutableArray *stack = [NSMutableArray arrayWithObject:window];
            while (stack.count) {
                UIView *view = stack.lastObject;
                [stack removeLastObject];
                if ([view isKindOfClass:WKWebView.class]) PHV13ApplyFiltersToWebView((WKWebView *)view);
                [stack addObjectsFromArray:view.subviews];
            }
        }
    }
}

#pragma mark - Installation

static void PHV13Swizzle(Class cls, SEL original, IMP replacement) {
    Method method = class_getInstanceMethod(cls, original);
    if (method) method_setImplementation(method, replacement);
}

__attribute__((constructor)) static void PHV13Init(void) {
    PHV13Pending = [NSMutableArray array];
    dispatch_async(dispatch_get_main_queue(), ^{
        Class inspector = NSClassFromString(@"PHInspectorViewController");
        Class manager = NSClassFromString(@"PHOverlayManager");
        if (inspector) {
            PHV13Swizzle(inspector, @selector(render:), (IMP)PHV13Render);
        }
        if (manager) {
            PHV13Swizzle(manager, @selector(hideSelectedElement), (IMP)PHV13HideSelectedElement);
            PHV13Swizzle(manager, @selector(savePendingFilters), (IMP)PHV13SavePendingFilters);
            PHV13Swizzle(manager, @selector(showHiddenElements), (IMP)PHV13ShowHiddenElements);
            PHV13Swizzle(manager, @selector(applyKnownWebViews), (IMP)PHV13ApplyKnownWebViews);
        }
    });
}
