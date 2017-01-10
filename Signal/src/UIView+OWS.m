//
//  Copyright (c) 2016 Open Whisper Systems. All rights reserved.
//

#import "UIView+OWS.h"
#import "PureLayout.h"

@implementation UIView (OWS)

- (void)autoPinWidthToSuperviewWithMargin:(CGFloat)margin {
    [self autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.superview withOffset:+margin];
    [self autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.superview withOffset:-margin];
}

- (void)autoPinHeightToSuperviewWithMargin:(CGFloat)margin {
    [self autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.superview withOffset:+margin];
    [self autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.superview withOffset:-margin];
}

- (void)autoHCenterInSuperview {
    [self autoAlignAxis:ALAxisVertical toSameAxisOfView:self.superview];
}

- (void)autoVCenterInSuperview {
    [self autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.superview];
}

- (void)setContentHuggingHorizontalLow {
    [self setContentHuggingPriority:0
                            forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)setContentHuggingHorizontalHigh {
    [self setContentHuggingPriority:1000
                            forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)setContentHuggingVerticalLow {
    [self setContentHuggingPriority:0
                            forAxis:UILayoutConstraintAxisVertical];
}

- (void)setContentHuggingVerticalHigh {
    [self setContentHuggingPriority:1000
                            forAxis:UILayoutConstraintAxisVertical];
}

@end
