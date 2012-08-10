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
#import "SGAddView.h"
#import "SGTabDefines.h"
#import "SGWebViewController.h"
#import "UIWebView+WebViewAdditions.h"
#import "SGBlankController.h"

@interface SGTabsViewController ()
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) SGTabsView *tabsView;
@property (nonatomic, strong) SGAddView *addButton;
@property (nonatomic, strong) SGToolbar *toolbar;


- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index;
- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index;

@end

@implementation SGTabsViewController
@synthesize delegate;
@synthesize tabContents = _tabContents, currentViewController = _currentViewController;
@synthesize headerView = _headerView, tabsView = _tabsView, addButton = _addButton, toolbar = _toolbar;
@synthesize contentFrame = _contentFrame;

- (id)init {
    if (self = [super initWithNibName:nil bundle:nil]) {
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return YES;
    else
        return UIInterfaceOrientationIsLandscape(interfaceOrientation);;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    CGRect head = self.headerView.frame;
    CGRect bounds = self.view.bounds;
    _contentFrame = CGRectMake(bounds.origin.x,
                               bounds.origin.y + head.size.height,
                               bounds.size.width,
                               bounds.size.height - head.size.height);
    self.currentViewController.view.frame = self.contentFrame;
}

- (UIView *)rotatingHeaderView {
    return self.headerView;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    
    CGRect bounds = self.view.bounds;
    
    CGRect head = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, kTabsToolbarHeigth + kTabsHeigth);
    self.headerView = [[UIView alloc] initWithFrame:head];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    CGRect frame = CGRectMake(head.origin.x, head.origin.y, head.size.width, kTabsToolbarHeigth);
    _toolbar = [[SGToolbar alloc] initWithFrame:frame delegate:self];
    
    frame = CGRectMake(head.origin.x, kTabsToolbarHeigth, head.size.width - kAddButtonWidth, kTabsHeigth);
    _tabsView = [[SGTabsView alloc] initWithFrame:frame];
    
    frame = CGRectMake(head.origin.x + frame.size.width, kTabsToolbarHeigth, kAddButtonWidth, kTabsHeigth - kTabsBottomMargin);
    _addButton = [[SGAddView alloc] initWithFrame:frame];
    _addButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_addButton.button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerView addSubview:_toolbar];
    [self.headerView addSubview:_tabsView];
    [self.headerView addSubview:_addButton];
     
    [self.view addSubview:self.headerView];
    
    _contentFrame = CGRectMake(bounds.origin.x,
                               bounds.origin.y + head.size.height,
                               bounds.size.width,
                               bounds.size.height - head.size.height);
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
        [self addTab:latest];
    }
}

- (void)viewDidUnload {
    self.headerView = nil;
    self.toolbar = nil;
    self.tabsView = nil;
    self.addButton = nil;
}

- (void)saveCurrentURLs {
    NSMutableArray *latest = [NSMutableArray arrayWithCapacity:self.count];
    for (UIViewController *controller in self.childViewControllers) {
        if ([controller isKindOfClass:[SGWebViewController class]]) {
            NSURL *url = ((SGWebViewController*)controller).request.URL;
            [latest addObject:url.absoluteString];
        }
    }
    [latest writeToFile:[self savedURLs] atomically:NO];
}

- (NSString *)savedURLs {
    NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"latestURLs.plist"];
    return path;
}

#pragma mark - Tab stuff

- (void)addTab:(UIViewController *)viewController {
    viewController.view.frame = self.contentFrame;
    [self addChildViewController:viewController];
    [self.tabContents addObject:viewController];
    [viewController addObserver:self
                     forKeyPath:@"title"
                        options:NSKeyValueObservingOptionNew
                        context:NULL];
    
    if (!self.currentViewController) {
        _currentViewController = viewController;
        [self.tabsView addTab:viewController.title];
        [self.view addSubview:viewController.view];
        self.tabsView.selected = 0;
        [viewController didMoveToParentViewController:self];
        return;
    }
    
    [UIView animateWithDuration:kAddTabDuration
                     animations:^{
                         [self.tabsView addTab:viewController.title];
                     }
                     completion:^(BOOL finished){
                         [viewController didMoveToParentViewController:self];
                     }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"title"]) {
        NSUInteger index = [self.tabContents indexOfObject:object];
        SGTabView *tab = [self.tabsView.tabs objectAtIndex:index];
        [tab setTitle:[object title]];
        [tab setNeedsLayout];
    }
}

- (void)showViewController:(UIViewController *)viewController index:(NSUInteger)index {
    if (viewController == self.currentViewController 
        || ![self.tabContents containsObject:viewController]) {
        return;
    }
    
    viewController.view.frame = self.contentFrame;
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
    UIViewController *viewController = [self.tabContents objectAtIndex:index];
    [self showViewController:viewController index:index];
}

