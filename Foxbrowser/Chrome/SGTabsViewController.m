//
//  SGTabsViewController.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
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
@property (nonatomic, strong) SGToolbar *toolbar;


- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index;
- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index;

@end

@implementation SGTabsViewController {
    NSTimer *_timer;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return YES;
    else
        return UIInterfaceOrientationIsLandscape(interfaceOrientation);;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

    self.currentViewController.view.frame = self.contentFrame;
}

- (void)viewWillAppear:(BOOL)animated {
    self.currentViewController.view.frame = self.contentFrame;
    _timer = [NSTimer scheduledTimerWithTimeInterval:5
                                              target:self
                                            selector:@selector(saveCurrentURLs)
                                            userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [_timer invalidate];
    _timer = nil;
}

- (UIView *)rotatingHeaderView {
    return self.headerView;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    
    CGRect bounds = self.view.bounds;
    
    CGRect head = CGRectMake(0, 0, bounds.size.width, kTabsToolbarHeigth + kTabsHeigth);
    self.headerView = [[UIView alloc] initWithFrame:head];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.headerView.backgroundColor = [UIColor clearColor];
    
    CGRect frame = CGRectMake(0, 0, head.size.width, kTabsToolbarHeigth);
    _toolbar = [[SGToolbar alloc] initWithFrame:frame delegate:self];
    
    frame = CGRectMake(0, kTabsToolbarHeigth, head.size.width - kAddButtonWidth, kTabsHeigth);
    _tabsView = [[SGTabsView alloc] initWithFrame:frame];
    
    frame = CGRectMake(head.size.width - kAddButtonWidth, kTabsToolbarHeigth, kAddButtonWidth, kTabsHeigth - kTabsBottomMargin);
    _addButton = [[SGAddButton alloc] initWithFrame:frame];
    _addButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_addButton.button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerView addSubview:_tabsView];
    [self.headerView addSubview:_addButton];
    [self.headerView addSubview:_toolbar];
     
    [self.view addSubview:self.headerView];
}

- (void)viewDidLoad {
    self.tabsView.tabsController = self;
    self.delegate = self;
    
    NSArray *latest = [NSArray arrayWithContentsOfFile:[self savedURLs]];
    if (latest.count > 0) {
        for (NSString *urlString in latest) {
            [self addTabWithURL:[NSURL URLWithString:urlString] withTitle:urlString];
        }
    } else {
        SGBlankController *latest = [SGBlankController new];
        [self addViewController:latest];
    }
}

- (void)viewDidUnload {
    self.headerView = nil;
    self.toolbar = nil;
    self.tabsView = nil;
    self.addButton = nil;
}

- (NSString *)savedURLs {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"latestURLs.plist"];
    return path;
}

- (void)saveCurrentURLs {
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(q, ^{
        NSMutableArray *latest = [NSMutableArray arrayWithCapacity:self.count];
        for (UIViewController *controller in self.childViewControllers) {
            if ([controller isKindOfClass:[SGWebViewController class]]) {
                NSURL *url = ((SGWebViewController*)controller).location;
                [latest addObject:url.absoluteString];
            }
        }
        [latest writeToFile:[self savedURLs] atomically:YES];
    });
}

- (CGRect)contentFrame {
    CGRect head = self.headerView.frame;
    CGRect bounds = self.view.bounds;
    return CGRectMake(bounds.origin.x,
                      bounds.origin.y + head.size.height,
                      bounds.size.width,
                      bounds.size.height - head.size.height);
}

#pragma mark - Tab stuff

- (void)addViewController:(UIViewController *)viewController {
    viewController.view.frame = self.contentFrame;
    [self addChildViewController:viewController];
    
    if (!self.currentViewController) {
        [viewController.view setNeedsLayout];
        _currentViewController = viewController;
        [self.tabsView addTab:viewController];
        [self.view addSubview:viewController.view];
        self.tabsView.selected = 0;
        [viewController didMoveToParentViewController:self];
        return;
    }
    
    [UIView animateWithDuration:kAddTabDuration
                     animations:^{
                         [self.tabsView addTab:viewController];
                     }
                     completion:^(BOOL finished){
                         [viewController didMoveToParentViewController:self];
                     }];
}

- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index {
    if (viewController == self.currentViewController || [self.tabsView indexOfViewController:viewController] == NSNotFound)
        return;
    
    viewController.view.frame = self.contentFrame;
    [viewController.view setNeedsLayout];
    [self transitionFromViewController:self.currentViewController
                      toViewController:viewController
                              duration:0
                               options:0
                            animations:^{
                                self.tabsView.selected = index;
                            }
                            completion:^(BOOL finished) {
                                _currentViewController = viewController;
                                [self updateChrome];
                            }];
}

