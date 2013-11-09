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
#import "SGSearchField.h"
#import "SGWebViewController.h"

#define SG_EXPOSED_SCALE (0.70f)
#define SG_EXPOSED_TRANSFORM (CGAffineTransformMakeScale(SG_EXPOSED_SCALE, SG_EXPOSED_SCALE))
#define SG_CONTAINER_EMPTY (_viewControllers.count == 0)

#define SG_DURATION 0.25

@implementation SGPageViewController {
    BOOL _animating;
    NSMutableArray *_viewControllers;
    
    CGFloat _topOffset;
    CGPoint _lastScrollViewContentOffset;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _viewControllers = [NSMutableArray arrayWithCapacity:10];
    self.view.backgroundColor = kSGBrowserBackgroundColor;
    
    CGRect b = self.view.bounds;
    
    __strong UIScrollView *scroller = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scroller.autoresizingMask = (UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight);
    scroller.clipsToBounds = YES;
    scroller.backgroundColor = [UIColor clearColor];
    scroller.pagingEnabled = YES;
    scroller.showsHorizontalScrollIndicator = NO;
    scroller.showsVerticalScrollIndicator = NO;
    scroller.scrollsToTop = NO;
    scroller.delaysContentTouches = NO;
    scroller.delegate = self;
    [self.view addSubview:scroller];
    _scrollView = scroller;
    
    __strong UIView *tmpView = [[UIPageControl alloc] initWithFrame:CGRectMake(0, b.size.height - 25., b.size.width, 25.)];
    [self.view insertSubview:tmpView belowSubview:_scrollView];
    _pageControl = (UIPageControl *)tmpView;
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_pageControl addTarget:self action:@selector(_updatePage) forControlEvents:UIControlEventValueChanged];
    
    tmpView = [[SGPageToolbar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, kSGToolbarHeight) browser:self];
    [self.view addSubview:tmpView];
    _toolbar = (SGPageToolbar *)tmpView;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 30, 30);
    button.hidden = YES;
    button.autoresizingMask = (UIViewAutoresizing)0b101101;
    button.backgroundColor  = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"closebox"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(_closeTabButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:button aboveSubview:_scrollView];
    _closeButton = button;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    button.backgroundColor  = [UIColor clearColor];
    button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:20];
    button.showsTouchWhenHighlighted = YES;
    [button setTitle:NSLocalizedString(@"New Tab", @"New Tab") forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"plus-white"] forState:UIControlStateNormal];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    [button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:button belowSubview:_scrollView];
    _addTabButton = button;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"grip-white"] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"grip-white-pressed"] forState:UIControlStateHighlighted];
    [button addTarget:self.toolbar action:@selector(_showOptions:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:button belowSubview:_scrollView];
    _optionsButton = button;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(self.view.bounds.size.width - 40, 4, 36, 36);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    button.backgroundColor = [UIColor clearColor];
    button.titleEdgeInsets = UIEdgeInsetsMake(5, 5, 0, 0);
    button.titleLabel.font = [UIFont systemFontOfSize:12.5];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitle:@"0" forState:UIControlStateNormal];
    [button setBackgroundImage:[UIImage imageNamed:@"expose-white"] forState:UIControlStateNormal];
    [button setBackgroundImage:[UIImage imageNamed:@"expose-white-pressed"] forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(_pressedTabsButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:button belowSubview:_scrollView];
    _tabsButton = button;
    
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    __strong UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5, 45, self.view.bounds.size.width - 5, font.lineHeight)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.view insertSubview:label belowSubview:_scrollView];
    _titleLabel = label;
    
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    
    [self loadSavedTabs];
}

/*! Set the delegate to nil because the scrollview delegate gets weird scroll values */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    self.scrollView.delegate = nil;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self _layoutChildViewControllers];
    self.scrollView.delegate = self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if (!_animating) [self _layout];
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

- (UIStatusBarStyle)preferredStatusBarStyle {
    return _exposeMode ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
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
    NSUInteger count = _viewControllers.count;
    self.pageControl.numberOfPages = count;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * count, 1);
    [self _layoutChildViewControllers];
    [self _enableScrollsToTop];
    
    [childController didMoveToParentViewController:self];
}

