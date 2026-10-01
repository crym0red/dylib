#import "DELvEKTheme.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString * const kThemeHexKey = @"DELvEK.Theme.Hex";
static NSString * const kThemeManagerTag = @"DELvEKThemeManager";

static UIColor *ColorFromHex(NSString *hex) {
    NSString *s = [[hex stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length != 6 && s.length != 8) return nil;

    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    if (![scanner scanHexInt:&value]) return nil;

    CGFloat r = ((value >> (s.length == 8 ? 24 : 16)) & 0xFF) / 255.0;
    CGFloat g = ((value >> (s.length == 8 ? 16 : 8)) & 0xFF) / 255.0;
    CGFloat b = ((value >> (s.length == 8 ? 8 : 0)) & 0xFF) / 255.0;
    CGFloat a = (s.length == 8 ? (value & 0xFF) : 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

static NSString *HexFromColor(UIColor *color) {
    CGFloat r=0,g=0,b=0,a=0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w=0;
        if ([color getWhite:&w alpha:&a]) r=g=b=w;
        else return @"#34C759";
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)lrintf(r*255), (int)lrintf(g*255), (int)lrintf(b*255)];
}

static UIColor *DefaultAccent(void) {
    return [UIColor colorWithRed:52.0/255.0 green:199.0/255.0 blue:89.0/255.0 alpha:1.0];
}

static UIColor *CurrentAccent(void) {
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:kThemeHexKey];
    UIColor *c = ColorFromHex(hex ?: @"");
    return c ?: DefaultAccent();
}

static BOOL IsCloseToSystemBlue(UIColor *color) {
    if (!color) return NO;
    CGFloat r=0,g=0,b=0,a=0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return NO;
    // Match common UIKit system-blue tinting without touching arbitrary app colors.
    return (b > 0.65 && r < 0.25 && g > 0.25 && b > g * 1.05);
}

static void ApplyAccent(UIView *view, UIColor *accent) {
    if (IsCloseToSystemBlue(view.tintColor)) {
        view.tintColor = accent;
    }

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (IsCloseToSystemBlue(label.textColor)) label.textColor = accent;
    }

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (IsCloseToSystemBlue(button.tintColor)) button.tintColor = accent;
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *cfg = button.configuration;
            if (cfg) {
                cfg.baseForegroundColor = accent;
                button.configuration = cfg;
            }
        }
    }

    if ([view isKindOfClass:[UISwitch class]]) {
        UISwitch *sw = (UISwitch *)view;
        sw.onTintColor = accent;
        sw.thumbTintColor = sw.thumbTintColor;
    }

    CGColorRef border = view.layer.borderColor;
    if (border) {
        UIColor *borderColor = [UIColor colorWithCGColor:border];
        if (IsCloseToSystemBlue(borderColor)) view.layer.borderColor = accent.CGColor;
    }

    for (UIView *subview in view.subviews) {
        ApplyAccent(subview, accent);
    }
}

static BOOL ContainsSettingsText(UIView *root) {
    __block BOOL found = NO;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count && !found) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];

        if ([v isKindOfClass:[UILabel class]]) {
            NSString *text = [(UILabel *)v text].lowercaseString;
            if ([text containsString:@"language switching"] ||
                [text isEqualToString:@"settings"] ||
                [text containsString:@"my favorites"] ||
                [text containsString:@"customer service"]) {
                found = YES;
                break;
            }
        }
        [stack addObjectsFromArray:v.subviews];
    }
    return found;
}

@class DELvEKThemeManagerHost;

@interface DELvEKThemeManagerViewController : UIViewController <UIColorPickerViewControllerDelegate>
@property(nonatomic,strong) UIColorWell *well;
@property(nonatomic,strong) UITextField *hexField;
@property(nonatomic,strong) UIView *preview;
@end

@implementation DELvEKThemeManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"Theme Manager";

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Accent color";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    title.translatesAutoresizingMaskIntoConstraints = NO;

    self.well = [[UIColorWell alloc] init];
    self.well.selectedColor = CurrentAccent();
    self.well.translatesAutoresizingMaskIntoConstraints = NO;
    [self.well addTarget:self action:@selector(colorChanged:) forControlEvents:UIControlEventValueChanged];

    self.hexField = [[UITextField alloc] init];
    self.hexField.text = HexFromColor(CurrentAccent());
    self.hexField.placeholder = @"#34C759";
    self.hexField.borderStyle = UITextBorderStyleRoundedRect;
    self.hexField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.hexField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.hexField.translatesAutoresizingMaskIntoConstraints = NO;
    self.hexField.returnKeyType = UIReturnKeyDone;

    UIButton *picker = [UIButton buttonWithType:UIButtonTypeSystem];
    [picker setTitle:@"Open color wheel" forState:UIControlStateNormal];
    picker.translatesAutoresizingMaskIntoConstraints = NO;
    [picker addTarget:self action:@selector(openPicker:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:@"Save theme" forState:UIControlStateNormal];
    save.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    save.translatesAutoresizingMaskIntoConstraints = NO;
    [save addTarget:self action:@selector(saveTheme:) forControlEvents:UIControlEventTouchUpInside];

    self.preview = [[UIView alloc] init];
    self.preview.layer.cornerRadius = 14;
    self.preview.backgroundColor = CurrentAccent();
    self.preview.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:
                          @[title, self.well, self.hexField, picker, self.preview, save]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [self.preview.heightAnchor constraintEqualToConstant:72]
    ]];
}

