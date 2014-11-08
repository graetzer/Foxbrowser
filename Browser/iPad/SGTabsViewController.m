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

- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index;
- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index;

@end

@implementation SGTabsViewController {
    __weak UIView *_headerView;
    __weak SGTabsView *_tabsView;
    __weak SGTabsToolbar *_toolbar;
}

#pragma mark - State Preservation and Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    
    
    NSUInteger c = _tabsView.tabs.count;
    [coder encodeInteger:c forKey:@"tabsCount"];
    for (NSUInteger i = 0; i < c; i++) {
        NSString *key = [NSString stringWithFormat:@"tab[%lud]", (unsigned long)i];
        UIViewController *vc = [_tabsView viewControllerAtIndex:i];
        [coder encodeObject:vc forKey:key];
    }
    
    [coder encodeInteger:[_tabsView selected] forKey:@"selected"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    
    NSUInteger c = [coder decodeIntegerForKey:@"tabsCount"];
    
    for (NSUInteger i = 0; i < c; i++) {
        NSString *key = [NSString stringWithFormat:@"tab[%lud]", (unsigned long)i];
        UIViewController *vc = [coder decodeObjectForKey:key];
        if (vc != nil) {
            [self addChildViewController:vc];
            [_tabsView addTab:vc];
            [vc didMoveToParentViewController:self];
        }
    }
    
    NSUInteger selected = [coder decodeIntegerForKey:@"selected"];
    [_tabsView setSelected:selected];
}


#pragma mark - View initialization

- (void)loadView {
    [super loadView];
        
    CGRect bounds = self.view.bounds;
    CGRect head = CGRectMake(0, 0, bounds.size.width, kSGToolbarHeight + kTabsHeigth);
    __strong UIView *header = [[UIView alloc] initWithFrame:head];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    header.backgroundColor = [UIColor blackColor];
    [self.view addSubview:header];
    _headerView = header;
    
    CGRect frame = CGRectMake(0, 0, head.size.width, kTabsHeigth);
    __strong SGTabsView *tabs = [[SGTabsView alloc] initWithFrame:frame];
    tabs.tabsController = self;
    [_headerView addSubview:tabs];
    _tabsView = tabs;
    
    frame = CGRectMake(0, kTabsHeigth, head.size.width, kSGToolbarHeight);
    __strong SGTabsToolbar *toolbar = [[SGTabsToolbar alloc] initWithFrame:frame browserDelegate:self];
    [_headerView addSubview:toolbar];
    _toolbar = toolbar;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.restorationIdentifier = NSStringFromClass([self class]);
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    
    // If the state was restored
    if ([self count] > 0) {
        UIViewController *vc = [self selectedViewController];
        if (vc.view.superview == nil) {
            [self.view addSubview:vc.view];
            [vc.view setNeedsLayout];
            // Get it to update the close button
            [_tabsView setSelected:[_tabsView selected]];
        }
    } else {
        [self loadSavedTabs];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat topOffset = 0;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        topOffset = self.topLayoutGuide.length;
    }
    CGRect b = self.view.bounds;
    _headerView.frame = CGRectMake(0, 0, b.size.width, kSGToolbarHeight + kTabsHeigth + topOffset);
    _tabsView.frame = CGRectMake(0, topOffset, b.size.width, kTabsHeigth);
    _toolbar.frame = CGRectMake(0, kTabsHeigth + topOffset, b.size.width, kSGToolbarHeight);
    self.selectedViewController.view.frame = [self _contentFrame];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? YES : UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (UIView *)rotatingHeaderView {
    return _headerView;
}

#pragma mark - Tab stuff

- (void)addViewController:(UIViewController *)childController {
    childController.view.frame = [self _contentFrame];
    [self addChildViewController:childController];
    
    if (_tabsView.tabs.count == 0) {
        [childController.view setNeedsLayout];
        [_tabsView addTab:childController];
        [self.view addSubview:childController.view];
        _tabsView.selected = 0;
        [childController didMoveToParentViewController:self];
        return;
    }
    
    [UIView transitionWithView:_tabsView
                      duration:kAddTabDuration
                       options:UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        [_tabsView addTab:childController];
                    }
                    completion:^(BOOL finished){
                        [childController didMoveToParentViewController:self];
                        [self updateInterface];
                    }];
}

- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index {
    UIViewController *current = [self selectedViewController];
    if (viewController == current || [_tabsView indexOfViewController:viewController] == NSNotFound)
        return;
    
    viewController.view.frame = [self _contentFrame];
    [viewController.view setNeedsLayout];
    [self transitionFromViewController:current
                      toViewController:viewController
                              duration:0
                               options:0
                            animations:^{
                                _tabsView.selected = index;
                            }
                            completion:^(BOOL finished) {
                                [self updateInterface];
                            }];
}

- (void)showViewController:(UIViewController *)viewController {
    [self showViewController:viewController index:[_tabsView indexOfViewController:viewController]];
}

- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index {
    if (_tabsView.tabs.count <= 1) {// 0 shouldn't happen
        UIViewController *viewC = [self createNewTabViewController];
        [self swapCurrentViewControllerWith:viewC];
        return;
    }
    
    [viewController willMoveToParentViewController:nil];
    if (index == self.selectedIndex) {
        NSUInteger newIndex = index;
        UIViewController *to;
        if (index == _tabsView.tabs.count - 1) {
            newIndex--;
            to = [_tabsView viewControllerAtIndex:newIndex];
        } else to  = [_tabsView viewControllerAtIndex:newIndex+1];
        
        to.view.frame = [self _contentFrame];
        [self transitionFromViewController:viewController
                          toViewController:to
                                  duration:kRemoveTabDuration
                                   options:UIViewAnimationOptionAllowAnimatedContent
                                animations:^{
                                    [_tabsView removeTab:index];
                                    _tabsView.selected = newIndex;
                                }
                                completion:^(BOOL finished){
                                    [viewController removeFromParentViewController];
                                    [self updateInterface];
                                }];
    } else {
        [UIView transitionWithView:_tabsView
                          duration:kRemoveTabDuration
                           options:UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
                            [_tabsView removeTab:index];
                        }
                        completion:^(BOOL finished){
                            [viewController.view removeFromSuperview];//Just in case
                            [viewController removeFromParentViewController];
                            [self updateInterface];
                        }];
    }
}

- (void)removeViewController:(UIViewController *)viewController {
    [self removeViewController:viewController index:[_tabsView indexOfViewController:viewController]];
}

- (void)removeIndex:(NSUInteger)index {
    [self removeViewController:[_tabsView viewControllerAtIndex:index] index:index];
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
                                    SGTabView *tab = (_tabsView.tabs)[index];
                                    tab.viewController = viewController;
                                    tab.closeButton.hidden = ![self canRemoveTab:viewController];
                                    
                                    [viewController didMoveToParentViewController:self];
                                    [self updateInterface];
                                }];
    }
}

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {
    return index < _tabsView.tabs.count ? [_tabsView viewControllerAtIndex:index] : nil;
}

- (UIViewController *)selectedViewController {
    return self.count > 0 ? [_tabsView viewControllerAtIndex:_tabsView.selected] : nil;
}

- (NSUInteger)selectedIndex {
    return _tabsView.selected;
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    if (selectedIndex < _tabsView.tabs.count) {
        [self showViewController:[_tabsView viewControllerAtIndex:selectedIndex] index:selectedIndex];
    }
}

- (NSUInteger)maxCount {
    return 10;
}

- (NSUInteger)count {
    return _tabsView.tabs.count;
}

- (void)updateInterface {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    [_toolbar updateInterface];
}

- (BOOL)canRemoveTab:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[SGBlankController class]] && self.count == 1) {
        return NO;
    }
    return YES;
}

#pragma mark - Utility

- (CGRect)_contentFrame {
    CGRect head = _headerView.frame;
    CGRect bounds = self.view.bounds;
    return CGRectMake(bounds.origin.x,
                      bounds.origin.y + head.size.height,
                      bounds.size.width,
                      bounds.size.height - head.size.height);
}

@end
