//
//  SGToolbarView.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 07.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SGSearchViewController.h"
@class SGBrowserViewController, SGSearchField, NJKWebViewProgressView;

/*! Common superclass for the device specific toolbars */
@interface SGToolbarView : UIView <UITextFieldDelegate, SGSearchDelegate>


@property (weak, nonatomic) SGBrowserViewController *browser;
@property (weak, readonly, nonatomic) UIButton *backButton;
@property (weak, readonly, nonatomic) UIButton *forwardButton;
@property (weak, readonly, nonatomic) UIButton *menuButton;

@property (weak, nonatomic) NJKWebViewProgressView *progressView;

@property (strong, nonatomic, readonly) UINavigationController *bookmarks;

@property (weak, readonly, nonatomic) SGSearchField *searchField;
@property (strong, readonly, nonatomic) SGSearchViewController *searchController;

- (instancetype)initWithFrame:(CGRect)frame browserDelegate:(SGBrowserViewController *)browser;

- (IBAction)showBrowserMenu:(id)sender;
/*! Update the searchfield and the progress */
- (void)updateInterface;

- (void)presentSearchController;
- (void)presentMenuController:(UIViewController *)vc completion:(void(^)(void))completion;
- (void)dismissPresented;

@end
