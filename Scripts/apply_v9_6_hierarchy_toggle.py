#!/usr/bin/env python3
from pathlib import Path

path = Path("Sources/PHOverlayManager.m")
s = path.read_text(encoding="utf-8")

# Keep the last inspected details so Hierarquia can return to the Inspector.
old = '@property (nonatomic, copy) NSString *currentDetails;\n+ (NSString *)descriptionForView:(UIView *)view;'
new = '@property (nonatomic, copy) NSString *currentDetails;\n@property (nonatomic, copy) NSString *baseDetails;\n@property (nonatomic, assign) BOOL showingHierarchy;\n+ (NSString *)descriptionForView:(UIView *)view;'
if old not in s:
    raise SystemExit("V9.6 marker: inspector properties not found")
s = s.replace(old, new, 1)

old = '''- (void)showSelectedView:(UIView *)view {
    [self showPanelWithSubtitle:@"Elemento nativo selecionado" details:[PHInspectorViewController descriptionForView:view]];
}

- (void)showSelectedWebElement:(NSString *)details {
    [self showPanelWithSubtitle:@"Elemento Web selecionado" details:details];
}

- (void)hierarchyTapped {
    [[PHOverlayManager sharedManager] showHierarchy];
}'''
new = '''- (void)showSelectedView:(UIView *)view {
    self.showingHierarchy = NO;
    self.baseDetails = [PHInspectorViewController descriptionForView:view];
    [self showPanelWithSubtitle:@"Elemento nativo selecionado" details:self.baseDetails];
}

- (void)showSelectedWebElement:(NSString *)details {
    if (!self.showingHierarchy) self.baseDetails = details ?: @"";
    [self showPanelWithSubtitle:self.showingHierarchy ? @"Hierarquia DOM" : @"Elemento Web selecionado" details:details];
}

- (void)showHierarchyDetails:(NSString *)details {
    self.showingHierarchy = YES;
    [self showPanelWithSubtitle:@"Hierarquia DOM" details:details ?: @""];
}

- (void)hierarchyTapped {
    if (self.showingHierarchy) {
        self.showingHierarchy = NO;
        [self showPanelWithSubtitle:@"Elemento Web selecionado" details:self.baseDetails ?: @""];
        return;
    }
    [[PHOverlayManager sharedManager] showHierarchy];
}'''
if old not in s:
    raise SystemExit("V9.6 marker: hierarchy methods not found")
s = s.replace(old, new, 1)

old = '[hierarchy setTitle:@"Hierarquia" forState:UIControlStateNormal];'
new = '[hierarchy setTitle:self.showingHierarchy ? @"Voltar" : @"Hierarquia" forState:UIControlStateNormal];'
if old not in s:
    raise SystemExit("V9.6 marker: hierarchy button title not found")
s = s.replace(old, new, 1)

# Route hierarchy output through the dedicated hierarchy state so the button becomes Voltar.
old = '[self.inspectorViewController showSelectedWebElement:@"Hierarquia Web\\n\\nNão foi possível obter a árvore DOM."];'
new = '[self.inspectorViewController showHierarchyDetails:@"Hierarquia Web\\n\\nNão foi possível obter a árvore DOM."];'
if old not in s:
    raise SystemExit("V9.6 marker: web hierarchy error route not found")
s = s.replace(old, new, 1)

old = '[self.inspectorViewController showSelectedWebElement:details];'
new = '[self.inspectorViewController showHierarchyDetails:details];'
if old not in s:
    raise SystemExit("V9.6 marker: web hierarchy details route not found")
s = s.replace(old, new, 1)

# Native hierarchy uses the same toggle state.
old = '[self.inspectorViewController showSelectedWebElement:details];\n    });\n}\n\n- (void)processInspectionEvent:'
new = '[self.inspectorViewController showHierarchyDetails:details];\n    });\n}\n\n- (void)processInspectionEvent:'
if old not in s:
    raise SystemExit("V9.6 marker: native hierarchy route not found")
s = s.replace(old, new, 1)

# Declare the private helper so the implementation compiles without an undeclared-selector warning.
old = '- (void)showSelectedWebElement:(NSString *)details;\n@end'
new = '- (void)showSelectedWebElement:(NSString *)details;\n- (void)showHierarchyDetails:(NSString *)details;\n@end'
if old not in s:
    raise SystemExit("V9.6 marker: inspector interface declaration not found")
s = s.replace(old, new, 1)

path.write_text(s, encoding="utf-8")
print("Applied V9.6 hierarchy toggle")
