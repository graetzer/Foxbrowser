//
//  SGPageViewController.m
//  SGPageController
//
//  Created by Simon Grätzer on 13.12.12.
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


#import "SGPageViewController.h"
#import "SGPageToolbar.h"
#import "SGPageScrollView.h"
#import "SGSearchField.h"
#import "SGWebViewController.h"

#define SG_EXPOSED_SCALE (0.76f)
#define SG_EXPOSED_TRANSFORM (CGAffineTransformMakeScale(SG_EXPOSED_SCALE, SG_EXPOSED_SCALE))
#define SG_CONTAINER_EMPTY (_viewControllers.count == 0)

#define SG_DURATION 0.25

@implementation SGPageViewController {
    NSMutableArray *_viewControllers;
}
@synthesize exposeMode = _exposeMode;

- (void)loadView {
    CGRect frame = [UIScreen mainScreen].bounds;
    self.view = [[UIView alloc] initWithFrame:frame];
    
    _viewControllers = [NSMutableArray arrayWithCapacity:10];
    _pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, frame.size.height - 25.,
                                                                   frame.size.width, 25.)];
    [self.view addSubview:_pageControl];
    
    _toolbar = [[SGPageToolbar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 44.) browser:self];
    [self.view addSubview:_toolbar];
    
    _scrollView = [[SGPageScrollView alloc] initWithFrame:CGRectMake(0, 45., frame.size.width, frame.size.height-45.)];
    [self.view addSubview:_scrollView];
    
    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeButton.frame = CGRectMake(0, 0, 35, 35);
    [self.view addSubview:_closeButton];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    self.scrollView.delegate = self;

    self.pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.pageControl addTarget:self action:@selector(updatePage) forControlEvents:UIControlEventValueChanged];
    
    NSString *text = NSLocalizedString(@"New Tab", @"New Tab");
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:20];
    CGSize size = [text sizeWithFont:font];
    
    UIButton *button  = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(5, 10, 40 + size.width, size.height);
    button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    button.backgroundColor  = [UIColor clearColor];
    button.titleLabel.font = font;
    button.showsTouchWhenHighlighted = YES;
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"plus-white"] forState:UIControlStateNormal];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    [button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:button belowSubview:self.toolbar];
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(self.view.bounds.size.width - 80, 4, 36, 36);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"grip-white"] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"grip-white-pressed"] forState:UIControlStateHighlighted];
    [button addTarget:self.toolbar action:@selector(showOptions:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:button belowSubview:self.toolbar];
    
    _tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _tabsButton.frame = CGRectMake(self.view.bounds.size.width - 40, 4, 36, 36);
    _tabsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _tabsButton.backgroundColor = [UIColor clearColor];
    _tabsButton.titleEdgeInsets = UIEdgeInsetsMake(5, 5, 0, 0);
    _tabsButton.titleLabel.font = [UIFont systemFontOfSize:12.5];
    [_tabsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_tabsButton setTitle:@"0" forState:UIControlStateNormal];
    [_tabsButton setBackgroundImage:[UIImage imageNamed:@"expose-white"] forState:UIControlStateNormal];
    [_tabsButton setBackgroundImage:[UIImage imageNamed:@"expose-white-pressed"] forState:UIControlStateHighlighted];
    [_tabsButton addTarget:self action:@selector(pressedTabsButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:_tabsButton belowSubview:self.toolbar];
    
    font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 45, self.view.bounds.size.width - 5, font.lineHeight)];
    _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
    [self.view insertSubview:_titleLabel belowSubview:self.scrollView];
    
    _closeButton.hidden = YES;
    _closeButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    _closeButton.backgroundColor  = [UIColor clearColor];
    [_closeButton setImage:[UIImage imageNamed:@"close_x"] forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(closeTabButton:) forControlEvents:UIControlEventTouchDown];
    
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    
    [self addSavedTabs];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    _toolbar = nil;
    _scrollView = nil;
    _pageControl = nil;
    _closeButton = nil;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    self.scrollView.delegate = nil;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [self arrangeChildViewControllers];
    
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width * _viewControllers.count, 1);
    self.scrollView.contentOffset = CGPointMake(self.scrollView.bounds.size.width * self.pageControl.currentPage, 0);
    [self setCloseButtonHidden:NO];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self arrangeChildViewControllers];
    self.scrollView.delegate = self;
}

