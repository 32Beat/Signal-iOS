//
//  Copyright (c) 2016 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>

// A set of helper methods for doing layout with PureLayout.
@interface UIView (OWS)

// Pins the width of this view to the view of its superview, with uniform margins.
- (void)autoPinWidthToSuperviewWithMargin:(CGFloat)margin;
// Pins the height of this view to the view of its superview, with uniform margins.
- (void)autoPinHeightToSuperviewWithMargin:(CGFloat)margin;

- (void)autoHCenterInSuperview;
- (void)autoVCenterInSuperview;

- (void)setContentHuggingHorizontalLow;
- (void)setContentHuggingHorizontalHigh;
- (void)setContentHuggingVerticalLow;
- (void)setContentHuggingVerticalHigh;

@end
