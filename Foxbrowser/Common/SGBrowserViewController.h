//
//  SGBrowserViewController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 15.12.12.
//  Copyright (c) 2012 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

// Container for SGWebViewController & SGBlankViewController
@interface SGBrowserViewController : UIViewController

// =========== Abstract =============

/// Adds a tab, don't add the same instance twice!
- (void)addViewController:(UIViewController *)viewController;

/// Bring a tab to the frontpage
- (void)showViewController:(UIViewController *)viewController;

// Remove a tap
- (void)removeViewController:(UIViewController *)childController;
- (void)removeIndex:(NSUInteger)index;

// Swap the current view controller. Used to replace the blankView with the webView
- (void)swapCurrentViewControllerWith:(UIViewController *)viewController;

- (void)updateChrome;

- (UIViewController *)selectedViewController;
- (NSUInteger)selected;

- (NSUInteger)count;
- (NSUInteger)maxCount;

// ========== Implemented =================

// Add and show a SGBlankViewController
- (void)addTab;

- (void)addTabWithURL:(NSURL *)url withTitle:(NSString *)title;

- (void)reload;
- (void)stop;

- (BOOL)isLoading;

- (void)goBack;
- (void)goForward;

- (BOOL)canGoBack;
- (BOOL)canGoForward;

- (NSURL *)URL;

- (BOOL)canStopOrReload;
- (void)handleURLInput:(NSString*)input title:(NSString *)title;
- (BOOL)canRemoveTab:(UIViewController *)viewController;

- (void)addSavedTabs;
- (void)saveCurrentTabs;

@end