- (void)showViewController:(UIViewController *)viewController{
    NSUInteger index = [_viewControllers indexOfObject:viewController];
    if (index != NSNotFound) {
        self.pageControl.currentPage = index;
        
        // self.count != 1 as a workaround when there is just 1 view and no scrolling animation
        [self _setCloseButtonHidden:self.count != 1];
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*index, 0)
                                 animated:YES];
        
        if (!_exposeMode) {
            [self _enableScrollsToTop];
        }
    }
}

- (void)removeViewController:(UIViewController *)childController withIndex:(NSUInteger)index {
    if (!childController || index == NSNotFound) return;
    
    [self _setCloseButtonHidden:YES];
    [childController willMoveToParentViewController:nil];
    [_viewControllers removeObjectAtIndex:index];
    
    NSUInteger count = _viewControllers.count;
    [UIView animateWithDuration:SG_DURATION
                     animations:^{
                         [childController.view removeFromSuperview];
                         self.pageControl.numberOfPages = count;
                         _scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * count, 1);
                         
                         for (NSUInteger i = index; i < count; i++) {
                             UIViewController *vC = _viewControllers[i];
                             vC.view.center = CGPointMake(vC.view.center.x - self.scrollView.frame.size.width,
                                                          vC.view.center.y);
                         }
                     }
                     completion:^(BOOL done){
                         [childController removeFromParentViewController];
                         [self _layoutChildViewControllers];
                         [self updateInterface];
                         
                         if (_exposeMode) self.closeButton.hidden = SG_CONTAINER_EMPTY;
                         else if (_viewControllers.count > 0) [self _enableScrollsToTop];
                         else self.exposeMode = YES;
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
    
    if (!old) [self addViewController:viewController];
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
                                    [self _layoutChildViewControllers];
                                    [self updateInterface];
                                    
                                    if (!_exposeMode) {
                                        [self _enableScrollsToTop];
                                    }
                                }];
    }
}

- (void)updateInterface {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    
    self.titleLabel.text = self.selectedViewController.title;
    
    _tabsButton.enabled = !SG_CONTAINER_EMPTY;
    NSString *text = [NSString stringWithFormat:@"%d", self.count];
    [_tabsButton setTitle:text forState:UIControlStateNormal];
    
    [self.toolbar updateInterface];
};

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {
    return index < _viewControllers.count ? _viewControllers[index] : nil;
}

- (UIViewController *)selectedViewController {
    return _viewControllers.count > 0 ? _viewControllers[self.pageControl.currentPage] : nil;
}

- (NSUInteger)selectedIndex {
    return self.pageControl.currentPage;
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    if (selectedIndex < _viewControllers.count) {
        UIViewController *controller = _viewControllers[selectedIndex];
        [self showViewController:controller];
    }
}

- (NSUInteger)count {
    return _viewControllers.count;
}

- (NSUInteger)maxCount {
    return 50;
}

#pragma mark - Utility

/*! Internal layout function */
- (void)_layout {
    CGRect b = self.view.bounds;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        _topOffset = [self.topLayoutGuide length];
    }
    
    CGFloat toolbarH = kSGToolbarHeight+_topOffset;
    if (_exposeMode) {
        _toolbar.frame = CGRectMake(0, -_toolbar.frame.size.height, b.size.width, toolbarH);
        _scrollView.frame = CGRectMake(0, toolbarH, b.size.width, b.size.height - (toolbarH));
    } else {
        _toolbar.frame = CGRectMake(0, _toolbar.frame.origin.x, b.size.width, toolbarH);
        _scrollView.frame = b;
    }
    
    CGSize size = [[_addTabButton titleForState:UIControlStateNormal] sizeWithFont:_addTabButton.titleLabel.font];
    _addTabButton.frame = CGRectMake(5, _topOffset + 10, 40 + size.width, size.height);
    _optionsButton.frame = CGRectMake(b.size.width - 80, _topOffset + 4, 36, 36);
    _tabsButton.frame = CGRectMake(b.size.width - 40, _topOffset + 4, 36, 36);
    _titleLabel.frame = CGRectMake(5, kSGToolbarHeight + _topOffset + 1, b.size.width - 5, _titleLabel.font.lineHeight);
    
    [self _layoutChildViewControllers];
    _scrollView.contentSize = CGSizeMake(_scrollView.bounds.size.width * _viewControllers.count, 1);
    _scrollView.contentOffset = CGPointMake(_scrollView.bounds.size.width * _pageControl.currentPage, 0);
    
    [self _setCloseButtonHidden:NO];
}

