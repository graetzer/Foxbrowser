//
//  SGTabsViewController.m
//  SGTabs
//
//  Created by simon on 07.06.12.
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

#import "SGTabsViewController.h"
#import "SGTabsToolbar.h"
#import "SGTabsView.h"
#import "SGTabView.h"
#import "SGAddButton.h"
#import "SGTabDefines.h"
#import "SGWebViewController.h"
#import "UIWebView+WebViewAdditions.h"
#import "SGBlankController.h"



@interface SGTabsViewController ()
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) SGTabsView *tabsView;
@property (nonatomic, strong) SGAddButton *addButton;
@property (nonatomic, strong) SGTabsToolbar *toolbar;


- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index;
- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index;

@end

@implementation SGTabsViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? YES : UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (UIView *)rotatingHeaderView {
    return self.headerView;
}

- (void)loadView {
    [super loadView];
    
    
    CGRect bounds = self.view.bounds;
    CGRect head = CGRectMake(0, 0, bounds.size.width, kSGToolbarHeight + kTabsHeigth);
    self.headerView = [[UIView alloc] initWithFrame:head];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.headerView.backgroundColor = [UIColor clearColor];
    
    CGRect frame = CGRectMake(0, 0, head.size.width - kAddButtonWidth, kTabsHeigth);
    _tabsView = [[SGTabsView alloc] initWithFrame:frame];
    
    frame = CGRectMake(head.size.width - kAddButtonWidth, 0, kAddButtonWidth, kTabsHeigth);
    _addButton = [[SGAddButton alloc] initWithFrame:frame];
    _addButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_addButton.button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchUpInside];
    
    frame = CGRectMake(0, kTabsHeigth, head.size.width, kSGToolbarHeight);
    _toolbar = [[SGTabsToolbar alloc] initWithFrame:frame browser:self];
    
    [self.headerView addSubview:_toolbar];
    [self.headerView addSubview:_tabsView];
    [self.headerView addSubview:_addButton];
    [self.view addSubview:self.headerView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = kSGBrowserBackgroundColor;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
    
    self.tabsView.tabsController = self;
    [self loadSavedTabs];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.headerView = nil;
    self.toolbar = nil;
    self.tabsView = nil;
    self.addButton = nil;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CGFloat topOffset = 0;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        topOffset = self.topLayoutGuide.length;
    }
    CGRect b = self.view.bounds;
    _headerView.frame = CGRectMake(0, 0, b.size.width, kSGToolbarHeight + kTabsHeigth + topOffset);
    _tabsView.frame = CGRectMake(0, topOffset, b.size.width - kAddButtonWidth, kTabsHeigth);
    _addButton.frame = CGRectMake(b.size.width - kAddButtonWidth, topOffset, kAddButtonWidth, kTabsHeigth);
    _toolbar.frame = CGRectMake(0, kTabsHeigth + topOffset, b.size.width, kSGToolbarHeight);
    self.selectedViewController.view.frame = [self _contentFrame];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - Tab stuff

- (void)addViewController:(UIViewController *)childController {
    childController.view.frame = [self _contentFrame];
    [self addChildViewController:childController];
    
    if (self.tabsView.tabs.count == 0) {
        [childController.view setNeedsLayout];
        [self.tabsView addTab:childController];
        [self.view addSubview:childController.view];
        self.tabsView.selected = 0;
        [childController didMoveToParentViewController:self];
        return;
    }
    
    [UIView transitionWithView:self.tabsView
                      duration:kAddTabDuration
                       options:UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        [self.tabsView addTab:childController];
                    }
                    completion:^(BOOL finished){
                        [childController didMoveToParentViewController:self];
                    }];
}

- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index {
    UIViewController *current = [self selectedViewController];
    if (viewController == current || [self.tabsView indexOfViewController:viewController] == NSNotFound)
        return;
    
    viewController.view.frame = [self _contentFrame];
    [viewController.view setNeedsLayout];
    [self transitionFromViewController:current
                      toViewController:viewController
                              duration:0
                               options:0
                            animations:^{
                                self.tabsView.selected = index;
                            }
                            completion:^(BOOL finished) {
                                [self updateInterface];
                            }];
}

