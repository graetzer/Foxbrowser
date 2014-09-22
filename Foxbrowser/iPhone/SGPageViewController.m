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

CGFloat const kSGMinYScale = 0.85;
CGFloat const kSGMinXScale = 0.85;
#define SG_EXPOSED_TRANSFORM (CGAffineTransformMakeScale(0.7, 0.7))

#define SG_CONTAINER_EMPTY (_viewControllers.count == 0)
#define SG_DURATION 0.25

@implementation SGPageViewController {
    BOOL _animating;
    
    NSMutableArray *_containerViews;
    NSMutableArray *_viewControllers;
    
    CGFloat _topOffset;
    
    UIPanGestureRecognizer *_panGesture;
    CGPoint _panTranslation;
}

- (UIViewController *)_viewControllerForFullScreenPresentationFromView:(UIView *)view {
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _containerViews = [NSMutableArray arrayWithCapacity:10];
    _viewControllers = [NSMutableArray arrayWithCapacity:10];
    self.view.backgroundColor = kSGBrowserBackgroundColor;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
    
    CGRect b = self.view.bounds;
    
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                          action:@selector(_moveWebView:)];
    _panGesture.delegate = self;
    
    __strong SGPageToolbar *toolbar = [[SGPageToolbar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, kSGToolbarHeight) browser:self];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _toolbar = toolbar;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    button.backgroundColor  = [UIColor clearColor];
    button.enabled = NO;
    button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:20];
    button.showsTouchWhenHighlighted = YES;
    [button setTitle:NSLocalizedString(@"New Tab", @"New Tab") forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"plus-white"] forState:UIControlStateNormal];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    [button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    _addTabButton = button;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(self.view.bounds.size.width - 80, 4, 36, 36);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    button.backgroundColor = [UIColor clearColor];
    button.enabled = NO;
    [button setImage:[UIImage imageNamed:@"grip-white"] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"grip-white-pressed"] forState:UIControlStateHighlighted];
    [button addTarget:_toolbar action:@selector(_showOptions:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    _optionsButton = button;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    button.enabled = NO;
    button.backgroundColor = [UIColor clearColor];
    button.titleEdgeInsets = UIEdgeInsetsMake(5, 5, 0, 0);
    button.titleLabel.font = [UIFont systemFontOfSize:12.5];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitle:@"0" forState:UIControlStateNormal];
    [button setBackgroundImage:[UIImage imageNamed:@"expose-white"] forState:UIControlStateNormal];
    [button setBackgroundImage:[UIImage imageNamed:@"expose-white-pressed"] forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(_pressedTabsButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    _tabsButton = button;
    
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    __strong UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5, 45, self.view.bounds.size.width - 5, font.lineHeight)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.view addSubview:label];
    _titleLabel = label;
    
    __strong UIScrollView *scroller = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scroller.autoresizingMask = (UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight);
    scroller.clipsToBounds = NO;
    scroller.backgroundColor = [UIColor clearColor];
    scroller.pagingEnabled = YES;
    scroller.showsHorizontalScrollIndicator = NO;
    scroller.showsVerticalScrollIndicator = NO;
    scroller.scrollsToTop = NO;
    scroller.delaysContentTouches = NO;
    scroller.delegate = self;
    [self.view addSubview:scroller];
    _scrollView = scroller;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 36, 36);
    button.hidden = YES;
    button.autoresizingMask = (UIViewAutoresizing)0b101101;
    button.backgroundColor  = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"closebox"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(_closeTabButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    _closeButton = button;
    
    __strong UIPageControl *pageCtrl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, b.size.height - 25., b.size.width, 25.)];
    [self.view insertSubview:pageCtrl belowSubview:_scrollView];
    _pageControl = pageCtrl;
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_pageControl addTarget:self action:@selector(_updatePage) forControlEvents:UIControlEventValueChanged];
    
    
    [self.view addSubview:toolbar];
    
    [self loadSavedTabs];
}