/*! Managing the visible viewcontroller, only 3 are added to the scrollview at a time */
- (void)_layoutChildViewControllers {
    NSInteger current = self.pageControl.currentPage;
    
    for (NSInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        if (current - 1  <= i && i <= current + 1) {// Just keep a max of 3 views around
            
            CGFloat y = 0, y2 = 0;
            //if (!_exposeMode) {
                y = _toolbar.frame.size.height;
                if ([viewController isKindOfClass:[SGWebViewController class]]) {
                    y2 = _topOffset;
                } else {
                    y2 = y;
                }
            //}
            
            // Just in case rest the transform
            viewController.view.transform = CGAffineTransformIdentity;
            viewController.view.frame = CGRectMake(self.scrollView.frame.size.width * i,
                                                   y,
                                                   self.scrollView.frame.size.width,
                                                   self.scrollView.frame.size.height-y2);
            if (_exposeMode) { // TODO account for the different sizes
                viewController.view.transform = SG_EXPOSED_TRANSFORM;
            }
            if (!viewController.view.superview) {
                [self.scrollView addSubview:viewController.view];
            }
        } else if (viewController.view.superview) {
            [viewController.view removeFromSuperview];
        }
    }
}

/*! Scale the child viewcontroller's if a user swipes left or right */
- (void)_scaleChildViewControllers {
    CGFloat offset = self.scrollView.contentOffset.x;
    CGFloat width = self.scrollView.frame.size.width;
    
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        if (_exposeMode) {
            viewController.view.transform = SG_EXPOSED_TRANSFORM;
        } else {
            
            CGFloat y = i * width;
            CGFloat value = (offset-y)/width;
            CGFloat scale = 1.f-fabs(value);
            if (scale < SG_EXPOSED_SCALE) scale = SG_EXPOSED_SCALE;
            
            viewController.view.transform = CGAffineTransformMakeScale(scale, scale);
        }
    }
}

- (void)_setCloseButtonHidden:(BOOL)hidden {
    if (!SG_CONTAINER_EMPTY) {
        CGPoint point = self.selectedViewController.view.frame.origin;
        self.closeButton.center = [self.view convertPoint:point fromView:self.scrollView];
        self.closeButton.hidden = !_exposeMode || hidden;
        
    } else self.closeButton.hidden = YES;
}

/*! Setting the currently selecte view as the one which receives the scrolls to top gesture */
- (void)_enableScrollsToTop {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        BOOL enable = (i == self.pageControl.currentPage);
        UIViewController *viewC = _viewControllers[i];
        if ([viewC isKindOfClass:[SGWebViewController class]]) {
            SGWebViewController *webC = (SGWebViewController *)viewC;
            webC.webView.scrollView.scrollsToTop = enable;
            webC.webView.scrollView.delegate = enable ? self : nil;
        }
        viewC.view.userInteractionEnabled = !_exposeMode;
    }
}

/*! Disabling the gesture for everyone */
- (void)_disableScrollsToTop {
    for (UIViewController *viewController in _viewControllers) {
        if ([viewController isKindOfClass:[SGWebViewController class]]) {
            ((SGWebViewController *)viewController).webView.scrollView.scrollsToTop = NO;
        }
        viewController.view.userInteractionEnabled = !_exposeMode;
    }
}

