#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSMutableArray<NSDictionary *> *PHV13Pending;

static NSString *PHV13Path(void) {
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *r;
        while ((r = [e nextObject])) {
            if ([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) { path = [home stringByAppendingPathComponent:r]; break; }
        }
        if (!path.length) path = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    return path;
}

static NSArray *PHV13Load(void) {
    NSData *d = [NSData dataWithContentsOfFile:PHV13Path()];
    if (!d) return @[];
    id j = [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil];
    if ([j isKindOfClass:NSDictionary.class]) j = j[@"filters"];
    return [j isKindOfClass:NSArray.class] ? j : @[];
}

static NSDictionary *PHV13Normalize(NSDictionary *f) {
    if (![f isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *a = f[@"action"], *t = f[@"trigger"];
    NSString *s = [a isKindOfClass:NSDictionary.class] ? a[@"selector"] : f[@"selector"];
    if (![s isKindOfClass:NSString.class] || !s.length) return nil;
    return @{ @"trigger": ([t isKindOfClass:NSDictionary.class] && t[@"url-filter"]) ? t : @{ @"url-filter": @".*" },
              @"action": @{ @"type": ([a isKindOfClass:NSDictionary.class] && [a[@"type"] isKindOfClass:NSString.class]) ? a[@"type"] : @"css-display-none", @"selector": s } };
}

static NSMutableArray *PHV13Filters(void) {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *f in PHV13Load()) { NSDictionary *n = PHV13Normalize(f); if (n) [a addObject:n]; }
    return a;
}

static BOOL PHV13Write(NSArray *filters) {
    NSString *p = PHV13Path();
    [NSFileManager.defaultManager createDirectoryAtPath:p.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *d = [NSJSONSerialization dataWithJSONObject:filters ?: @[] options:NSJSONWritingPrettyPrinted error:nil];
    return d && [d writeToFile:p atomically:YES];
}

static NSString *PHV13Name(NSString *s) {
    if (!s.length) return @"Elemento";
    NSString *x = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([x rangeOfString:@"lottie-player" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"Lottie Player";
    if ([x hasPrefix:@"#"]) {
        NSString *v = [x substringFromIndex:1];
        NSRange r = [v rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" .>#"]];
        if (r.location != NSNotFound) v = [v substringToIndex:r.location];
        return [NSString stringWithFormat:@"ID: %@", v];
    }
    NSString *last = x.componentsSeparatedByString(@" > ").lastObject ?: x;
    NSRange n = [last rangeOfString:@":nth-of-type("];
    if (n.location != NSNotFound) last = [last substringToIndex:n.location];
    NSRange dot = [last rangeOfString:@"."];
    if (dot.location != NSNotFound && dot.location > 0) last = [last substringToIndex:dot.location];
    return last.length ? [NSString stringWithFormat:@"Elemento: %@", last] : @"Elemento";
}

static NSString *PHV13JSON(id obj) {
    NSData *d = [NSJSONSerialization dataWithJSONObject:obj ?: @[] options:0 error:nil];
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"[]";
}

static void PHV13JS(WKWebView *w, NSString *selector, BOOL hide) {
    if (!w || !selector.length) return;
    NSString *j = PHV13JSON(@[selector]);
    NSString *script = hide ? [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';})}catch(e){}});", j] : [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display');})}catch(e){}});", j];
    [w evaluateJavaScript:script completionHandler:nil];
}

