#import "DELvEKTheme.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const void *kDELTopBarKey = &kDELTopBarKey;
static const void *kDELSearchExpandedKey = &kDELSearchExpandedKey;

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

static BOOL DELIsAccentCandidate(UIColor *color) {
    if (!color) return NO;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return NO;
    // Covers UIKit system blue plus the cyan/teal blue used by DELvEK.
    BOOL blue = (b > 0.45 && b > r * 1.20 && b >= g * 0.90 && g > 0.20);
    BOOL cyan = (g > 0.35 && b > 0.35 && r < 0.20 && fabs(g - b) < 0.35);
    return blue || cyan;
}

static void DELApplyAccent(UIView *view, UIColor *accent) {
    if (DELIsAccentCandidate(view.tintColor)) view.tintColor = accent;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (DELIsAccentCandidate(label.textColor)) label.textColor = accent;
    }

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (DELIsAccentCandidate(button.tintColor)) button.tintColor = accent;
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
        if (toggle.onTintColor && DELIsAccentCandidate(toggle.onTintColor)) {
            toggle.onTintColor = accent;
        }
    }

    CGColorRef border = view.layer.borderColor;
    if (border) {
        UIColor *borderColor = [UIColor colorWithCGColor:border];
        if (DELIsAccentCandidate(borderColor)) view.layer.borderColor = accent.CGColor;
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


@interface DELvEKTopBar : UIView
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *searchButton;
@property(nonatomic, strong) UIButton *historyButton;
@property(nonatomic, strong) UIButton *downloadButton;
@property(nonatomic, strong) UISearchBar *searchBar;
@property(nonatomic, weak) UIViewController *owner;
@property(nonatomic, assign) BOOL expanded;
@property(nonatomic, strong) NSLayoutConstraint *heightConstraint;
@end

@implementation DELvEKTopBar

- (instancetype)initWithOwner:(UIViewController *)owner {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _owner = owner;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;
    self.layer.zPosition = 10000;

    UIView *bar = [UIView new];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = UIColor.clearColor;
    [self addSubview:bar];

    _titleLabel = [UILabel new];
    _titleLabel.text = @"Home";
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightSemibold];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:_titleLabel];

    _searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _historyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    NSArray *buttons = @[_searchButton, _historyButton, _downloadButton];
    NSArray *symbols = @[@"magnifyingglass", @"clock", @"arrow.down.to.line"];
    for (NSUInteger i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tintColor = DELCurrentAccent();
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:23 weight:UIImageSymbolWeightMedium];
            [button setImage:[UIImage systemImageNamed:symbols[i] withConfiguration:config] forState:UIControlStateNormal];
        }
        [bar addSubview:button];
    }
    [_searchButton addTarget:self action:@selector(toggleSearch:) forControlEvents:UIControlEventTouchUpInside];

    _searchBar = [UISearchBar new];
    _searchBar.placeholder = @"Search";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.hidden = YES;
    [self addSubview:_searchBar];

    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:self.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:88],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:18],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor constant:8],
        [_downloadButton.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-14],
        [_downloadButton.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_downloadButton.widthAnchor constraintEqualToConstant:44],
        [_downloadButton.heightAnchor constraintEqualToConstant:44],
        [_historyButton.trailingAnchor constraintEqualToAnchor:_downloadButton.leadingAnchor constant:-2],
        [_historyButton.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_historyButton.widthAnchor constraintEqualToConstant:44],
        [_historyButton.heightAnchor constraintEqualToConstant:44],
        [_searchButton.trailingAnchor constraintEqualToAnchor:_historyButton.leadingAnchor constant:-2],
        [_searchButton.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [_searchButton.widthAnchor constraintEqualToConstant:44],
        [_searchButton.heightAnchor constraintEqualToConstant:44],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
        [_searchBar.topAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [_searchBar.heightAnchor constraintEqualToConstant:56],
    ]];
    return self;
}