/*! Set the delegate to nil because the scrollview delegate gets weird scroll values */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    _scrollView.delegate = nil;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self _layoutPages];
    _scrollView.delegate = self;
}

/*! Set the delegate to nil because the scrollview delegate gets weird scroll values */
#ifdef __IPHONE_8_0
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    _scrollView.delegate = nil;
    [coordinator animateAlongsideTransition:NULL completion:^(id<UIViewControllerTransitionCoordinator> handler) {
        [self _layoutPages];
        _scrollView.delegate = self;
    }];
}
#endif

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if (!_animating) [self _layout];
}

- (UIView *)rotatingHeaderView {
    return _toolbar;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Methods

- (void)addViewController:(UIViewController *)childController {
    
    UIView *container = [[UIView alloc] initWithFrame:_scrollView.bounds];
    container.clipsToBounds = _exposeMode;
    [container addSubview:childController.view];
    
    if (_viewControllers.count == 0) {
        [_containerViews addObject:container];
        [_viewControllers addObject:childController];
        // If there are no pages we need to redisplay the button
        _closeButton.hidden = !_exposeMode;
    } else {
        NSInteger index = _pageControl.currentPage+1;
        [_containerViews insertObject:container atIndex:index];
        [_viewControllers insertObject:childController atIndex:index];
    }
    
    [self addChildViewController:childController];
    NSUInteger count = _viewControllers.count;
    _pageControl.numberOfPages = count;
    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * count, 1);
    [self _layoutPages];
    
    [childController didMoveToParentViewController:self];
}

- (void)showViewController:(UIViewController *)viewController{
    NSUInteger index = [_viewControllers indexOfObject:viewController];
    if (index != NSNotFound) {
        _pageControl.currentPage = index;
        
        // self.count != 1 as a workaround when there is just 1 view and no scrolling animation
        [self _setCloseButtonHidden:self.count != 1];
        [_scrollView setContentOffset:CGPointMake(_scrollView.frame.size.width*index, 0)
                                 animated:YES];
        
        if (!_exposeMode) {
            [self _enableInteractions];
        } else {
            UIView *container = _containerViews[index];
            container.userInteractionEnabled = NO;
        }
    }
}

- (void)removeViewController:(UIViewController *)childController withIndex:(NSUInteger)index {
    if (!childController || index == NSNotFound) return;
    
    [self _setCloseButtonHidden:YES];
    [childController willMoveToParentViewController:nil];
    [_containerViews removeObjectAtIndex:index];
    [_viewControllers removeObjectAtIndex:index];
    
    NSUInteger count = _viewControllers.count;
    [UIView animateWithDuration:SG_DURATION
                     animations:^{
                         [childController.view removeFromSuperview];
                         _pageControl.numberOfPages = count;
                         _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * count, 1);
                         
                         for (NSUInteger i = index; i < count; i++) {
                             UIView *view = _containerViews[i];
                             view.center = CGPointMake(view.center.x - _scrollView.frame.size.width,
                                                          view.center.y);
                         }
                     }
                     completion:^(BOOL done){
                         [childController removeFromParentViewController];
                         [self _layoutPages];
                         [self updateInterface];
                         
                         if (_exposeMode) _closeButton.hidden = SG_CONTAINER_EMPTY;
                         else if (_viewControllers.count > 0) [self _enableInteractions];
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
                                    [self _layoutPages];
                                    [self updateInterface];
                                    
                                    if (!_exposeMode) {
                                        [self _enableInteractions];
                                    }
                                }];
    }
}

- (void)updateInterface {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    
    self.titleLabel.text = self.selectedViewController.title;
    
    _tabsButton.enabled = !SG_CONTAINER_EMPTY;
    NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)[self count]];
    [_tabsButton setTitle:text forState:UIControlStateNormal];
    
    [_toolbar updateInterface];
};

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {
    return index < _viewControllers.count ? _viewControllers[index] : nil;
}

