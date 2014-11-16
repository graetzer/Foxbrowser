//
//  SGAddView.m
//  Foxbrowser
//
//  Created by simon on 16.07.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import "SGAddButton.h"
#import "SGTabDefines.h"
#import <math.h>

@implementation SGAddButton {
    UIColor *_tabColor;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _tabColor = UIColorFromHEX(0xC0C0C0);
        self.backgroundColor = [UIColor clearColor];
        
        self.button = [UIButton buttonWithType:UIButtonTypeCustom];
        //[self.button setImage:[UIImage imageNamed:@"plus-gray"] forState:UIControlStateNormal];
        self.button.showsTouchWhenHighlighted = YES;
        self.button.frame = self.bounds;//CGRectMake(kCornerRadius, 0, self.bounds.size.width - kCornerRadius*2, self.bounds.size.height);
        [self addSubview:self.button];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGRect  tabRect   = self.bounds;
    CGFloat tabLeft   = tabRect.origin.x;
    CGFloat tabRight  = tabRect.origin.x + tabRect.size.width;
    CGFloat tabTop    = tabRect.origin.y + kCornerRadius;
    CGFloat tabBottom = tabRect.origin.y + tabRect.size.height - kCornerRadius;
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPathMoveToPoint(path, NULL, tabLeft+kCornerRadius, tabBottom);
    // Bottom left
    CGPathAddArc(path, NULL, tabLeft+kCornerRadius, tabBottom - kCornerRadius, kCornerRadius, M_PI_2, -M_PI, NO);
    CGPathAddLineToPoint(path, NULL, tabLeft, tabTop + kCornerRadius);
    
    // Top left
    CGPathAddArc(path, NULL, tabLeft + kCornerRadius, tabTop + kCornerRadius, kCornerRadius, M_PI, -M_PI_2, NO);
    CGPathAddLineToPoint(path, NULL, tabRight - kCornerRadius, tabTop);
    
    // Top rigth
    CGPathAddArc(path, NULL, tabRight - kCornerRadius, tabTop + kCornerRadius, kCornerRadius, M_PI_2, 0, NO);
    
    // Bottom rigth
    CGPathAddArc(path, NULL, tabRight - kCornerRadius, tabBottom - kCornerRadius, kCornerRadius, 0, M_PI_2, NO);
    CGPathCloseSubpath(path);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // Fill with current tab color
    CGColorRef startColor = _tabColor.CGColor;
    
    CGContextSetFillColorWithColor(ctx, startColor);
    CGContextSetShadow(ctx, CGSizeMake(0, -1), kShadowRadius);
    CGContextAddPath(ctx, path);
    CGContextFillPath(ctx);
    
    CGPathRelease(path);
}

@end
