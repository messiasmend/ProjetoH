#!/usr/bin/env python3
from pathlib import Path
import re

path = Path("Sources/PHOverlayManager.m")
source = path.read_text(encoding="utf-8")

pattern = r'- \(void\)showPanelWithSubtitle:\(NSString \*\)subtitle details:\(NSString \*\)details \{.*?\n\}\n\n- \(void\)showSelectedView:'

replacement = '''- (void)showPanelWithSubtitle:(NSString *)subtitle details:(NSString *)details {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.selectionMode = NO;
        self.currentDetails = details ?: @"";
        [self clearSubviews];

        UIView *panel = [self makePanel];
        UILabel *title = [self labelWithText:@"ProjetoH Inspector" font:[UIFont boldSystemFontOfSize:21.0] color:UIColor.whiteColor];
        UILabel *subtitleLabel = [self labelWithText:subtitle font:[UIFont systemFontOfSize:14.0] color:[UIColor colorWithWhite:0.72 alpha:1.0]];

        UIScrollView *scrollView = [UIScrollView new];
        scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        scrollView.alwaysBounceVertical = YES;
        scrollView.showsVerticalScrollIndicator = YES;
        scrollView.directionalLockEnabled = YES;
        scrollView.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.55];
        scrollView.layer.cornerRadius = 8.0;
        scrollView.layer.masksToBounds = YES;

        UILabel *detailsLabel = [self labelWithText:details font:[UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightRegular] color:[UIColor colorWithWhite:0.86 alpha:1.0]];
        detailsLabel.textAlignment = NSTextAlignmentLeft;

        UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
        copyButton.translatesAutoresizingMaskIntoConstraints = NO;
        [copyButton setTitle:@"Copiar" forState:UIControlStateNormal];
        copyButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        [copyButton addTarget:self action:@selector(copyTapped) forControlEvents:UIControlEventTouchUpInside];

        UIButton *close = [self makeCloseButton];

        UIButton *hierarchy = [UIButton buttonWithType:UIButtonTypeSystem];
        hierarchy.translatesAutoresizingMaskIntoConstraints = NO;
        [hierarchy setTitle:@"Hierarquia" forState:UIControlStateNormal];
        hierarchy.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        [hierarchy addTarget:self action:@selector(hierarchyTapped) forControlEvents:UIControlEventTouchUpInside];

        [scrollView addSubview:detailsLabel];
        [panel addSubview:title];
        [panel addSubview:subtitleLabel];
        [panel addSubview:scrollView];
        [panel addSubview:hierarchy];
        [panel addSubview:copyButton];
        [panel addSubview:close];
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

            [scrollView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
            [scrollView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12.0],
            [scrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12.0],
            [scrollView.bottomAnchor constraintEqualToAnchor:hierarchy.topAnchor constant:-10.0],

            [detailsLabel.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:12.0],
            [detailsLabel.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:10.0],
            [detailsLabel.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-10.0],
            [detailsLabel.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-12.0],
            [detailsLabel.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-20.0],

            [hierarchy.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
            [hierarchy.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
            [copyButton.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
            [copyButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0],
            [close.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-22.0],
            [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20.0]
        ]];
    });
}

- (void)showSelectedView:'''

updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
if count != 1:
    raise SystemExit("V9.1 marker: showPanel method not found")

path.write_text(updated, encoding="utf-8")
print("Applied V9.1 scrollable inspector layout")