- (UIViewController *)selectedViewController {
    return _viewControllers.count > 0 ? _viewControllers[_pageControl.currentPage] : nil;
}

- (NSUInteger)selectedIndex {
    return _pageControl.currentPage;
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

#pragma mark - Layouting

/*! Internal layout function */
- (void)_layout {
    CGRect b = self.view.bounds;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        _topOffset = [self.topLayoutGuide length];
    }
    
    CGFloat toolbarH = kSGToolbarHeight+_topOffset;
    if (_exposeMode) {
        _toolbar.frame = CGRectMake(0, -toolbarH, b.size.width, toolbarH);
        //_scrollView.frame = CGRectMake(0, toolbarH, b.size.width, b.size.height - (toolbarH));
    } else {
        _toolbar.frame = CGRectMake(0, _toolbar.frame.origin.y, b.size.width, toolbarH);
    }
    _scrollView.frame = CGRectMake(0, toolbarH, b.size.width, b.size.height - (toolbarH));
    
    CGSize size = [[_addTabButton titleForState:UIControlStateNormal] sizeWithFont:_addTabButton.titleLabel.font];
    _addTabButton.frame = CGRectMake(5, _topOffset + 10, 40 + size.width, size.height);
    _optionsButton.frame = CGRectMake(b.size.width - 80, _topOffset + 4, 36, 36);
    _tabsButton.frame = CGRectMake(b.size.width - 40, _topOffset + 4, 36, 36);
    _titleLabel.frame = CGRectMake(5, kSGToolbarHeight + _topOffset + 1, b.size.width - 5, _titleLabel.font.lineHeight);
    
    [self _layoutPages];
    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * _viewControllers.count, 1);
    _scrollView.contentOffset = CGPointMake(_scrollView.frame.size.width * _pageControl.currentPage, 0);
}

/*! Managing the visible viewcontrollers, only 3 are added to the scrollview at a time */
- (void)_layoutPages {
    NSInteger current = _pageControl.currentPage;
    
    for (NSInteger i = 0; i < _containerViews.count; i++) {
        UIView *container = _containerViews[i];
        if (current - 1  <= i && i <= current + 1) {// Just keep a max of 3 views around
            
            CGFloat y = 0;//_toolbar.frame.size.height;
            
            // Just in case rest the transform
            container.transform = CGAffineTransformIdentity;
            container.frame = CGRectMake(_scrollView.frame.size.width * i,
                                                   y,
                                                   _scrollView.frame.size.width,
                                                   _scrollView.frame.size.height-y);
            if (_exposeMode) {
                container.transform = SG_EXPOSED_TRANSFORM;
            }
            if (!container.superview) {
                [_scrollView addSubview:container];
            }
            UIViewController *viewC = _viewControllers[i];
            if ([viewC isKindOfClass:[SGWebViewController class]]) {
                SGWebViewController *webC = (SGWebViewController *)viewC;
                CGRect frame = container.bounds;
                frame.origin.y = _toolbar.frame.origin.y * container.transform.d;
                frame.size.height += kSGToolbarHeight/container.transform.d;
                webC.view.frame = frame;
            } else {
                viewC.view.frame = container.bounds;
            }
        } else if (container.superview) {
            [container removeFromSuperview];
        }
    }
}

/*! Scale the child viewcontroller's if a user swipes left or right */
- (void)_scalePages {
    CGFloat offset = _scrollView.contentOffset.x;
    CGFloat width = _scrollView.frame.size.width;
    
    for (NSUInteger i = 0; i < _containerViews.count; i++) {
        UIView *view = _containerViews[i];
        if (_exposeMode) {
            view.transform = SG_EXPOSED_TRANSFORM;
        } else {
            
            CGFloat y = i * width;// Position of view
            CGFloat rel = MIN(MAX(fabs(offset-y)/width, 0.f), 1.f);
            CGFloat scaleX = MAX(kSGMinXScale, expf(-rel));
            CGFloat scaleY = MAX(kSGMinYScale, expf(-rel));
            
            view.transform = CGAffineTransformMakeScale(scaleX, scaleY);
        }
    }
}

