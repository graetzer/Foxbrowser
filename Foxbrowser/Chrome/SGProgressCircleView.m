//
//  TKProgressCircleView.m
//  Created by Devin Ross on 1/1/11.
//
/*
 
 tapku.com || http://github.com/devinross/tapkulibrary
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "SGProgressCircleView.h"

#define AnimationTimer 0.015
#define AnimationIncrement 0.02

@implementation SGProgressCircleView

- (id) init{
	self = [self initWithFrame:CGRectZero];	
	return self;
}

- (id) initWithFrame:(CGRect)frame {
	frame.size = CGSizeMake(40,40);
	if(!(self = [super initWithFrame:frame])) return nil;
	
	self.backgroundColor = [UIColor clearColor];
	self.userInteractionEnabled = NO;
	self.opaque = NO;
	_running = NO;
	
	return self;
}

- (void) drawRect:(CGRect)rect {

	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGRect r = CGRectInset(rect, 7.5, 7.5);
	
	CGContextSetRGBStrokeColor(context, 108./255., 115./255., 122./255, 1.0);
    CGContextSetLineWidth(context, 3.0);
    CGContextAddEllipseInRect(context, r);
	CGContextStrokePath(context);
	
	
	CGContextSetRGBFillColor(context, 108./255., 115./255., 122./255 ,1);
    float start = (M_PI*2.0 *_displayProgress) - (M_PI/2.0);
    
    CGContextAddArc(context, rect.size.width/2, rect.size.height/2, (rect.size.width/2)-7, start, start + (M_PI/2.0), false);
    CGContextAddLineToPoint(context, rect.size.width/2, rect.size.height/2);
    CGContextFillPath(context);
}


- (void) updateTwirl{
	if(!_running) return;
	
	_displayProgress += AnimationIncrement;
	[self setNeedsDisplay];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTwirl) object:nil];
	[self performSelector:@selector(updateTwirl) withObject:nil afterDelay:AnimationTimer];
	
}

- (void)startAnimating {
    _running = YES;
    [self updateTwirl];
}

- (void)stopAnimating {
    _running = NO;
}

- (void)didMoveToSuperview {
    if (self.superview) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

@end