- (void)showIndex:(NSUInteger)index; {
    [self showViewController:[self.tabsView viewControllerAtIndex:index] index:index];
}

- (void)showViewController:(UIViewController *)viewController {
    [self showViewController:viewController index:[self.tabsView indexOfViewController:viewController]];
}

- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index {
    if (self.tabsView.tabs.count == 1) {// 0 shouldn't happen
        SGBlankController *latest = [SGBlankController new];
        [self swapCurrentViewControllerWith:latest];
        return;
    }
    
    NSUInteger newIndex = index;
    UIViewController *to;
    if (index == self.tabsView.tabs.count - 1) {
        newIndex--;
        to = [self.tabsView viewControllerAtIndex:newIndex];
    } else
        to  = [self.tabsView viewControllerAtIndex:newIndex+1];
    
    to.view.frame = self.contentFrame;
    [viewController willMoveToParentViewController:nil];
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
                                _currentViewController = to;
                                [self updateChrome];
                            }];
}

- (void)removeViewController:(UIViewController *)viewController {
    [self removeViewController:viewController index:[self.tabsView indexOfViewController:viewController]];
}

- (void)removeIndex:(NSUInteger)index {
    [self removeViewController:[self.tabsView viewControllerAtIndex:index] index:index];
}

- (void)swapCurrentViewControllerWith:(UIViewController *)viewController {
    if (![self.childViewControllers containsObject:viewController]) {
        [self addChildViewController:viewController];
        viewController.view.frame = self.contentFrame;

        UIViewController *old = self.currentViewController;
        NSUInteger index = [self.tabsView indexOfViewController:old];
        
        [old willMoveToParentViewController:nil];
        [self transitionFromViewController:old
                          toViewController:viewController 
                                  duration:0 
                                   options:UIViewAnimationOptionAllowAnimatedContent
                                animations:NULL
                                completion:^(BOOL finished){
                                    [old removeFromParentViewController];
                                    
                                    // Update tab content
                                    SGTabView *tab = [self.tabsView.tabs objectAtIndex:index];
                                    tab.viewController = viewController;
                                    tab.closeButton.hidden = ![self canRemoveTab:viewController];
                                    
                                    [viewController didMoveToParentViewController:self];
                                    _currentViewController = viewController;
                                    [self updateChrome];
                                }];
    }
}

#pragma mark - Propertys

- (NSUInteger)maxCount {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 10 : 4;
}

- (NSUInteger)count {
    return self.tabsView.tabs.count;
}

#pragma mark - SGBarDelegate

- (void)addTab; {
    if (self.count >= self.maxCount) {
        return;
    }
    SGBlankController *latest = [SGBlankController new];
    [self addViewController:latest];
    [self showViewController:latest];
}

- (void)addTabWithURL:(NSURL *)url withTitle:(NSString *)title;{
    SGWebViewController *webC = [[SGWebViewController alloc] initWithNibName:nil bundle:nil];
    webC.title = title;
    [webC openURL:url];
    [self addViewController:webC];
    if (self.count >= self.maxCount) {
        if (self.tabsView.selected != 0)
            [self removeIndex:0];
        else
            [self removeIndex:1];
    }
}

- (void)handleURLInput:(NSString*)input title:(NSString *)title {
    NSURL *url = [[WeaveOperations sharedOperations] parseURLString:input];
    if (!title) {
        title = [input stringByReplacingOccurrencesOfString:@"http://" withString:@""];
        title = [title stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    }
    
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        webC.title = title;
        [webC openURL:url];
    } else {
        SGWebViewController *webC = [[SGWebViewController alloc] initWithNibName:nil bundle:nil];
        webC.title = title;
        [webC openURL:url];
        [self swapCurrentViewControllerWith:webC];
    }
}

- (void)reload; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC reload];
        [self updateChrome];
    }
}

- (void)stop {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC.webView stopLoading];
        [self updateChrome];
    }
}

- (BOOL)isLoading {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return webC.loading;
    }
    return NO;
}

- (void)goBack; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC.webView goBack];
        [self updateChrome];
    }
}

- (void)goForward; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC.webView goForward];
        [self updateChrome];
    }
}

- (BOOL)canGoBack; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return [webC.webView canGoBack];
    }
    return NO;
}

- (BOOL)canGoForward; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return [webC.webView canGoForward];
    }
    return NO;
}

- (BOOL)canStopOrReload {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        return YES;
    }
    return NO;
}

- (NSURL *)URL {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return webC.location;
    }
    return nil;
}

- (void)updateChrome {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    [self.toolbar updateChrome];
}

- (BOOL)canRemoveTab:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[SGBlankController class]] && self.count == 1) {
        return NO;
    }
    return YES;
}

@end