- (void)toggleSearch:(id)sender {
    self.expanded = !self.expanded;
    self.searchBar.hidden = !self.expanded;
    self.heightConstraint.constant = self.expanded ? 144.0 : 88.0;
    [UIView animateWithDuration:0.22 animations:^{
        [self.superview layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (self.expanded) [self.searchBar becomeFirstResponder];
    }];
    objc_setAssociatedObject(self.owner, kDELSearchExpandedKey, @(self.expanded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

static BOOL DELLooksLikeHomeScreen(UIViewController *controller) {
    UITabBarController *tabs = controller.tabBarController;
    if (tabs && tabs.selectedViewController == controller) {
        UITabBarItem *item = controller.tabBarItem;
        if ([item.title.lowercaseString containsString:@"home"]) return YES;
    }
    __block BOOL found = NO;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:controller.view];
    while (stack.count && !found) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if ([v isKindOfClass:[UILabel class]]) {
            NSString *t = [(UILabel *)v text].lowercaseString;
            if ([t containsString:@"recommend"] || [t containsString:@"trending now"]) found = YES;
        }
        [stack addObjectsFromArray:v.subviews];
    }
    return found;
}

static void DELHideOriginalHomeTopControls(UIView *root) {
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        CGRect f = [view convertRect:view.bounds toView:root];
        if (f.origin.y < 160.0 && f.origin.y + f.size.height > 20.0) {
            if ([view isKindOfClass:[UISearchBar class]] ||
                [view isKindOfClass:[UITextField class]]) {
                view.hidden = YES;
            } else if ([view isKindOfClass:[UIButton class]]) {
                // The original home header contains Search/History/Download controls.
                // Keep the category labels and everything below the new top bar untouched.
                view.hidden = YES;
            }
        }
        [stack addObjectsFromArray:view.subviews];
    }
}

static void DELInstallTopBar(UIViewController *controller) {
    if (!DELLooksLikeHomeScreen(controller)) return;
    if (objc_getAssociatedObject(controller, kDELTopBarKey)) return;

    DELHideOriginalHomeTopControls(controller.view);
    DELvEKTopBar *topBar = [[DELvEKTopBar alloc] initWithOwner:controller];
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    [controller.view addSubview:topBar];
    topBar.heightConstraint = [topBar.heightAnchor constraintEqualToConstant:88];
    [NSLayoutConstraint activateConstraints:@[
        [topBar.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [topBar.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [topBar.topAnchor constraintEqualToAnchor:controller.view.topAnchor],
        topBar.heightConstraint
    ]];
    objc_setAssociatedObject(controller, kDELTopBarKey, topBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

    NSString *normalized = DELHexFromColor(color);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:normalized forKey:kThemeHexKey];
    [defaults synchronize];
    [self.view endEditing:YES];
    self.well.selectedColor = color;
    self.preview.backgroundColor = color;
    self.hexField.text = normalized;

    for (UIWindow *window in DELActiveWindows()) {
        [DELvEKTheme applyAccentToViewHierarchy:window];
        UIViewController *root = window.rootViewController;
        [DELvEKTheme refreshTopBarForController:root];
    }

    [self dismissViewControllerAnimated:YES completion:^{
        for (UIWindow *window in DELActiveWindows()) {
            [DELvEKTheme applyAccentToViewHierarchy:window];
        }
    }];
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
        [DELvEKTheme refreshTopBarForController:controller];
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


static void DELRefreshAllWindows(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *window in DELActiveWindows()) {
            UIViewController *root = window.rootViewController;
            if (!root) continue;
            [DELvEKTheme applyAccentToViewHierarchy:window];
            [DELvEKTheme refreshTopBarForController:root];
        }
    });
}

static void DELWindowDidAppearNotification(NSNotification *note) {
    (void)note;
    DELRefreshAllWindows();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DELRefreshAllWindows();
    });
}

@implementation DELvEKTheme
+ (UIColor *)accentColor { return DELCurrentAccent(); }
+ (void)applyAccentToViewHierarchy:(UIView *)view {
    if (!view) return;
    DELApplyAccent(view, DELCurrentAccent());
}
+ (void)refreshTopBarForController:(UIViewController *)controller {
    if (!controller) return;
    DELInstallTopBar(controller);
    DELvEKTopBar *bar = objc_getAssociatedObject(controller, kDELTopBarKey);
    if (bar) {
        UIColor *accent = DELCurrentAccent();
        bar.searchButton.tintColor = accent;
        bar.historyButton.tintColor = accent;
        bar.downloadButton.tintColor = accent;
        bar.titleLabel.textColor = UIColor.labelColor;
    }
    for (UIViewController *child in controller.childViewControllers) {
        [self refreshTopBarForController:child];
    }
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

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:DELWindowDidAppearNotification];
        [center addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:DELWindowDidAppearNotification];
        dispatch_async(dispatch_get_main_queue(), ^{
            DELRefreshAllWindows();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                DELRefreshAllWindows();
            });
        });
    }
}
