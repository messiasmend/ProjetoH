#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PHOverlayManager : NSObject

+ (instancetype)sharedManager;
- (void)presentTestOverlayIfNeeded;
- (void)presentInspectorIfNeeded;
- (void)startSelectionMode;
- (void)processInspectionEvent:(UIEvent *)event;
- (void)selectView:(UIView *)view;
- (void)dismissOverlay;

@end

NS_ASSUME_NONNULL_END
