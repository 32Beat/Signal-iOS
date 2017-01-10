//
//  Copyright (c) 2016 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (OWS)

- (void)autoPinWidthToSuperviewWithMargin:(CGFloat)margin;
- (void)autoPinHeightToSuperviewWithMargin:(CGFloat)margin;

- (void)autoHCenterInSuperview;
- (void)autoVCenterInSuperview;

- (void)setContentHuggingHorizontalLow;
- (void)setContentHuggingHorizontalHigh;
- (void)setContentHuggingVerticalLow;
- (void)setContentHuggingVerticalHigh;

@end
