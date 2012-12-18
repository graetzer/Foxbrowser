//
//  SGBlankToolbar.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 30.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGBottomView.h"
#import "SGBlankController.h"

@implementation SGBottomView
@dynamic markerPosititon;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        self.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        
        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo"]];
        
        logoView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        logoView.frame = CGRectMake(10., (frame.size.height - 50.)/2, 50., 50.);
        [self addSubview:logoView];
        
        NSString *text = @"Foxbrowser";
        UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:20.];
        CGSize size = [text sizeWithFont:font];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(70., (frame.size.height - size.height)/2, size.width, size.height)];
        label.autoresizingMask =  UIViewAutoresizingFlexibleRightMargin;
        label.backgroundColor = [UIColor clearColor];
        label.font = font;
        label.textAlignment = UITextAlignmentCenter;
        label.text = text;
        [self addSubview:label];
        
        font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17.];
        text = NSLocalizedString(@"Most popular", @"Most popular websites");
        size = [text sizeWithFont:font];
        NSString *text2 = NSLocalizedString(@"Other devices", @"Tabs of other devices");
        CGSize size2 = [text2 sizeWithFont:font];
        CGFloat labelWidth = MAX(size.width, size2.width);
        
        CGRect gRect = CGRectMake(frame.size.width/2 - labelWidth, 0, 2*labelWidth + 40, frame.size.height);
        UIView *group = [[UIView alloc] initWithFrame:gRect];
        group.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        group.backgroundColor = [UIColor clearColor];
        [self addSubview:group];
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(10., (gRect.size.height - size.height)/2, labelWidth, size.height)];
        label.backgroundColor = [UIColor clearColor];
        label.font = font;
        label.text = text;
        label.textAlignment = UITextAlignmentCenter;
        [group addSubview:label];
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(gRect.size.width/2 + 10.,
                                                                   (gRect.size.height - size2.height)/2, labelWidth, size2.height)];
        label.backgroundColor = [UIColor clearColor];
        label.font = font;
        label.text = text2;
        label.textAlignment = UITextAlignmentCenter;
        [group addSubview:label];
        
       
        CGRect f = CGRectMake(0, 0, labelWidth + 20., gRect.size.height);
        _marker = [[UIView alloc] initWithFrame:f];
        _marker.backgroundColor = [UIColor colorWithRed:0.1 green:0.2 blue:0.9 alpha:0.4];
        _marker.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [group addSubview:_marker];
        
        UITapGestureRecognizer *tapG = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [group addGestureRecognizer:tapG];
        
        [self addSubview:group];
    }
    return self;
}

- (void)setMarkerPosititon:(CGFloat)posititon {
    CGFloat width = self.marker.bounds.size.width;
    CGRect newF = CGRectMake(width*posititon, 0, width, self.bounds.size.height);
    self.marker.frame = newF;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(contextRef, 2.5);
    CGContextSetRGBStrokeColor(contextRef, 0., 0., 0.5, 1.0);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, 0);
    CGPathAddLineToPoint(path, NULL, self.bounds.size.width, 0.);
    CGContextAddPath(contextRef, path);
    CGContextStrokePath(contextRef);
    CGPathRelease(path);
}

- (IBAction)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        UIView *group = sender.view;
        CGPoint location = [sender locationInView:group];
        if (location.x > group.bounds.size.width/2) {
            [self.container.scrollView setContentOffset:CGPointMake(SG_TAB_WIDTH, 0) animated:YES];
        } else if (location.x > 0) {
            [self.container.scrollView setContentOffset:CGPointMake(0, 0) animated:YES];
        }
    }
}

@end
