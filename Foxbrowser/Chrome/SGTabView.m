//
//  SGTabView.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SGTabView.h"
#import "SGTabDefines.h"

#import <math.h>

@interface SGTabView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIColor *tabColor;
@property (nonatomic, strong) UIColor *tabDarkerColor;
@end

@implementation SGTabView
@synthesize titleLabel, closeButton;
@synthesize tabColor;
@dynamic title;

- (id)initWithFrame:(CGRect)frame title:(NSString *)title
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.tabColor = kTabColor;
        self.tabDarkerColor = kTabDarkerColor;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        self.exclusiveTouch = YES;
        _cap = 2*kCornerRadius/frame.size.width;
        self.contentStretch = CGRectMake(_cap, 0., 1.-_cap, 1.);
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.titleLabel.textAlignment = UITextAlignmentCenter;
        self.titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
        self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:14.0];
        self.titleLabel.minimumFontSize = 14.0;
        self.titleLabel.textColor = [UIColor darkGrayColor];
        self.titleLabel.shadowColor = [UIColor colorWithWhite:0.6 alpha:0.5];
        self.titleLabel.shadowOffset = CGSizeMake(0, 0.5);
        self.title = title;
        [self addSubview:self.titleLabel];
        
        self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        
        [self.closeButton setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
        [self.closeButton setTitle:@"x" forState:UIControlStateNormal];
        [self.closeButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [self.closeButton setShowsTouchWhenHighlighted:YES];
        self.closeButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:17.0];
        [self  addSubview:self.closeButton];
    }
    return self;
}

- (void)layoutSubviews {
    CGRect b = self.bounds;
    CGFloat margin = kCornerRadius;
    
    CGSize t = _tSize;
    if (t.width > b.size.width*0.75) {
        t.width = b.size.width*0.75 - 2*margin;
    }
        
    if(!self.closeButton.hidden) {
        self.titleLabel.frame = CGRectMake((b.size.width - t.width)/2 + margin,
                                           (b.size.height - t.height)/2,
                                           t.width, t.height);
    } else {
        self.titleLabel.frame = CGRectMake((b.size.width - t.width)/2,
                                           (b.size.height - t.height)/2,
                                           t.width, t.height);
    }
    
    self.closeButton.frame =  CGRectMake(margin, 0, 25, b.size.height);
}

- (void)setTitle:(NSString *)title {
    self.titleLabel.text = title;
    _tSize = [self.titleLabel.text sizeWithFont:self.titleLabel.font];
}

- (NSString *)title {
    return self.titleLabel.text;
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
    CGPathAddLineToPoint(path, NULL, tabRight - 2*kCornerRadius, tabBottom);
    
    // Bottom rigth
    CGPathAddArc(path, NULL, tabRight - 2*kCornerRadius, tabBottom - kCornerRadius, kCornerRadius, M_PI_2, 0, YES);
    CGPathAddLineToPoint(path, NULL, tabRight - kCornerRadius, tabTop + kCornerRadius);
    
    // Top rigth
    CGPathAddArc(path, NULL, tabRight, tabTop + kCornerRadius, kCornerRadius, M_PI, -M_PI_2, NO);
    CGPathAddLineToPoint(path, NULL, tabRight, tabTop);
    CGPathCloseSubpath(path);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // Fill with current tab color
    CGColorRef startColor = self.alpha < 1. ? self.tabDarkerColor.CGColor : self.tabColor.CGColor;
    
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    CGContextSetFillColorWithColor(ctx, startColor);
    CGContextSetShadow(ctx, CGSizeMake(0, -1), kShadowRadius);
    CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
    
    CGPathRelease(path);
    
}

@end
