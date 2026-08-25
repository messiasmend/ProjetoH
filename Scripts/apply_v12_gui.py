from pathlib import Path
p=Path('Sources/PHOverlayManager.m')
s=p.read_text(encoding='utf-8')
start=s.index('- (void)render:(BOOL)hierarchyMode {')
end=s.index('- (void)hierarchyTapped {',start)
render=r'''- (void)render:(BOOL)hierarchyMode {
    [self clear];
    UIView *p=[self panel]; [self.view addSubview:p];
    UILabel *title=[self label:@"ProjetoH Inspector" font:[UIFont boldSystemFontOfSize:21] color:UIColor.whiteColor];
    UILabel *subtitle=[self label:(hierarchyMode?@"Hierarquia DOM":self.currentSubtitle) font:[UIFont systemFontOfSize:14] color:[UIColor colorWithWhite:0.72 alpha:1]];
    UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO; scroll.backgroundColor=[UIColor colorWithWhite:0.055 alpha:1]; scroll.layer.cornerRadius=12; scroll.alwaysBounceVertical=YES;
    UILabel *content=[self label:self.currentDetails font:[UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular] color:[UIColor colorWithWhite:0.88 alpha:1]]; [scroll addSubview:content];
    UIButton *left=[self button:(hierarchyMode?@"Voltar":@"Hierarquia") action:(hierarchyMode?@selector(backTapped):@selector(hierarchyTapped))];
    UIButton *copy=[self button:@"Copiar" action:@selector(copyTapped)]; UIButton *close=[self button:@"Fechar" action:@selector(closeTapped)];
    UIButton *hide=[self button:@"Ocultar" action:@selector(hideTapped)]; UIButton *hidden=[self button:@"Ocultos" action:@selector(hiddenTapped)]; UIButton *save=[self button:@"Salvar" action:@selector(saveTapped)];
    BOOL pending=PHPendingSelectors.count>0; save.hidden=NO; save.alpha=pending?1.0:0.35; save.userInteractionEnabled=pending;
    for(UIView *v in @[title,subtitle,scroll,left,copy,close,hide,hidden,save]) [p addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [p.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[p.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[p.widthAnchor constraintEqualToConstant:360],[p.heightAnchor constraintEqualToConstant:560],
        [title.topAnchor constraintEqualToAnchor:p.topAnchor constant:22],[title.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:22],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],[subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:18],[scroll.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[scroll.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[scroll.heightAnchor constraintEqualToConstant:370],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],[content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],[content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],[content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],
        [left.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[left.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-78],[left.widthAnchor constraintEqualToConstant:100],
        [copy.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],[copy.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-78],[copy.widthAnchor constraintEqualToConstant:100],
        [close.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[close.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-78],[close.widthAnchor constraintEqualToConstant:100],
        [hide.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[hide.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-24],[hide.widthAnchor constraintEqualToConstant:100],
        [hidden.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],[hidden.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-24],[hidden.widthAnchor constraintEqualToConstant:100],
        [save.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[save.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-24],[save.widthAnchor constraintEqualToConstant:100]
    ]];
}

'''
s=s[:start]+render+s[end:]
p.write_text(s,encoding='utf-8')
