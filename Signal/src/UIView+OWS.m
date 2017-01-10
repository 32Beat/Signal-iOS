//
//  Copyright (c) 2016 Open Whisper Systems. All rights reserved.
//

#import "UIView+OWS.h"

@implementation UIView (OWS)

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
