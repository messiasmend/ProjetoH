#!/usr/bin/env python3
from pathlib import Path
import re

path = Path("Sources/PHOverlayManager.m")
s = path.read_text(encoding="utf-8")

# V9.8: make the inspector panel large enough for two complete button rows.
old = '''        [p.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[p.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[p.widthAnchor constraintEqualToConstant:360],[p.heightAnchor constraintEqualToConstant:500],'''
new = '''        [p.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[p.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[p.widthAnchor constraintEqualToConstant:360],[p.heightAnchor constraintEqualToConstant:560],'''
assert old in s, "V9.8 marker: panel size not found"
s = s.replace(old, new, 1)

# Replace the complete renderer so the original three buttons stay together and
# Ocultar/Ocultos/Salvar are always a separate second row. Salvar is only visible
# after a hide operation creates a pending change.
start = s.index('- (void)render:(BOOL)hierarchyMode {')
end = s.index('- (void)hierarchyTapped {', start)
new_render = r'''- (void)render:(BOOL)hierarchyMode {
    [self clear];
    UIView *p = [self panel]; [self.view addSubview:p];
    UILabel *title = [self label:@"ProjetoH Inspector" font:[UIFont boldSystemFontOfSize:21] color:UIColor.whiteColor];
    UILabel *subtitle = [self label:(hierarchyMode ? @"Hierarquia DOM" : self.currentSubtitle) font:[UIFont systemFontOfSize:14] color:[UIColor colorWithWhite:0.72 alpha:1]];
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.backgroundColor = [UIColor colorWithWhite:0.055 alpha:1];
    scroll.layer.cornerRadius = 12;
    scroll.alwaysBounceVertical = YES;
    UILabel *content = [self label:self.currentDetails font:[UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular] color:[UIColor colorWithWhite:0.88 alpha:1]];
    [scroll addSubview:content];

    UIButton *left = [self button:(hierarchyMode ? @"Voltar" : @"Hierarquia") action:(hierarchyMode ? @selector(backTapped) : @selector(hierarchyTapped))];
    UIButton *copy = [self button:@"Copiar" action:@selector(copyTapped)];
    UIButton *close = [self button:@"Fechar" action:@selector(closeTapped)];

    UIButton *hide = [self button:@"Ocultar" action:@selector(hideTapped)];
    UIButton *hidden = [self button:@"Ocultos" action:@selector(hiddenTapped)];
    UIButton *save = [self button:@"Salvar" action:@selector(saveTapped)];
    BOOL hasPending = PHPendingSelectors.count > 0;
    save.hidden = !hasPending;
    if (!hasPending) save.alpha = 0.35;

    for (UIView *v in @[title, subtitle, scroll, left, copy, close, hide, hidden, save]) [p addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [p.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [p.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [p.widthAnchor constraintEqualToConstant:360],
        [p.heightAnchor constraintEqualToConstant:560],

        [title.topAnchor constraintEqualToAnchor:p.topAnchor constant:22],
        [title.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:22],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],

        [scroll.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:18],
        [scroll.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
        [scroll.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
        [scroll.heightAnchor constraintEqualToConstant:370],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],

        // Row 1: the original inspector actions.
        [left.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
        [left.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-78],
        [left.widthAnchor constraintEqualToConstant:100],
        [copy.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],
        [copy.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-78],
        [copy.widthAnchor constraintEqualToConstant:100],
        [close.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
        [close.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-78],
        [close.widthAnchor constraintEqualToConstant:100],

        // Row 2: element filtering actions. Salvar appears only when needed.
        [hide.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],
        [hide.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-24],
        [hide.widthAnchor constraintEqualToConstant:100],
        [hidden.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],
        [hidden.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-24],
        [hidden.widthAnchor constraintEqualToConstant:100],
        [save.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],
        [save.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-24],
        [save.widthAnchor constraintEqualToConstant:100]
    ]];
}

'''
s = s[:start] + new_render + s[end:]