- (void)_setCloseButtonHidden:(BOOL)hidden {
    if (!SG_CONTAINER_EMPTY) {
        UIView *container = _containerViews[_pageControl.currentPage];
        CGPoint point = container.frame.origin;
        _closeButton.center = [self.view convertPoint:point fromView:_scrollView];
        _closeButton.hidden = !_exposeMode || hidden;
        
    } else _closeButton.hidden = YES;
}

/*! Setting the currently selecte view as the one which receives the scrolls to top gesture */
- (void)_enableInteractions {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        BOOL enable = (i == _pageControl.currentPage);
        
        UIView *container = _containerViews[i];
        UIViewController *viewC = _viewControllers[i];
        if ([viewC isKindOfClass:[SGWebViewController class]]) {
            
            SGWebViewController *webC = (SGWebViewController *)viewC;
            webC.webView.scrollView.scrollsToTop = enable;
            webC.webView.scrollView.delegate = enable ? self : nil;
            
            if (enable && container != _panGesture.view) {
                [container addGestureRecognizer:_panGesture];
            }
        }
        container.clipsToBounds = !enable;
        container.userInteractionEnabled = enable;
    }
}

/*! Disabling the gesture for everyone */
- (void)_disableInteractions {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        
        UIView *container = _containerViews[i];
        UIViewController *viewC = _viewControllers[i];
        if ([viewC isKindOfClass:[SGWebViewController class]]) {
            SGWebViewController *webC = (SGWebViewController *)viewC;
            webC.webView.scrollView.scrollsToTop = NO;
            webC.webView.scrollView.delegate = nil;
        }
        container.clipsToBounds = YES;
        container.userInteractionEnabled = NO;
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
                                 [_toolbar setSubviewsAlpha:0];
                             } else {
                                 _toolbar.frame = CGRectMake(0, 0, b.size.width, y);
                                 [_toolbar setSubviewsAlpha:1];
                             }
                             if ([self.selectedViewController isKindOfClass:[SGWebViewController class]]) {
                                 SGWebViewController *webC = (SGWebViewController *)self.selectedViewController;
                                 CGRect frame = webC.view.frame;
                                 frame.origin.y = _toolbar.frame.origin.y;
                                 webC.view.frame = frame;
                             }
                         } completion:^(BOOL finished){
                             _animating = NO;
                         }];
    }
}

- (void)setExposeMode:(BOOL)exposeMode animated:(BOOL)animated {
    _exposeMode = exposeMode;
    CGFloat duration = animated ? SG_DURATION : 0;
    if (exposeMode) {
        [_toolbar.searchField resignFirstResponder];
        [self _disableInteractions];
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
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
                             rec.cancelsTouchesInView = NO;
                             [self.view addGestureRecognizer:rec];
                             [self _setCloseButtonHidden:NO];
                         }];
        
    } else {
        
        [self _setCloseButtonHidden:YES];
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
        }
        
        _animating = YES;
        [UIView animateWithDuration:duration
                         animations:^{
                             CGRect frame = _toolbar.frame;
                             frame.origin.y = 0;
                             _toolbar.frame = frame;
                             [self _layout];
                         }
                         completion:^(BOOL finished){
                             _animating = NO;
                             [self _enableInteractions];
                         }
         ];
    }
    _addTabButton.enabled = exposeMode;
    _optionsButton.enabled = exposeMode;
    _tabsButton.enabled = exposeMode;
}

- (void)setExposeMode:(BOOL)exposeMode {
    [self setExposeMode:exposeMode animated:NO];
}

#pragma mark - UIGestureRecognizer

