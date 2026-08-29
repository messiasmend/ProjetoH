#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP PHV27OriginalRender = NULL;

static UILabel *PHV27FindLabel(UIView *root, NSString *text) {
    if (!root) return nil;
    if ([root isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)root;
        if ([label.text isEqualToString:text]) return label;
    }
    for (UIView *child in root.subviews) {
        UILabel *found = PHV27FindLabel(child, text);
        if (found) return found;
    }
    return nil;
}

static UILabel *PHV27FindFirstLabel(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:UILabel.class]) return (UILabel *)root;
    for (UIView *child in root.subviews) {
        UILabel *found = PHV27FindFirstLabel(child);
        if (found) return found;
    }
    return nil;
}

static void PHV27ApplyHeader(UIViewController *controller, BOOL hierarchyMode) {
    UIView *root = controller.view;
    if (!root) return;

    /* The original inspector title is wrong for WebHider. Set it by role/text
       after render so every state uses the same product name. */
    UILabel *title = PHV27FindLabel(root, @"ProjetoH Inspector");
    if (!title) title = PHV27FindLabel(root, @"WebHider Inspector");
    if (!title) title = PHV27FindFirstLabel(root);
    if (title) {
        title.text = @"WebHider Inspector";
    }

    UILabel *subtitle = PHV27FindLabel(root, @"Hierarquia DOM");
    if (!subtitle) subtitle = PHV27FindLabel(root, @"Elemento Web selecionado");
    if (!subtitle) subtitle = PHV27FindLabel(root, @"Elemento nativo selecionado");
    if (!subtitle) subtitle = PHV27FindLabel(root, @"Filtro JSON");

    if (subtitle) {
        NSString *current = nil;
        @try { current = [controller valueForKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}

        if (hierarchyMode) {
            /* JSON also uses render:YES. currentSubtitle is deliberately set
               to Filtro JSON by the JSON state machine, so preserve that state. */
            subtitle.text = [current isEqualToString:@"Filtro JSON"] ? @"Filtro JSON" : @"Hierarquia DOM";
        } else if (current.length) {
            subtitle.text = current;
        } else {
            subtitle.text = @"Elemento Web selecionado";
        }
    }
}

static void PHV27Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PHV27OriginalRender) {
        ((void (*)(id, SEL, BOOL))PHV27OriginalRender)(self, _cmd, hierarchyMode);
    }

    /* Apply immediately, before a later run-loop frame can expose the
       original ProjetoH/Hierarquia header. */
    PHV27ApplyHeader((UIViewController *)self, hierarchyMode);
}

__attribute__((constructor))
static void PHV27Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;

        Method method = class_getInstanceMethod(cls, @selector(render:));
        if (!method) return;

        IMP current = method_getImplementation(method);
        if (current == (IMP)PHV27Render) return;

        PHV27OriginalRender = current;
        method_setImplementation(method, (IMP)PHV27Render);
    });
}
