#import "DELvEKTheme.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString * const kThemeHexKey = @"DELvEK.Theme.Hex";
static NSInteger const kThemeManagerTag = 0xD3E1;

static NSArray<UIWindow *> *DELActiveWindows(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        if (scene.activationState == UISceneActivationStateUnattached) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.hidden && window.alpha > 0.0) [windows addObject:window];
        }
    }
    return windows.copy;
}

static UIWindow *DELKeyWindow(void) {
    for (UIWindow *window in DELActiveWindows()) {
        if (window.isKeyWindow) return window;
    }
    return DELActiveWindows().firstObject;
}

static UIColor *DELColorFromHex(NSString *hex) {
    NSString *s = [[hex stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length != 6 && s.length != 8) return nil;

    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    if (![scanner scanHexInt:&value]) return nil;

    BOOL hasAlpha = (s.length == 8);
    CGFloat r = ((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255.0;
    CGFloat g = ((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255.0;
    CGFloat b = ((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255.0;
    CGFloat a = hasAlpha ? (value & 0xFF) / 255.0 : 1.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

static NSString *DELHexFromColor(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        if ([color getWhite:&w alpha:&a]) r = g = b = w;
        else return @"#34C759";
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (unsigned)lrintf(r * 255.0f),
            (unsigned)lrintf(g * 255.0f),
            (unsigned)lrintf(b * 255.0f)];
}

static UIColor *DELDefaultAccent(void) {
    return [UIColor colorWithRed:52.0/255.0 green:199.0/255.0 blue:89.0/255.0 alpha:1.0];
}

static UIColor *DELCurrentAccent(void) {
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:kThemeHexKey];
    return DELColorFromHex(hex ?: @"") ?: DELDefaultAccent();
}

static BOOL DELIsSystemBlue(UIColor *color) {
    if (!color) return NO;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return NO;
    return (b > 0.60 && r < 0.30 && g > 0.20 && b > g * 1.05);
}

static void DELApplyAccent(UIView *view, UIColor *accent) {
    if (DELIsSystemBlue(view.tintColor)) view.tintColor = accent;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (DELIsSystemBlue(label.textColor)) label.textColor = accent;
    }

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (DELIsSystemBlue(button.tintColor)) button.tintColor = accent;
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *configuration = button.configuration;
            if (configuration) {
                configuration.baseForegroundColor = accent;
                button.configuration = configuration;
            }
        }
    }

    if ([view isKindOfClass:[UISwitch class]]) {
        UISwitch *toggle = (UISwitch *)view;
        if (toggle.onTintColor && DELIsSystemBlue(toggle.onTintColor)) {
            toggle.onTintColor = accent;
        }
    }

    CGColorRef border = view.layer.borderColor;
    if (border) {
        UIColor *borderColor = [UIColor colorWithCGColor:border];
        if (DELIsSystemBlue(borderColor)) view.layer.borderColor = accent.CGColor;
    }

    for (UIView *subview in view.subviews) {
        DELApplyAccent(subview, accent);
    }
}

static BOOL DELLooksLikeSettingsScreen(UIView *root) {
    __block BOOL found = NO;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count && !found) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:[UILabel class]]) {
            NSString *text = [(UILabel *)view text].lowercaseString;
            if ([text containsString:@"language switching"] ||
                [text isEqualToString:@"settings"] ||
                [text containsString:@"my favorites"] ||
                [text containsString:@"customer service"]) {
                found = YES;
                break;
            }
        }
        [stack addObjectsFromArray:view.subviews];
    }
    return found;
}

// Theme-manager host is declared and implemented before DELAddThemeManagerFooter.
@interface DELvEKThemeManagerViewController : UIViewController <UIColorPickerViewControllerDelegate>
@property(nonatomic, strong) UIColorWell *well;
@property(nonatomic, strong) UITextField *hexField;
@property(nonatomic, strong) UIView *preview;
@end

@implementation DELvEKThemeManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"Theme Manager";

    UILabel *title = [UILabel new];
    title.text = @"Accent color";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];

    self.well = [UIColorWell new];
    self.well.selectedColor = DELCurrentAccent();
    [self.well addTarget:self action:@selector(colorChanged:) forControlEvents:UIControlEventValueChanged];

    self.hexField = [UITextField new];
    self.hexField.text = DELHexFromColor(DELCurrentAccent());
    self.hexField.placeholder = @"#34C759";
    self.hexField.borderStyle = UITextBorderStyleRoundedRect;
    self.hexField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.hexField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.hexField.returnKeyType = UIReturnKeyDone;

    UIButton *picker = [UIButton buttonWithType:UIButtonTypeSystem];
    [picker setTitle:@"Open color wheel" forState:UIControlStateNormal];
    [picker addTarget:self action:@selector(openPicker:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:@"Save theme" forState:UIControlStateNormal];
    save.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [save addTarget:self action:@selector(saveTheme:) forControlEvents:UIControlEventTouchUpInside];

    self.preview = [UIView new];
    self.preview.layer.cornerRadius = 14.0;
    self.preview.backgroundColor = DELCurrentAccent();

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        title, self.well, self.hexField, picker, self.preview, save
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24.0],
        [self.preview.heightAnchor constraintEqualToConstant:72.0]
    ]];
}