# Saving must persist the pending selectors before clearing the pending state,
# then immediately re-apply them to every currently visible WKWebView.
old = r'''- (void)savePendingFilters {
    if(!PHPendingSelectors.count) return; NSMutableArray *filters=PHLoadFilters();
    for(NSString *selector in PHPendingSelectors){ BOOL exists=NO; for(NSDictionary *f in filters) if([f[@"selector"] isEqualToString:selector]){exists=YES;break;} if(!exists)[filters addObject:@{ @"selector":selector }]; }
    if(PHWriteFilters(filters)){ [PHPendingSelectors removeAllObjects]; [self.inspectorViewController render:self.inspectorViewController.showingHierarchy]; PHApplyFilters(self.highlightedWebView); }
}'''
new = r'''- (void)savePendingFilters {
    if (!PHPendingSelectors.count) return;

    NSMutableArray *filters = PHLoadFilters();
    for (NSString *selector in PHPendingSelectors) {
        BOOL exists = NO;
        for (NSDictionary *f in filters) {
            if ([f[@"selector"] isEqualToString:selector]) { exists = YES; break; }
        }
        if (!exists) [filters addObject:@{ @"selector": selector }];
    }

    if (!PHWriteFilters(filters)) return;

    // Only now is the change committed. Before this point, Ocultar is preview-only.
    [PHPendingSelectors removeAllObjects];
    [self applyKnownWebViews];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.inspectorViewController render:self.inspectorViewController.showingHierarchy];
    });
}'''
assert old in s, "V9.8 marker: save method not found"
s = s.replace(old, new, 1)

# Make the persistent store more reliable: keep a second copy in NSUserDefaults
# inside the injected app container, while retaining custom-filters.json as the
# visible/editable source of truth.
old = '''static NSMutableArray *PHLoadFilters(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHFilterPath()];
    if (!data) return [NSMutableArray array];
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    return [json isKindOfClass:NSArray.class] ? [json mutableCopy] : [NSMutableArray array];
}'''
new = '''static NSMutableArray *PHLoadFilters(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHFilterPath()];
    id json = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] : nil;
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    if ([json isKindOfClass:NSArray.class] && [json count] > 0) return [json mutableCopy];

    NSArray *backup = [[NSUserDefaults standardUserDefaults] objectForKey:@"ProjetoH.PersistentFilters"];
    return [backup isKindOfClass:NSArray.class] ? [backup mutableCopy] : [NSMutableArray array];
}'''
assert old in s, "V9.8 marker: load method not found"
s = s.replace(old, new, 1)

old = '''static BOOL PHWriteFilters(NSArray *filters) {
    NSString *path = PHFilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"version": @1, @"filters": filters ?: @[] } options:0 error:nil];
    return data && [data writeToFile:path atomically:YES];
}'''
new = '''static BOOL PHWriteFilters(NSArray *filters) {
    NSString *path = PHFilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray *safeFilters = filters ?: @[];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"version": @1, @"filters": safeFilters } options:0 error:nil];
    BOOL fileOK = data && [data writeToFile:path atomically:YES];
    [[NSUserDefaults standardUserDefaults] setObject:safeFilters forKey:@"ProjetoH.PersistentFilters"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return fileOK;
}'''
assert old in s, "V9.8 marker: write method not found"
s = s.replace(old, new, 1)

# Re-apply persisted selectors more aggressively after navigation/content changes.
old = '''PHApplyTimer=[NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(__unused NSTimer *timer){ [[PHOverlayManager sharedManager] applyKnownWebViews]; }];'''
new = '''PHApplyTimer=[NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(__unused NSTimer *timer){ [[PHOverlayManager sharedManager] applyKnownWebViews]; }];'''
assert old in s, "V9.8 marker: apply timer not found"
s = s.replace(old, new, 1)

path.write_text(s, encoding="utf-8")
print("ProjetoH V9.8 save/gui/persistence patch applied successfully.")