- (void)showViewController:(UIViewController *)viewController {
    NSUInteger index = [self.tabContents indexOfObject:viewController];
    [self showViewController:viewController index:index];
}

- (void)removeViewController:(UIViewController *)viewController index:(NSUInteger)index {
    if (self.tabContents.count == 1) {
        SGBlankController *latest = [SGBlankController new];
        [self swapCurrentViewControllerWith:latest];
        return;
    }
    
    NSUInteger oldIndex = index;
    [self.tabContents removeObjectAtIndex:oldIndex];
    [viewController willMoveToParentViewController:nil];
    [viewController removeObserver:self forKeyPath:@"title"];
    if (oldIndex >= self.tabContents.count) {
        index = self.tabContents.count-1;
    }
    
    UIViewController *to = [self.tabContents objectAtIndex:index];
    to.view.frame = self.contentFrame;
    
    [self transitionFromViewController:viewController
                      toViewController:to
                              duration:kRemoveTabDuration 
                               options:UIViewAnimationOptionAllowAnimatedContent
                            animations:^{
                                [self.tabsView removeTab:oldIndex];
                                self.tabsView.selected = index;
                            }
                            completion:^(BOOL finished){
                                [viewController removeFromParentViewController];
                                _currentViewController = to;
                                [self updateChrome];
                            }];
}

- (void)removeViewController:(UIViewController *)viewController {
    NSUInteger index = [self.tabContents indexOfObject:viewController];
    [self removeViewController:viewController index:index];
}

- (void)removeIndex:(NSUInteger)index {
    UIViewController *viewController = [self.tabContents objectAtIndex:index];
    [self removeViewController:viewController index:index];
}

- (void)swapCurrentViewControllerWith:(UIViewController *)viewController {
    if (![self.childViewControllers containsObject:viewController]) {
        [self addChildViewController:viewController];
        viewController.view.frame = self.contentFrame;
        [viewController addObserver:self
                         forKeyPath:@"title"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];
        
        UIViewController *old = self.currentViewController;
        [old willMoveToParentViewController:nil];
        [old removeObserver:self forKeyPath:@"title"];
        NSUInteger index = [self.tabContents indexOfObject:old];
        [self.tabContents replaceObjectAtIndex:index withObject:viewController];
        
        _currentViewController = viewController;
        [self transitionFromViewController:old
                          toViewController:viewController 
                                  duration:0 
                                   options:UIViewAnimationOptionAllowAnimatedContent
                                animations:NULL
                                completion:^(BOOL finished){
                                    [old removeFromParentViewController];
                                    [viewController didMoveToParentViewController:self];
                                    
                                    // Update tab content
                                    SGTabView *tab = [self.tabsView.tabs objectAtIndex:index];
                                    [tab setTitle:viewController.title];
                                    [tab setNeedsLayout];
                                    tab.closeButton.hidden = ![self canRemoveTab:viewController];
                                }];
    }
}

#pragma mark - Propertys

- (NSUInteger)maxCount {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 8 : 4;
}

- (NSUInteger)count {
    return self.tabsView.tabs.count;
}

- (NSMutableArray *)tabContents {
    if (!_tabContents) {
        _tabContents = [[NSMutableArray alloc] initWithCapacity:self.maxCount];
    }
    return _tabContents;
}


#pragma mark - SGBarDelegate

- (void)addTab; {
    if (self.count >= self.maxCount) {
        return;
    }
    SGBlankController *latest = [SGBlankController new];
    [self addTab:latest];
    [self showViewController:latest];
}

- (void)addTabWithURL:(NSURL *)url withTitle:(NSString *)title;{
    SGWebViewController *webC = [[SGWebViewController alloc] initWithNibName:nil bundle:nil];
    webC.title = title;
    [webC openURL:url];
    [self addTab:webC];
    if (self.count >= self.maxCount) {
        if (self.tabsView.selected != 0)
            [self removeIndex:0];
        else
            [self removeIndex:1];
    }
}

- (void)handleURLInput:(NSString*)input withTitle:(NSString *)title {
    NSURL *url = [WeaveOperations parseURLString:input];
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

- (void)handleURLInput:(NSString*)input {
    [self handleURLInput:input withTitle:input];
}

- (void)reload; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC reload];
    }
}

- (void)stop {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC stop];
    }
}

- (BOOL)isLoading {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return [webC isLoading];
    }
    return NO;
}

- (void)goBack; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC goBack];
    }
}

- (void)goForward; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        [webC goForward];
    }
}

- (BOOL)canGoBack; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return [webC canGoBack];
    }
    return NO;
}

- (BOOL)canGoForward; {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return [webC canGoForward];
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
        return webC.request.URL;
    }
    return nil;
}

- (NSString *)location {
    if ([self.currentViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)self.currentViewController;
        return webC.request.URL.absoluteString;
    }
    return @"";
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
