//
//  SGPageToolbar.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 17.12.12.
//  Copyright (c) 2012 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SGSearchController.h"

@class SGSearchField, SGSearchController, SGPageViewController;

@interface SGPageToolbar : UIView <UITextFieldDelegate, SGSearchDelegate>
@property (readonly, nonatomic) SGSearchField *searchField;
@property (readonly, nonatomic) SGSearchController *searchController;

@property (readonly, nonatomic) UIButton *tabsButton;
@property (readonly, nonatomic) UIButton *backButton;

@property (weak, nonatomic) SGPageViewController *browser;

- (id)initWithFrame:(CGRect)frame browser:(SGPageViewController *)browser;
- (void)updateChrome;
@end
