//
//  SGProgressCircleView.m
//  Foxbrowser
//
//  Created by simon on 10.07.12.
//
//
//  Copyright (c) 2012-2013 Simon Grätzer
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

#import "SGProgressCircleView.h"

#define kSGProgressAnimationKey @"SGProgressAnimationKey"

@implementation SGProgressCircleView

- (id)init {
	self = [self initWithFrame:CGRectZero];	
	return self;
}

- (id) initWithFrame:(CGRect)frame {
	frame.size = CGSizeMake(40,40);
	if(!(self = [super initWithFrame:frame])) return nil;
	
	self.backgroundColor = [UIColor clearColor];
	self.userInteractionEnabled = NO;
	self.opaque = NO;
	
	return self;
}

- (void) drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGRect r = CGRectInset(rect, 7.5, 7.5);
    CGFloat c = 108./255.;
	CGContextSetRGBStrokeColor(context, c, c, c, 1.);
    CGContextSetLineWidth(context, 3.0);
    CGContextAddEllipseInRect(context, r);
	CGContextStrokePath(context);
	
	CGContextSetRGBFillColor(context, c, c, c, 1.);
    float start = (M_PI/2.0);
    
    CGContextAddArc(context, rect.size.width/2, rect.size.height/2, (rect.size.width/2)-7, start, start + (M_PI/2.0), false);
    CGContextAddLineToPoint(context, rect.size.width/2, rect.size.height/2);
    CGContextFillPath(context);
}

- (void)startAnimating {    
    CABasicAnimation* rotationAnimation = (CABasicAnimation *)[self.layer animationForKey:kSGProgressAnimationKey];
    if (!rotationAnimation) {
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = @(M_PI * 2.0);
        rotationAnimation.duration = 1.0;
        rotationAnimation.cumulative = NO;
        rotationAnimation.repeatCount = MAXFLOAT;
        rotationAnimation.autoreverses = NO;
        [self.layer addAnimation:rotationAnimation forKey:kSGProgressAnimationKey];
    }
}

- (void)stopAnimating {
    [self.layer removeAnimationForKey:kSGProgressAnimationKey];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    if (!hidden) [self startAnimating];
}

- (void)didMoveToSuperview {
    if (self.superview) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

@end