- (UIView *)rotatingHeaderView {
    return self.toolbar;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Methods

- (void)addViewController:(UIViewController *)childController {
    NSInteger index = 0;
    if (_viewControllers.count == 0) {
        [_viewControllers addObject:childController];
        self.closeButton.hidden = !self.exposeMode;
    } else {
        index = self.pageControl.currentPage+1;
        [_viewControllers insertObject:childController atIndex:index];
    }
    
    [self addChildViewController:childController];
    
    childController.view.clipsToBounds = YES;
    childController.view.transform = CGAffineTransformIdentity;
    childController.view.frame = CGRectMake(self.scrollView.frame.size.width * index,
                                           0,
                                           self.scrollView.frame.size.width,
                                           self.scrollView.frame.size.height);
    if (_exposeMode) {
        childController.view.userInteractionEnabled = NO;
        childController.view.transform = SG_EXPOSED_TRANSFORM;
    }
    
    NSUInteger count = _viewControllers.count;
    self.pageControl.numberOfPages = count;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * count, 1);
    
    for (NSUInteger i = index+1; i < count; i++) {
        UIViewController *vC = _viewControllers[i];
        vC.view.center = CGPointMake(vC.view.center.x + self.scrollView.frame.size.width,
                                     vC.view.center.y);
    }
    [childController didMoveToParentViewController:self];
    [self arrangeChildViewControllers];
    
    if (_viewControllers.count > 1 && [childController isKindOfClass:[SGWebViewController class]])
        [((SGWebViewController *)childController).webView.scrollView setScrollsToTop:NO];
}

- (void)showViewController:(UIViewController *)viewController {
    NSUInteger index = [_viewControllers indexOfObject:viewController];
    if (index != NSNotFound) {
        self.pageControl.currentPage = index;
        
        // self.count != 1 as a workaround when there is just 1 view and no scrolling animation
        [self setCloseButtonHidden:self.count != 1];
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*index, 0)
                                 animated:YES];
        
        if (!_exposeMode)
            [self enableScrollsToTop];
    }
}

- (void)removeViewController:(UIViewController *)childController withIndex:(NSUInteger)index {
    if (!childController || index == NSNotFound)
        return;
    
    [self setCloseButtonHidden:YES];
    [childController willMoveToParentViewController:nil];
    [_viewControllers removeObjectAtIndex:index];
    
    NSUInteger count = _viewControllers.count;
    [UIView animateWithDuration:SG_DURATION
                     animations:^{
                         for (NSUInteger i = index; i < count; i++) {
                             UIViewController *vC = _viewControllers[i];
                             vC.view.center = CGPointMake(vC.view.center.x - self.scrollView.frame.size.width,
                                                          vC.view.center.y);
                         }
                         [childController.view removeFromSuperview];
                         self.pageControl.numberOfPages = count;
                         self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * count, 1);
                     }
                     completion:^(BOOL done){
                         [childController removeFromParentViewController];
                         [self arrangeChildViewControllers];
                         [self updateChrome];
                         
                         if (_exposeMode)
                             self.closeButton.hidden = SG_CONTAINER_EMPTY;
                         else
                             [self enableScrollsToTop];
                     }];
}

- (void)removeViewController:(UIViewController *)childController {
    [self removeViewController:childController withIndex:[_viewControllers indexOfObject:childController]];
}

- (void)removeIndex:(NSUInteger)index {
    [self removeViewController:_viewControllers[index] withIndex:index];
}

- (void)swapCurrentViewControllerWith:(UIViewController *)viewController {
    UIViewController *old = [self selectedViewController];
    
    if (!old)
        [self addViewController:viewController];
    else if (![_viewControllers containsObject:viewController]) {
        [self addChildViewController:viewController];
        
        NSUInteger index = [self selectedIndex];
        
        viewController.view.frame = old.view.frame;
        
        [old willMoveToParentViewController:nil];
        [self transitionFromViewController:old
                          toViewController:viewController
                                  duration:0
                                   options:UIViewAnimationOptionAllowAnimatedContent
                                animations:NULL
                                completion:^(BOOL finished){
                                    [old removeFromParentViewController];
                                    _viewControllers[index] = viewController;
                                    [viewController didMoveToParentViewController:self];
                                    [self arrangeChildViewControllers];
                                    [self updateChrome];
                                    
                                    if (!_exposeMode)
                                        [self enableScrollsToTop];
                                }];
    }
}

- (void)updateChrome {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    
    self.titleLabel.text = self.selectedViewController.title;
    
    _tabsButton.enabled = !SG_CONTAINER_EMPTY;
    NSString *text = [NSString stringWithFormat:@"%d", self.count];
    [_tabsButton setTitle:text forState:UIControlStateNormal];
    
    [self.toolbar updateChrome];
};

- (UIViewController *)selectedViewController {
    return _viewControllers.count > 0 ? _viewControllers[self.pageControl.currentPage] : nil;
}

- (NSUInteger)selectedIndex {
    return self.pageControl.currentPage;
}

- (NSUInteger)count {
    return _viewControllers.count;
}

- (NSUInteger)maxCount {
    return 50;
}

#pragma mark - Utility

