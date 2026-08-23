#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PHPreciseSelector : NSObject
+ (instancetype)sharedSelector;
- (void)reset;
- (void)processEvent:(UIEvent *)event inspectorWindow:(nullable UIWindow *)inspectorWindow;
@end

NS_ASSUME_NONNULL_END
