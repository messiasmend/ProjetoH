from pathlib import Path

path = Path("Sources/PHOverlayManager.m")
source = path.read_text(encoding="utf-8")

old = '''@property (nonatomic, strong, nullable) UIColor *previousBorderColor;\n- (void)showHierarchy;'''
new = '''@property (nonatomic, strong, nullable) UIColor *previousBorderColor;\n@property (nonatomic, copy) NSString *currentDetails;\n- (void)showHierarchy;'''
assert old in source, "V9 marker: controller properties not found"
source = source.replace(old, new, 1)

old = '''        self.selectionMode = NO;\n        [self clearSubviews];\n        UIView *panel = [self makePanel];'''
new = '''        self.selectionMode = NO;\n        self.currentDetails = details ?: @"";\n        [self clearSubviews];\n        UIView *panel = [self makePanel];'''
assert old in source, "V9 marker: showPanel start not found"
source = source.replace(old, new, 1)

old = '''        UIButton *close = [self makeCloseButton];\n        UIButton *hierarchy = [UIButton buttonWithType:UIButtonTypeSystem];'''
new = '''        UIButton *close = [self makeCloseButton];\n        UIButton *copy = [UIButton buttonWithType:UIButtonTypeSystem];\n        copy.translatesAutoresizingMaskIntoConstraints = NO;\n        copy.tag = 9001;\n        [copy setTitle:@"Copiar" forState:UIControlStateNormal];\n        copy.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];\n        [copy addTarget:self action:@selector(copyTapped) forControlEvents:UIControlEventTouchUpInside];\n        UIButton *hierarchy = [UIButton buttonWithType:UIButtonTypeSystem];'''
assert old in source, "V9 marker: close button block not found"
source = source.replace(old, new, 1)

old = '''        [panel addSubview:detailsLabel];\n        [panel addSubview:hierarchy];\n        [panel addSubview:close];'''
new = '''        [panel addSubview:detailsLabel];\n        [panel addSubview:hierarchy];\n        [panel addSubview:copy];\n        [panel addSubview:close];'''
assert old in source, "V9 marker: panel button insertion point not found"
source = source.replace(old, new, 1)

old = '''            [hierarchy.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],\n            [hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],\n            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],'''
new = '''            [hierarchy.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],\n            [hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],\n            [copy.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],\n            [copy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],\n            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],'''
assert old in source, "V9 marker: button constraints not found"
source = source.replace(old, new, 1)

old = '''- (void)closeTapped { [[PHOverlayManager sharedManager] dismissOverlay]; }'''
new = '''- (void)copyTapped {\n    UIPasteboard.generalPasteboard.string = self.currentDetails ?: @"";\n    UIButton *button = (UIButton *)[self.view viewWithTag:9001];\n    if (button != nil) {\n        [button setTitle:@"✓ Copiado" forState:UIControlStateNormal];\n        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{\n            [button setTitle:@"Copiar" forState:UIControlStateNormal];\n        });\n    }\n}\n\n- (void)closeTapped { [[PHOverlayManager sharedManager] dismissOverlay]; }'''
assert old in source, "V9 marker: closeTapped method not found"
source = source.replace(old, new, 1)

path.write_text(source, encoding="utf-8")
print("ProjetoH V9 copy button patch applied successfully.")