- (void)arrangeChildViewControllers {
    NSInteger current = self.pageControl.currentPage;
    
    for (NSInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        if (current - 1  <= i && i <= current + 1) {
            viewController.view.transform = CGAffineTransformIdentity;
            viewController.view.frame = CGRectMake(self.scrollView.frame.size.width * i,
                                                   0,
                                                   self.scrollView.frame.size.width,
                                                   self.scrollView.frame.size.height);
            if (_exposeMode)
                viewController.view.transform = SG_EXPOSED_TRANSFORM;
            
            if (!viewController.view.superview)
                [self.scrollView addSubview:viewController.view];
        } else if (viewController.view.superview)
            [viewController.view removeFromSuperview];
    }
}

- (void)scaleChildViewControllers {
    CGFloat offset = self.scrollView.contentOffset.x;
    CGFloat width = self.scrollView.frame.size.width;
    
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        if (_exposeMode) {
            viewController.view.userInteractionEnabled = NO;
            viewController.view.transform = SG_EXPOSED_TRANSFORM;
        } else {
            viewController.view.userInteractionEnabled = YES;
            
            CGFloat y = i * width;
            CGFloat value = (offset-y)/width;
            CGFloat scale = 1.f-fabs(value);
            if (scale > 1.f) scale = 1.f;
            if (scale < SG_EXPOSED_SCALE) scale = SG_EXPOSED_SCALE;
            
            viewController.view.transform = CGAffineTransformMakeScale(scale, scale);
        }
    }
}

- (void)setCloseButtonHidden:(BOOL)hidden {
    if (self.count > 0) {
        CGPoint point = self.selectedViewController.view.frame.origin;
        self.closeButton.center = [self.view convertPoint:point fromView:self.scrollView];
        self.closeButton.hidden = !_exposeMode  || SG_CONTAINER_EMPTY || hidden;
    } else
        self.closeButton.hidden = YES;
}

// Setting the currently selecte view as the one which receives the scrolls to top gesture
- (void)enableScrollsToTop {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        BOOL enable = i == self.pageControl.currentPage;
        UIViewController *viewController = _viewControllers[i];
        if ([viewController isKindOfClass:[SGWebViewController class]])
            [((SGWebViewController *)viewController).webView.scrollView setScrollsToTop:enable];
    }
}

// Disabling the gesture for everyone
- (void)disableScrollsToTop {
    for (UIViewController *viewController in _viewControllers) {
        if ([viewController isKindOfClass:[SGWebViewController class]])
            [((SGWebViewController *)viewController).webView.scrollView setScrollsToTop:NO];
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (!_exposeMode)
        [self disableScrollsToTop];
    
    [self setCloseButtonHidden:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self setCloseButtonHidden:NO];
    if (!_exposeMode)
        [self enableScrollsToTop];
    
    [self arrangeChildViewControllers];
    [self updateChrome];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self setCloseButtonHidden:NO];
    [self arrangeChildViewControllers];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offset = scrollView.contentOffset.x;
    CGFloat width = scrollView.frame.size.width;
    
    NSInteger nextPage = (NSInteger)fabsf((offset+(width/2))/width);
    if (nextPage != self.pageControl.currentPage) {
        self.pageControl.currentPage = nextPage;
        [self arrangeChildViewControllers];
        [self updateChrome];
    }
    
    [self scaleChildViewControllers];
}

- (void)setExposeMode:(BOOL)exposeMode {
    _exposeMode = exposeMode;
    if (exposeMode) {
        [self.toolbar.searchField resignFirstResponder];
        [self disableScrollsToTop];
        
        [UIView animateWithDuration:SG_DURATION
                         animations:^{
                             self.toolbar.frame = CGRectMake(0, -self.toolbar.frame.size.height,
                                                             self.view.bounds.size.width, self.toolbar.frame.size.height);
                             [self scaleChildViewControllers];
                         }
                         completion:^(BOOL finished) {
                             UITapGestureRecognizer *rec = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                   action:@selector(tappedViewController:)];
                             [self.view addGestureRecognizer:rec];
                             [self arrangeChildViewControllers];
                             [self setCloseButtonHidden:NO];
                         }];

    } else {
        [self enableScrollsToTop];
        self.closeButton.hidden = YES;
        [UIView animateWithDuration:SG_DURATION
                         animations:^{
                             self.toolbar.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.toolbar.frame.size.height);
                             [self scaleChildViewControllers];
                         }
         ];
    }
}

#pragma mark - IBAction

- (IBAction)updatePage {
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*self.pageControl.currentPage, 0)
                             animated:YES];
}

- (IBAction)tappedViewController:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        UIView *view = [self selectedViewController].view;
        CGPoint pos = [recognizer locationInView:view];
        if (CGRectContainsPoint(view.bounds, pos)) {
            self.exposeMode = NO;
            [self.view removeGestureRecognizer:recognizer];
        }
    }
}

- (IBAction)pressedTabsButton:(id)sender {
    if (!SG_CONTAINER_EMPTY)
        self.exposeMode = NO;
}

- (IBAction)closeTabButton:(UIButton *)button {
    [self removeViewController:self.selectedViewController];
}

@end
