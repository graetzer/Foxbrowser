//
//  SGAddView.m
//  Foxbrowser
//
//  Created by simon on 16.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGAddButton.h"
#import "SGTabDefines.h"
#import <math.h>

@implementation SGAddButton
@synthesize button, tabColor;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.tabColor = kTabColor;
        self.backgroundColor = [UIColor clearColor];
        
        self.button = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.button setImage:[UIImage imageNamed:@"plus"] forState:UIControlStateNormal];
        self.button.showsTouchWhenHighlighted = YES;
        self.button.frame = CGRectMake(kCornerRadius, 0, self.bounds.size.width - kCornerRadius, self.bounds.size.height);
        [self addSubview:self.button];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGRect  tabRect   = self.bounds;
    CGFloat tabLeft   = tabRect.origin.x;
    CGFloat tabRight  = tabRect.origin.x + tabRect.size.width;
    CGFloat tabTop    = tabRect.origin.y;
    CGFloat tabBottom = tabRect.origin.y + tabRect.size.height;
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPathMoveToPoint(path, NULL, tabLeft, tabTop);
    // Top left
    CGPathAddArc(path, NULL, tabLeft, tabTop + kCornerRadius, kCornerRadius, -M_PI_2, 0, NO);
    CGPathAddLineToPoint(path, NULL, tabLeft + kCornerRadius, tabBottom - kCornerRadius);
    
    // Bottom left
    CGPathAddArc(path, NULL, tabLeft + 2*kCornerRadius, tabBottom - kCornerRadius, kCornerRadius, M_PI, M_PI_2, YES);
    CGPathAddLineToPoint(path, NULL, tabRight, tabBottom);
    CGPathAddLineToPoint(path, NULL, tabRight, tabTop);
    CGPathCloseSubpath(path);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // Fill with current tab color
    CGColorRef startColor = [self.tabColor CGColor];
    
    CGContextSetFillColorWithColor(ctx, startColor);
    CGContextSetShadow(ctx, CGSizeMake(0, -1), kShadowRadius);
    CGContextAddPath(ctx, path);
    CGContextFillPath(ctx);
    
    CGPathRelease(path);
    
}

@end
