//
//  SGPageToolbar.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 17.12.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SGToolbarView.h"
#import "SGSearchViewController.h"

@class SGSearchField, SGSearchViewController, SGPageViewController;

@interface SGPageToolbar : SGToolbarView

@property (weak, readonly, nonatomic) UIButton *tabsButton;
@property (weak, readonly, nonatomic) UIButton *cancelButton;

- (instancetype)initWithFrame:(CGRect)frame browserDelegate:(SGBrowserViewController *)browser;
- (void)updateInterface;
- (void)setSubviewsAlpha:(CGFloat)alpha;
@end
