//
//  SGPageViewController.h
//  SGPageController
//
//  Created by Simon Grätzer on 13.12.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "SGBrowserViewController.h"

@class SGPageToolbar;

@interface SGPageViewController : SGBrowserViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (weak, readonly, nonatomic) SGPageToolbar *toolbar;
@property (weak, readonly, nonatomic) UIScrollView *scrollView;
@property (weak, readonly, nonatomic) UIPageControl *pageControl;
@property (weak, readonly, nonatomic) UIButton *closeButton;
@property (weak, readonly, nonatomic) UIButton *addTabButton;
@property (weak, readonly, nonatomic) UIButton *menuButton;
@property (weak, readonly, nonatomic) UIButton *tabsButton;
@property (weak, readonly, nonatomic) UILabel *titleLabel;
@property (assign, nonatomic) BOOL exposeMode;

- (void)setExposeMode:(BOOL)exposeMode animated:(BOOL)animated;
@end