- (IBAction)_moveWebView:(UIPanGestureRecognizer *)recognizer {
     if (![self.selectedViewController isKindOfClass:[SGWebViewController class]]) return;
    
    UIView *container = _containerViews[_pageControl.currentPage];
    SGWebViewController *webC = (SGWebViewController *)self.selectedViewController;
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:{
            _panTranslation = [recognizer translationInView:container];
            _animating = YES;
        }
            break;
            
        case UIGestureRecognizerStateChanged:{
            
            CGPoint trans = [recognizer translationInView:container];
            CGFloat offset = trans.y - _panTranslation.y;
            _panTranslation = trans;

            CGRect next = CGRectOffset(_toolbar.frame, 0, offset);
            if (next.origin.y >= -kSGToolbarHeight
                && next.origin.y <= 0) {
                _toolbar.frame = next;
                [_toolbar setSubviewsAlpha:1.f-fabsf(next.origin.y/kSGToolbarHeight)];
                webC.view.frame = CGRectOffset(webC.view.frame, 0, offset);
            } else {
                CGPoint curr = webC.webView.scrollView.contentOffset;
                curr.y -= offset;
                if ( curr.y > 0 && curr.y <= webC.webView.scrollView.contentSize.height) {
                    webC.webView.scrollView.contentOffset = curr;
                }
            }
        }
            break;
        
        
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:{
            _animating = NO;
            if (_toolbar.frame.origin.y < -kSGToolbarHeight/2) {
                [self _setToolbarHidden:YES];
            } else {
                [self _setToolbarHidden:NO];
            }
            _panTranslation = CGPointZero;
        }
            break;
        default:
            break;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == _panGesture) {
        UIView *container = _containerViews[_pageControl.currentPage];
        
        CGPoint trans = [_panGesture translationInView:container];
        CGFloat offset = trans.y - _panTranslation.y;
        CGRect next = CGRectOffset(_toolbar.frame, 0, offset);
        
        //check for the vertical gesture
        return fabsf(trans.y) > fabsf(trans.x)
        && next.origin.y >= -kSGToolbarHeight
        && next.origin.y <= 0;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return gestureRecognizer == _panGesture
    && ![otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]
    && !_exposeMode;
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) return;
    if (!_exposeMode) {
        [self _disableInteractions];
    }
    [self _setCloseButtonHidden:YES];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        // This may need to be changed if -scrollViewDidEndDecelerating changes
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self _setCloseButtonHidden:NO];
    [self _layoutPages];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) return;
    if (!_exposeMode) {
        [self _enableInteractions];
    }
    [self _setCloseButtonHidden:NO];
    [self _layoutPages];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) {
        if (scrollView.contentOffset.y < 0 && _toolbar.frame.origin.y < 0) {
            [self _setToolbarHidden:NO];
        }
        return;
    }
    
    CGFloat offset = scrollView.contentOffset.x;
    CGFloat width = scrollView.frame.size.width;
    
    NSInteger nextPage = (NSInteger)fabs((offset+(width/2))/width);
    if (nextPage != _pageControl.currentPage) {
        _pageControl.currentPage = nextPage;
        [self _layoutPages];
        [self updateInterface];
    }
    [self _scalePages];
    if (_toolbar.frame.origin.y != 0) {
        [self _setToolbarHidden:NO];
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    if (scrollView == _scrollView) return;
    [self _setToolbarHidden:NO];
}

#pragma mark - IBAction

/*! Update the displayed controller, of the user taps the UIPageControl */
- (IBAction)_updatePage {
    [_scrollView setContentOffset:CGPointMake(_scrollView.frame.size.width*_pageControl.currentPage, 0)
                             animated:YES];
}

/*! Recognize if the user taps the currently displayed viewcontroller and end the expose mode */
- (IBAction)_tappedViewController:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        UIView *view = [self selectedViewController].view;
        CGPoint pos = [recognizer locationInView:view];
        CGRect rect = CGRectInset(view.bounds, 20, 20);
        if (CGRectContainsPoint(rect, pos)) {
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