- (void)_setToolbarHidden:(BOOL)hidden {
    if (!_exposeMode && !_animating) {
        _animating = YES;
        [UIView animateWithDuration:SG_DURATION
                         animations:^{
                             CGRect b = self.view.bounds;
                             CGFloat y = _toolbar.frame.size.height;
                             if (hidden) {
                                 _toolbar.frame = CGRectMake(0, -kSGToolbarHeight, b.size.width, y);
                                 y = _topOffset;
                                 [_toolbar setSubviewsAlpha:0];
                             } else {
                                 _toolbar.frame = CGRectMake(0, 0, b.size.width, y);
                                 [_toolbar setSubviewsAlpha:1];
                             }
                             CGRect frame = self.selectedViewController.view.frame;
                             frame.origin.y = y;
                             self.selectedViewController.view.frame = frame;
                         } completion:^(BOOL finished){
                             _animating = NO;
                         }];
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) return;
        
    if (!_exposeMode) {
        [self _disableScrollsToTop];
    }
    [self _setCloseButtonHidden:YES];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView != self.scrollView && !decelerate) {
        // This may need to be changed if -scrollViewDidEndDecelerating changes
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) return;
    
    [self _setCloseButtonHidden:NO];
    [self _layoutChildViewControllers];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == self.scrollView) {
        if (!_exposeMode) {
            [self _enableScrollsToTop];
        }
        [self _setCloseButtonHidden:NO];
        [self _layoutChildViewControllers];
    } else {
        if (_toolbar.frame.origin.y < - _toolbar.frame.size.height/2) {
            [self _setToolbarHidden:YES];
        } else {
            [self _setToolbarHidden:NO];
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == self.scrollView) {
        CGFloat offset = scrollView.contentOffset.x;
        CGFloat width = scrollView.frame.size.width;
        
        NSInteger nextPage = (NSInteger)fabs((offset+(width/2))/width);
        if (nextPage != self.pageControl.currentPage) {
            self.pageControl.currentPage = nextPage;
            [self _layoutChildViewControllers];
            [self updateInterface];
        }
        [self _scaleChildViewControllers];
        if (_toolbar.frame.origin.y != 0) {
            [self _setToolbarHidden:NO];
        }
        
    } else {
        
        CGPoint contentOff = scrollView.contentOffset;
        CGFloat offset = _lastScrollViewContentOffset.y - contentOff.y;
        _lastScrollViewContentOffset = contentOff;
        
        // Test if we are zooming or the toolbar is already visible and has
        // pulled the webview down over the max offset
        if (scrollView.zooming || (contentOff.y <= 0 && _toolbar.frame.origin.y == 0)) return;
        
        CGRect next = CGRectOffset(_toolbar.frame, 0, offset);
        if (next.origin.y >= -kSGToolbarHeight
            && next.origin.y <= 0) {
            _toolbar.frame = next;
            self.selectedViewController.view.frame = CGRectOffset(self.selectedViewController.view.frame, 0, offset);
            [_toolbar setSubviewsAlpha:1.f-fabsf(next.origin.y/kSGToolbarHeight)];
        }
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) return;
    
    [self _setToolbarHidden:NO];
}

#pragma mark - Manage the expose mode

- (void)setExposeMode:(BOOL)exposeMode animated:(BOOL)animated {
    _exposeMode = exposeMode;
    CGFloat duration = animated ? SG_DURATION : 0;
    if (exposeMode) {
        [self.toolbar.searchField resignFirstResponder];
        [self _disableScrollsToTop];
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            [self setNeedsStatusBarAppearanceUpdate];
        }
        
        _animating = YES;
        [UIView animateWithDuration:duration
                         animations:^{
                             [self _layout];
                         }
                         completion:^(BOOL finished) {
                             _animating = NO;
                             UITapGestureRecognizer *rec = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                   action:@selector(_tappedViewController:)];
                             [self.view addGestureRecognizer:rec];
                             //[self _layoutChildViewControllers];
                             [self _setCloseButtonHidden:NO];
                         }];
        
    } else {
        [self _enableScrollsToTop];
        [self _setCloseButtonHidden:YES];
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            [self setNeedsStatusBarAppearanceUpdate];
        }
        
        _animating = YES;
        [UIView animateWithDuration:duration
                         animations:^{
                             [self _layout];
                         }
                         completion:^(BOOL finished){
                             _animating = NO;
                         }
         ];
    }
}

- (void)setExposeMode:(BOOL)exposeMode {
    [self setExposeMode:exposeMode animated:NO];
}

#pragma mark - IBAction

/*! Update the displayed controller, of the user taps the UIPageControl */
- (IBAction)_updatePage {
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*self.pageControl.currentPage, 0)
                             animated:YES];
}

/*! Recognize if the user taps the currently displayed viewcontroller and end the expose mode */
- (IBAction)_tappedViewController:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        UIView *view = [self selectedViewController].view;
        CGPoint pos = [recognizer locationInView:view];
        if (CGRectContainsPoint(view.bounds, pos)) {
            [self setExposeMode:NO animated:YES];
            [self.view removeGestureRecognizer:recognizer];
        }
    }
}

- (IBAction)_pressedTabsButton:(id)sender {
    if (!SG_CONTAINER_EMPTY) [self setExposeMode:NO animated:YES];
}

/*! Remove the currently displayed view controller */
- (IBAction)_closeTabButton:(UIButton *)button {
    [self removeViewController:self.selectedViewController withIndex:self.selectedIndex];
}

@end