- (void)colorChanged:(UIColorWell *)sender {
    self.preview.backgroundColor = sender.selectedColor;
    self.hexField.text = HexFromColor(sender.selectedColor);
}

- (void)openPicker:(id)sender {
    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    picker.selectedColor = self.well.selectedColor ?: CurrentAccent();
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    self.well.selectedColor = viewController.selectedColor;
    [self colorChanged:self.well];
}

- (void)saveTheme:(id)sender {
    UIColor *color = ColorFromHex(self.hexField.text);
    if (!color) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Invalid HEX"
            message:@"Enter a color such as #34C759."
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:HexFromColor(color) forKey:kThemeHexKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        [DELvEKTheme applyAccentToViewHierarchy:window];
    }

    [self.navigationController popViewControllerAnimated:YES];
}

@end

static void AddThemeManagerFooter(UITableView *tableView) {
    if ([tableView viewWithTag:0xD3E1]) return;

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 74)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = 0xD3E1;
    button.accessibilityIdentifier = kThemeManagerTag;
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
        [button.heightAnchor constraintEqualToConstant:48]
    ]];

    tableView.tableFooterView = footer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [DELvEKTheme applyAccentToViewHierarchy:footer];
    });
}

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
    UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIViewController *top = root;
    while (top.presentedViewController) top = top.presentedViewController;

    DELvEKThemeManagerViewController *theme = [DELvEKThemeManagerViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:theme];
    [top presentViewController:nav animated:YES completion:nil];
}
@end

@implementation DELvEKTheme

+ (UIColor *)accentColor {
    return CurrentAccent();
}

+ (void)applyAccentToViewHierarchy:(UIView *)view {
    ApplyAccent(view, CurrentAccent());
}

@end

#pragma mark - Runtime hooks

static IMP orig_viewDidAppear = NULL;
static IMP orig_viewDidLayoutSubviews = NULL;

static void hooked_viewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    ((void(*)(id,SEL,BOOL))orig_viewDidAppear)(self,_cmd,animated);

    dispatch_async(dispatch_get_main_queue(), ^{
        [DELvEKTheme applyAccentToViewHierarchy:self.view];

        if (ContainsSettingsText(self.view)) {
            for (UIView *v in self.view.subviews) {
                if ([v isKindOfClass:[UITableView class]]) {
                    AddThemeManagerFooter((UITableView *)v);
                }
                for (UIView *sub in v.subviews) {
                    if ([sub isKindOfClass:[UITableView class]]) {
                        AddThemeManagerFooter((UITableView *)sub);
                    }
                }
            }
        }
    });
}

static void hooked_viewDidLayoutSubviews(UIViewController *self, SEL _cmd) {
    ((void(*)(id,SEL))orig_viewDidLayoutSubviews)(self,_cmd);

    static __thread BOOL busy = NO;
    if (busy) return;
    busy = YES;
    [DELvEKTheme applyAccentToViewHierarchy:self.view];
    busy = NO;
}

__attribute__((constructor))
static void DELvEKThemeInit(void) {
    @autoreleasepool {
        Class cls = [UIViewController class];

        SEL appear = @selector(viewDidAppear:);
        Method appearMethod = class_getInstanceMethod(cls, appear);
        orig_viewDidAppear = method_getImplementation(appearMethod);
        method_setImplementation(appearMethod, (IMP)hooked_viewDidAppear);

        SEL layout = @selector(viewDidLayoutSubviews);
        Method layoutMethod = class_getInstanceMethod(cls, layout);
        orig_viewDidLayoutSubviews = method_getImplementation(layoutMethod);
        method_setImplementation(layoutMethod, (IMP)hooked_viewDidLayoutSubviews);

        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIWindow *window in UIApplication.sharedApplication.windows) {
                [DELvEKTheme applyAccentToViewHierarchy:window];
            }
        });
    }
}
