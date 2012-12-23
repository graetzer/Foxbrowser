//
//  SGPageViewController.h
//  SGPageController
//
//  Created by Simon Grätzer on 13.12.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "SGBrowserViewController.h"

@class SGPageToolbar;

@interface SGPageViewController : SGBrowserViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (readonly, nonatomic) UIScrollView *scrollView;
@property (readonly, nonatomic) SGPageToolbar *toolbar;
@property (readonly, nonatomic) UIPageControl *pageControl;
@property (assign, nonatomic) BOOL exposeMode;

@end