static void PHV13Apply(WKWebView *w) {
    if (!w) return;
    NSMutableArray *s = [NSMutableArray array];
    for (NSDictionary *f in PHV13Filters()) {
        NSString *x = f[@"action"][@"selector"];
        if (x.length) [s addObject:x];
    }
    if (!s.count) return;
    NSString *j = PHV13JSON(s);
    NSString *script = [NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';})}catch(e){}});", j];
    [w evaluateJavaScript:script completionHandler:nil];
}

static id PHV13Manager(void) {
    Class c = NSClassFromString(@"PHOverlayManager");
    return c && [c respondsToSelector:@selector(sharedManager)] ? [c performSelector:@selector(sharedManager)] : nil;
}

static UIViewController *PHV13Inspector(void) {
    return [PHV13Manager() valueForKey:@"inspectorViewController"];
}

static void PHV13RenderAgain(UIViewController *vc) {
    if (vc) ((void (*)(id,SEL,BOOL))objc_msgSend)(vc, @selector(render:), [[vc valueForKey:@"showingHierarchy"] boolValue]);
}

#pragma mark - GUI

static UIButton *PHV13Button(NSString *title, id target, SEL action) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = .75;
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void PHV13Render(UIViewController *vc, SEL cmd, BOOL hierarchy) {
    (void)cmd;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *v in vc.view.subviews.copy) [v removeFromSuperview];

        UIView *p = [UIView new];
        p.translatesAutoresizingMaskIntoConstraints = NO;
        p.backgroundColor = [UIColor colorWithWhite:.08 alpha:.97];
        p.layer.cornerRadius = 20;
        p.layer.masksToBounds = YES;
        [vc.view addSubview:p];

        UILabel *title = [UILabel new];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        title.text = @"ProjetoH Inspector";
        title.font = [UIFont boldSystemFontOfSize:21];
        title.textColor = UIColor.whiteColor;

        UILabel *sub = [UILabel new];
        sub.translatesAutoresizingMaskIntoConstraints = NO;
        sub.text = hierarchy ? @"Hierarquia DOM" : ([vc valueForKey:@"currentSubtitle"] ?: @"Elemento Web selecionado");
        sub.font = [UIFont systemFontOfSize:14];
        sub.textColor = [UIColor colorWithWhite:.72 alpha:1];

        UIScrollView *scroll = [UIScrollView new];
        scroll.translatesAutoresizingMaskIntoConstraints = NO;
        scroll.backgroundColor = [UIColor colorWithWhite:.055 alpha:1];
        scroll.layer.cornerRadius = 12;
        scroll.alwaysBounceVertical = YES;

        UILabel *content = [UILabel new];
        content.translatesAutoresizingMaskIntoConstraints = NO;
        content.text = [vc valueForKey:@"currentDetails"] ?: @"";
        content.font = [UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular];
        content.textColor = [UIColor colorWithWhite:.88 alpha:1];
        content.numberOfLines = 0;
        [scroll addSubview:content];

        UIButton *hier = PHV13Button(hierarchy ? @"Voltar" : @"Hierarquia", vc, hierarchy ? @selector(backTapped) : @selector(hierarchyTapped));
        UIButton *copy = PHV13Button(@"Copiar", vc, @selector(copyTapped));
        UIButton *close = PHV13Button(@"Fechar", vc, @selector(closeTapped));

        id manager = PHV13Manager();
        UIButton *hide = PHV13Button(@"Ocultar", manager, @selector(hideSelectedElement));
        UIButton *hidden = PHV13Button(@"Ocultos", manager, @selector(showHiddenElements));
        UIButton *save = PHV13Button(@"Salvar", manager, @selector(savePendingFilters));
        save.enabled = PHV13Pending.count > 0;

        UIStackView *r1 = [[UIStackView alloc] initWithArrangedSubviews:@[hier, copy, close]];
        r1.translatesAutoresizingMaskIntoConstraints = NO;
        r1.axis = UILayoutConstraintAxisHorizontal;
        r1.distribution = UIStackViewDistributionFillEqually;
        r1.spacing = 8;

        UIStackView *r2 = [[UIStackView alloc] initWithArrangedSubviews:@[hide, hidden, save]];
        r2.translatesAutoresizingMaskIntoConstraints = NO;
        r2.axis = UILayoutConstraintAxisHorizontal;
        r2.distribution = UIStackViewDistributionFillEqually;
        r2.spacing = 8;

        [p addSubview:title];
        [p addSubview:sub];
        [p addSubview:scroll];
        [p addSubview:r1];
        [p addSubview:r2];

        [NSLayoutConstraint activateConstraints:@[
            [p.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
            [p.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
            [p.leadingAnchor constraintGreaterThanOrEqualToAnchor:vc.view.leadingAnchor constant:12],
            [p.trailingAnchor constraintLessThanOrEqualToAnchor:vc.view.trailingAnchor constant:-12],
            [p.widthAnchor constraintLessThanOrEqualToConstant:360],
            [p.heightAnchor constraintEqualToConstant:520],

            [title.topAnchor constraintEqualToAnchor:p.topAnchor constant:22],
            [title.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:22],
            [title.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-22],

            [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],
            [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [sub.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

            [scroll.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:16],
            [scroll.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
            [scroll.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
            [scroll.bottomAnchor constraintEqualToAnchor:r1.topAnchor constant:-12],

            [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
            [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
            [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
            [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
            [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],

            [r1.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
            [r1.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
            [r1.bottomAnchor constraintEqualToAnchor:r2.topAnchor constant:-10],
            [r1.heightAnchor constraintEqualToConstant:38],

            [r2.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
            [r2.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
            [r2.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-18],
            [r2.heightAnchor constraintEqualToConstant:38]
        ]];
    });
}

#pragma mark - Pending hide/save

static void PHV13Hide(id self, SEL cmd) {
    (void)cmd;
    WKWebView *w = [self valueForKey:@"highlightedWebView"];
    if (!w) return;

    NSString *script = @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}var t=(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,80);if(!t&&e.id)t='#'+e.id;if(!t)t=e.tagName.toLowerCase();return JSON.stringify({selector:p(e),label:t});})()";

    [w evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) return;
        NSData *d = [result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *i = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        NSString *s = i[@"selector"];
        if (!s.length) return;

        BOOL exists = NO;
        for (NSDictionary *x in PHV13Pending) if ([x[@"selector"] isEqualToString:s]) { exists = YES; break; }
        if (!exists) [PHV13Pending addObject:@{ @"selector":s, @"label":([i[@"label"] length] ? i[@"label"] : PHV13Name(s)) }];

        PHV13JS(w, s, YES);
        dispatch_async(dispatch_get_main_queue(), ^{ PHV13RenderAgain(PHV13Inspector()); });
    }];
}

static void PHV13Save(id self, SEL cmd) {
    (void)cmd;
    if (!PHV13Pending.count) return;
    UIViewController *vc = PHV13Inspector();
    if (!vc) return;

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Salvar alterações?" message:[NSString stringWithFormat:@"%lu elemento(s) serão gravados no custom-filters.json.",(unsigned long)PHV13Pending.count] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Salvar" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) {
        NSMutableArray *filters = PHV13Filters();
        for (NSDictionary *pending in [PHV13Pending copy]) {
            NSString *s = pending[@"selector"];
            BOOL exists = NO;
            for (NSDictionary *f in filters) if ([f[@"action"][@"selector"] isEqualToString:s]) { exists = YES; break; }
            if (!exists) [filters addObject:@{ @"trigger":@{ @"url-filter":@".*" }, @"action":@{ @"type":@"css-display-none", @"selector":s } }];
        }
        if (PHV13Write(filters)) {
            [PHV13Pending removeAllObjects];
            PHV13Apply([self valueForKey:@"highlightedWebView"]);
            PHV13RenderAgain(PHV13Inspector());
        }
    }]];
    [vc presentViewController:a animated:YES completion:nil];
}

#pragma mark - Hidden list

static void PHV13Hidden(id self, SEL cmd) {
    (void)cmd;
    UIViewController *vc = PHV13Inspector();
    if (!vc) return;
    NSArray *saved = PHV13Filters();
    WKWebView *w = [self valueForKey:@"highlightedWebView"];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu salvo(s) • %lu pendente(s)",(unsigned long)saved.count,(unsigned long)PHV13Pending.count] preferredStyle:UIAlertControllerStyleAlert];

    for (NSDictionary *p in [PHV13Pending copy]) {
        NSString *s = p[@"selector"] ?: @"";
        NSString *n = p[@"label"] ?: PHV13Name(s);
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Desfazer: %@",n] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) {
            PHV13JS(w, s, NO);
            [PHV13Pending removeObject:p];
            PHV13RenderAgain(PHV13Inspector());
        }]];
    }

    for (NSDictionary *f in saved) {
        NSString *s = f[@"action"][@"selector"] ?: @"";
        NSString *n = PHV13Name(s);
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@",n] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) {
            NSMutableArray *cur = PHV13Filters();
            NSIndexSet *idx = [cur indexesOfObjectsPassingTest:^BOOL(NSDictionary *z, NSUInteger j, BOOL *stop) {
                return [z[@"action"][@"selector"] isEqualToString:s];
            }];
            [cur removeObjectsAtIndexes:idx];
            PHV13Write(cur);
            PHV13JS(w, s, NO);
            PHV13RenderAgain(PHV13Inspector());
        }]];
    }

    if (saved.count) [a addAction:[UIAlertAction actionWithTitle:@"Reativar todos os salvos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x) {
        for (NSDictionary *f in PHV13Filters()) PHV13JS(w, f[@"action"][@"selector"], NO);
        PHV13Write(@[]);
        PHV13RenderAgain(PHV13Inspector());
    }]];

    if (!saved.count && !PHV13Pending.count) a.message = @"Nenhum elemento oculto.";
    [a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

static void PHV13ApplyAll(id self, SEL cmd) {
    (void)self; (void)cmd;
    if (!PHV13Filters().count) return;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *win in ((UIWindowScene *)scene).windows) {
            if (win.hidden || win.alpha <= 0) continue;
            NSMutableArray *stack = [NSMutableArray arrayWithObject:win];
            while (stack.count) {
                UIView *v = stack.lastObject;
                [stack removeLastObject];
                if ([v isKindOfClass:WKWebView.class]) PHV13Apply((WKWebView *)v);
                [stack addObjectsFromArray:v.subviews];
            }
        }
    }
}

static void PHV13Replace(Class c, SEL s, IMP imp) {
    Method m = class_getInstanceMethod(c, s);
    if (m) method_setImplementation(m, imp);
}

__attribute__((constructor)) static void PHV13Init(void) {
    PHV13Pending = [NSMutableArray array];
    dispatch_async(dispatch_get_main_queue(), ^{
        Class i = NSClassFromString(@"PHInspectorViewController");
        Class m = NSClassFromString(@"PHOverlayManager");
        if (i) PHV13Replace(i, @selector(render:), (IMP)PHV13Render);
        if (m) {
            PHV13Replace(m, @selector(hideSelectedElement), (IMP)PHV13Hide);
            PHV13Replace(m, @selector(savePendingFilters), (IMP)PHV13Save);
            PHV13Replace(m, @selector(showHiddenElements), (IMP)PHV13Hidden);
            PHV13Replace(m, @selector(applyKnownWebViews), (IMP)PHV13ApplyAll);
        }
    });
}