- (void)colorChanged:(UIColorWell *)sender {
    self.preview.backgroundColor = sender.selectedColor;
    self.hexField.text = DELHexFromColor(sender.selectedColor);
}

- (void)openPicker:(id)sender {
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.selectedColor = self.well.selectedColor ?: DELCurrentAccent();
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    self.well.selectedColor = viewController.selectedColor;
    [self colorChanged:self.well];
}

- (void)saveTheme:(id)sender {
    UIColor *color = DELColorFromHex(self.hexField.text ?: @"");
    if (!color) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid HEX"
            message:@"Enter a color such as #34C759."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:DELHexFromColor(color) forKey:kThemeHexKey];
    [self.view endEditing:YES];

    for (UIWindow *window in DELActiveWindows()) {
        [DELvEKTheme applyAccentToViewHierarchy:window];
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface DELvEKThemeManagerHost : NSObject
+ (instancetype)sharedHost;
- (void)openThemeManager:(UIButton *)sender;
@end

@implementation DELvEKThemeManagerHost
+ (instancetype)sharedHost {
    static DELvEKThemeManagerHost *host;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ host = [DELvEKThemeManagerHost new]; });
    return host;
}

- (void)openThemeManager:(UIButton *)sender {
    (void)sender;
    UIWindow *window = DELKeyWindow();
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;

    UINavigationController *navigation = [[UINavigationController alloc]
        initWithRootViewController:[DELvEKThemeManagerViewController new]];
    [top presentViewController:navigation animated:YES completion:nil];
}
@end

static void DELAddThemeManagerFooter(UITableView *tableView) {
    if ([tableView viewWithTag:kThemeManagerTag]) return;

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 74.0)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kThemeManagerTag;
    [button setTitle:@"Theme Manager" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:[DELvEKThemeManagerHost sharedHost]
               action:@selector(openThemeManager:)
     forControlEvents:UIControlEventTouchUpInside];

    [footer addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.centerXAnchor constraintEqualToAnchor:footer.centerXAnchor],
        [button.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [button.heightAnchor constraintEqualToConstant:48.0]
    ]];

    tableView.tableFooterView = footer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [DELvEKTheme applyAccentToViewHierarchy:footer];
    });
}

static UITableView *DELFindTableView(UIView *root) {
    if ([root isKindOfClass:[UITableView class]]) return (UITableView *)root;
    for (UIView *subview in root.subviews) {
        UITableView *table = DELFindTableView(subview);
        if (table) return table;
    }
    return nil;
}

static IMP DELOriginalViewDidAppear = NULL;
static IMP DELOriginalViewDidLayoutSubviews = NULL;

static void DELHookedViewDidAppear(UIViewController *controller, SEL selector, BOOL animated) {
    if (DELOriginalViewDidAppear) {
        ((void(*)(id, SEL, BOOL))DELOriginalViewDidAppear)(controller, selector, animated);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [DELvEKTheme applyAccentToViewHierarchy:controller.view];
        if (DELLooksLikeSettingsScreen(controller.view)) {
            UITableView *table = DELFindTableView(controller.view);
            if (table) DELAddThemeManagerFooter(table);
        }
    });
}

static void DELHookedViewDidLayoutSubviews(UIViewController *controller, SEL selector) {
    if (DELOriginalViewDidLayoutSubviews) {
        ((void(*)(id, SEL))DELOriginalViewDidLayoutSubviews)(controller, selector);
    }

    static __thread BOOL busy = NO;
    if (busy) return;
    busy = YES;
    [DELvEKTheme applyAccentToViewHierarchy:controller.view];
    busy = NO;
}

@implementation DELvEKTheme
+ (UIColor *)accentColor { return DELCurrentAccent(); }
+ (void)applyAccentToViewHierarchy:(UIView *)view {
    if (!view) return;
    DELApplyAccent(view, DELCurrentAccent());
}
@end

__attribute__((constructor))
static void DELvEKThemeInit(void) {
    @autoreleasepool {
        Class cls = [UIViewController class];

        Method appear = class_getInstanceMethod(cls, @selector(viewDidAppear:));
        if (appear) {
            DELOriginalViewDidAppear = method_getImplementation(appear);
            method_setImplementation(appear, (IMP)DELHookedViewDidAppear);
        }

        Method layout = class_getInstanceMethod(cls, @selector(viewDidLayoutSubviews));
        if (layout) {
            DELOriginalViewDidLayoutSubviews = method_getImplementation(layout);
            method_setImplementation(layout, (IMP)DELHookedViewDidLayoutSubviews);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIWindow *window in DELActiveWindows()) {
                [DELvEKTheme applyAccentToViewHierarchy:window];
            }
        });
    }
}
