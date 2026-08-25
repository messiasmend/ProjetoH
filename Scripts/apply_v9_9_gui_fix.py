#!/usr/bin/env python3
from pathlib import Path
import re

# V9.9: rebuild only the Inspector button layout using UIKit Auto Layout.
# Functional filter/JSON behavior remains unchanged.

overlay = Path("Sources/PHOverlayManager.m")
s = overlay.read_text(encoding="utf-8")

method_re = re.compile(
    r'(- \(void\)showPanelWithSubtitle:\(NSString \*\)subtitle details:\(NSString \*\)details \{.*?)(\n\}\n\n- \(void\)showSelectedView:)',
    re.S,
)
m = method_re.search(s)
if not m:
    raise SystemExit("V9.9: showPanelWithSubtitle method not found")
method = m.group(1)

layout_re = re.compile(
    r'        \[panel addSubview:title\];.*?        \]\];',
    re.S,
)
layout = r'''        [panel addSubview:title];
        [panel addSubview:subtitleLabel];
        [panel addSubview:detailsLabel];

        // Row 1: Hierarquia | Copiar | Fechar
        UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[hierarchy, copyButton, close]];
        topRow.translatesAutoresizingMaskIntoConstraints = NO;
        topRow.axis = UILayoutConstraintAxisHorizontal;
        topRow.alignment = UIStackViewAlignmentCenter;
        topRow.distribution = UIStackViewDistributionFillEqually;
        topRow.spacing = 8.0;
        topRow.tag = 9001;

        // Row 2 is a dedicated host for Ocultar | Ocultos.
        UIView *bottomRow = [UIView new];
        bottomRow.translatesAutoresizingMaskIntoConstraints = NO;
        bottomRow.tag = 9002;

        [panel addSubview:topRow];
        [panel addSubview:bottomRow];
        [self.view addSubview:panel];

        [NSLayoutConstraint activateConstraints:@[
            [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
            [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:12.0],
            [panel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-12.0],
            [panel.widthAnchor constraintEqualToConstant:350.0],
            [panel.heightAnchor constraintEqualToConstant:430.0],

            [title.topAnchor constraintEqualToAnchor:panel.topAnchor constant:22.0],
            [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
            [subtitleLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5.0],
            [subtitleLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [detailsLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:20.0],
            [detailsLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
            [detailsLabel.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [detailsLabel.bottomAnchor constraintLessThanOrEqualToAnchor:topRow.topAnchor constant:-10.0],

            [topRow.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [topRow.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [topRow.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-62.0],
            [topRow.heightAnchor constraintEqualToConstant:32.0],

            [bottomRow.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
            [bottomRow.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
            [bottomRow.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0],
            [bottomRow.heightAnchor constraintEqualToConstant:32.0],
            [bottomRow.topAnchor constraintEqualToAnchor:topRow.bottomAnchor constant:10.0]
        ]];'''

method2, n = layout_re.subn(layout, method, count=1)
if n != 1:
    raise SystemExit("V9.9: Inspector layout block not found")
s = s[:m.start(1)] + method2 + s[m.end(1):]
overlay.write_text(s, encoding="utf-8")

filters = Path("Sources/PHCustomFiltersManager.m")
s = filters.read_text(encoding="utf-8")
if "static char K1,K2;" not in s:
    raise SystemExit("V9.9: expected K1,K2 declaration not found")
s = s.replace("static char K1,K2;", "static char K1,K2,K3;", 1)

phadd_re = re.compile(r'static void PHAdd\(void\)\{.*?\n\}\n(?=static void\(\*Orig\))', re.S)
new_add = r'''static void PHAdd(void){
    UIViewController*v=PHI();
    if(!v)return;

    UIButton*oldHide=objc_getAssociatedObject(v,&K1);
    if(oldHide)[oldHide removeFromSuperview];
    UIButton*oldManage=objc_getAssociatedObject(v,&K2);
    if(oldManage)[oldManage removeFromSuperview];
    UIView*oldRow=objc_getAssociatedObject(v,&K3);
    if(oldRow)[oldRow removeFromSuperview];

    [v.view layoutIfNeeded];

    UIView*panel=nil;
    for(UIView*sub in v.view.subviews.reverseObjectEnumerator){
        if(sub.tag==9002){
            panel=sub.superview;
            break;
        }
    }
    if(!panel)return;

    UIView*bottomRow=nil;
    for(UIView*sub in panel.subviews){
        if(sub.tag==9002){
            bottomRow=sub;
            break;
        }
    }
    if(!bottomRow)return;

    UIButton*h=[UIButton buttonWithType:UIButtonTypeSystem];
    UIButton*m=[UIButton buttonWithType:UIButtonTypeSystem];
    [h setTitle:@"Ocultar" forState:UIControlStateNormal];
    h.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [m setTitle:@"Ocultos" forState:UIControlStateNormal];
    m.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [h addTarget:PHCustomFiltersTarget.sharedTarget action:@selector(hide:) forControlEvents:UIControlEventTouchUpInside];
    [m addTarget:PHCustomFiltersTarget.sharedTarget action:@selector(manage:) forControlEvents:UIControlEventTouchUpInside];

    UIStackView*row=[[UIStackView alloc]initWithArrangedSubviews:@[h,m]];
    row.translatesAutoresizingMaskIntoConstraints=NO;
    row.axis=UILayoutConstraintAxisHorizontal;
    row.alignment=UIStackViewAlignmentCenter;
    row.distribution=UIStackViewDistributionEqualSpacing;
    row.spacing=24.0;

    [bottomRow addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.centerXAnchor constraintEqualToAnchor:bottomRow.centerXAnchor],
        [row.centerYAnchor constraintEqualToAnchor:bottomRow.centerYAnchor],
        [row.leadingAnchor constraintGreaterThanOrEqualToAnchor:bottomRow.leadingAnchor],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:bottomRow.trailingAnchor],
        [row.heightAnchor constraintEqualToConstant:32.0]
    ]];

    objc_setAssociatedObject(v,&K1,h,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(v,&K2,m,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(v,&K3,row,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
'''
s, n = phadd_re.subn(new_add, s, count=1)
if n != 1:
    raise SystemExit("V9.9: PHAdd block not found")
filters.write_text(s, encoding="utf-8")
print("Applied V9.9 GUI two-row Auto Layout fix")
