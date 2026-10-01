#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DELvEKTheme : NSObject
+ (UIColor *)accentColor;
+ (void)applyAccentToViewHierarchy:(UIView *)view;
@end

NS_ASSUME_NONNULL_END