- (void)showViewController:(UIViewController *)viewController {
    [self showViewController:viewController index:[self.tabsView indexOfViewController:viewController]];
}

- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index {
    if (self.tabsView.tabs.count <= 1) {// 0 shouldn't happen
        UIViewController *viewC = [self createNewTabViewController];
        [self swapCurrentViewControllerWith:viewC];
        return;
    }
    
    [viewController willMoveToParentViewController:nil];
    if (index == self.selectedIndex) {
        NSUInteger newIndex = index;
        UIViewController *to;
        if (index == self.tabsView.tabs.count - 1) {
            newIndex--;
            to = [self.tabsView viewControllerAtIndex:newIndex];
        } else to  = [self.tabsView viewControllerAtIndex:newIndex+1];
        
        to.view.frame = [self _contentFrame];
        [self transitionFromViewController:viewController
                          toViewController:to
                                  duration:kRemoveTabDuration
                                   options:UIViewAnimationOptionAllowAnimatedContent
                                animations:^{
                                    [self.tabsView removeTab:index];
                                    self.tabsView.selected = newIndex;
                                }
                                completion:^(BOOL finished){
                                    [viewController removeFromParentViewController];
                                    [self updateInterface];
                                }];
    } else {
        [UIView transitionWithView:self.tabsView
                          duration:kRemoveTabDuration
                           options:UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
                            [self.tabsView removeTab:index];
                        }
                        completion:^(BOOL finished){
                            [viewController.view removeFromSuperview];//Just in case
                            [viewController removeFromParentViewController];
                            [self updateInterface];
                        }];
    }
}

- (void)removeViewController:(UIViewController *)viewController {
    [self removeViewController:viewController index:[self.tabsView indexOfViewController:viewController]];
}

- (void)removeIndex:(NSUInteger)index {
    [self removeViewController:[self.tabsView viewControllerAtIndex:index] index:index];
}

- (void)swapCurrentViewControllerWith:(UIViewController *)viewController {
    UIViewController *old = [self selectedViewController];
    
    if (!old) {
        [self addViewController:viewController];
    } else if (![self.childViewControllers containsObject:viewController]) {
        viewController.view.frame = [self _contentFrame];
        [self addChildViewController:viewController];
        NSUInteger index = [self selectedIndex];
        
        [old willMoveToParentViewController:nil];
        [self transitionFromViewController:old
                          toViewController:viewController 
                                  duration:0 
                                   options:UIViewAnimationOptionAllowAnimatedContent
                                animations:NULL
                                completion:^(BOOL finished){
                                    [old removeFromParentViewController];
                                    
                                    // Update tab content
                                    SGTabView *tab = (self.tabsView.tabs)[index];
                                    tab.viewController = viewController;
                                    tab.closeButton.hidden = ![self canRemoveTab:viewController];
                                    
                                    [viewController didMoveToParentViewController:self];
                                    [self updateInterface];
                                }];
    }
}

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {
    return index < self.tabsView.tabs.count ? [self.tabsView viewControllerAtIndex:index] : nil;
}

- (UIViewController *)selectedViewController {
    return self.count > 0 ? [self.tabsView viewControllerAtIndex:self.tabsView.selected] : nil;
}

- (NSUInteger)selectedIndex {
    return self.tabsView.selected;
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    if (selectedIndex < self.tabsView.tabs.count) {
        [self showViewController:[self.tabsView viewControllerAtIndex:selectedIndex] index:selectedIndex];
    }
}

- (NSUInteger)maxCount {
    return 10;
}

- (NSUInteger)count {
    return self.tabsView.tabs.count;
}

- (void)updateInterface {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    [self.toolbar updateInterface];
}

- (BOOL)canRemoveTab:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[SGBlankController class]] && self.count == 1) {
        return NO;
    }
    return YES;
}

#pragma mark - Utility

- (CGRect)_contentFrame {
    CGRect head = self.headerView.frame;
    CGRect bounds = self.view.bounds;
    return CGRectMake(bounds.origin.x,
                      bounds.origin.y + head.size.height,
                      bounds.size.width,
                      bounds.size.height - head.size.height);
}

@end
