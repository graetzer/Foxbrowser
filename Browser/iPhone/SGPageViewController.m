//
//  SGPageViewController.m
//  SGPageController
//
//  Created by Simon Grätzer on 13.12.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//


#import "SGPageViewController.h"
#import "SGPageToolbar.h"
#import "SGSearchField.h"

#import "SGWebViewController.h"
#import "SGBlankController.h"

CGFloat const kSGMinYScale = 0.84;
CGFloat const kSGMinXScale = 0.84;
#define SG_EXPOSED_TRANSFORM (CGAffineTransformMakeScale(0.75, 0.8))
#define SG_CONTAINER_EMPTY (_viewControllers.count == 0)
#define SG_DURATION 0.2

@implementation SGPageViewController {
    NSMutableArray *_viewControllers;
    CGFloat _topOffset;
    
    CGFloat _panTranslation;
    UIPanGestureRecognizer *_panGesture;
}

#pragma mark - State Preservation and Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:_viewControllers forKey:@"viewControllers"];
    [coder encodeInteger:_pageControl.currentPage forKey:@"currentPage"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    _viewControllers = [coder decodeObjectForKey:@"viewControllers"];
    NSInteger i = [coder decodeIntegerForKey:@"currentPage"];
    
    for (UIViewController *vc in _viewControllers) {
        [self addChildViewController:vc];
        [vc didMoveToParentViewController:self];
    }
    
    _pageControl.numberOfPages = _viewControllers.count;
    _pageControl.currentPage = i;
}

#pragma mark - View initialization

- (UIViewController *)_viewControllerForFullScreenPresentationFromView:(UIView *)view {
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.restorationIdentifier = NSStringFromClass([self class]);
    self.view.backgroundColor = [UIColor blackColor];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
    
    // Set up the recognizer to move our webview
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                          action:@selector(_moveWebView:)];
    _panGesture.delegate = self;
    
    CGRect b = self.view.bounds;
    __strong SGPageToolbar *toolbar = [[SGPageToolbar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, kSGToolbarHeight)
                                                                   browserDelegate:self];
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
    [button addTarget:_toolbar action:@selector(showBrowserMenu:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    _menuButton = button;
    
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
    scroller.autoresizesSubviews = NO;
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
    
    __strong UIPageControl *pageCtrl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, b.size.height - 25.,
                                                                                       b.size.width, 25.)];
    [self.view insertSubview:pageCtrl belowSubview:_scrollView];
    _pageControl = pageCtrl;
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_pageControl addTarget:self action:@selector(_updatePage) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:toolbar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Otherwise this is loaded during restoration
    if (_viewControllers == nil) {
        _viewControllers = [NSMutableArray arrayWithCapacity:10];
        [self loadSavedTabs];
    }
    
    [self _layout];
    [self _layoutScrollviews];
    [self _layoutPages];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Take care of the top offset
    [self _layoutScrollviews];
    [self _layoutPages];
    if (!_exposeMode) {
        [self _enableInteractions];
    }
}

/*! Set the delegate to nil because the scrollview delegate gets weird scroll values */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    _scrollView.delegate = nil;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self _layout];
    [self _layoutScrollviews];
    [self _layoutPages];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    _scrollView.delegate = self;
}

/*! Set the delegate to nil because the scrollview delegate gets weird scroll values */
#ifdef __IPHONE_8_0
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    _scrollView.delegate = nil;
    //_animatedScrolling = YES;
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinator> handler) {
        [self _layout];
        [self _layoutScrollviews];
        [self _layoutPages];
    } completion:^(id<UIViewControllerTransitionCoordinator> handler) {
        _scrollView.delegate = self;
    }];
}
#endif

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self _layout];
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
    
    if (SG_CONTAINER_EMPTY) {
        [_viewControllers addObject:childController];
        _pageControl.currentPage = 0;
    } else {
        NSInteger index = _pageControl.currentPage+1;
        [_viewControllers insertObject:childController atIndex:index];
    }
    [self addChildViewController:childController];
    _pageControl.numberOfPages = _viewControllers.count;
    
    [self _layoutScrollviews];
    [self _layoutPages];
    [childController didMoveToParentViewController:self];
}

- (void)showViewController:(UIViewController *)viewController{
    NSUInteger index = [_viewControllers indexOfObject:viewController];
    if (index != NSNotFound) {
        _pageControl.currentPage = index;
        CGPoint off = CGPointMake(_scrollView.frame.size.width * index, 0);

        [self _disableInteractions];
        [self _setCloseButtonHidden:self.count != 1];
        if (CGRectGetMinY(_toolbar.frame) < 0) {
            [UIView animateWithDuration:SG_DURATION/2
                             animations:^{
                                 [self _layoutPages];
                                 [self _setToolbarHidden:NO animated:NO];
                             } completion:^(BOOL animated) {
                                 [_scrollView setContentOffset:off animated:YES];
                             }];
        } else {
            [_scrollView setContentOffset:off animated:YES];
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
                         _pageControl.numberOfPages = count;
                         _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * count, 1);
                         for (NSUInteger i = index; i < count; i++) {
                             UIViewController *vc = _viewControllers[i];
                             vc.view.center = CGPointMake(vc.view.center.x - _scrollView.frame.size.width,
                                                       vc.view.center.y);
                         }
                     }
                     completion:^(BOOL done){
                         [childController removeFromParentViewController];
                         [self _layoutScrollviews];
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
    
    if (!old) {
        [self addViewController:viewController];
    } else if (![_viewControllers containsObject:viewController]) {
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
                                    [self _layoutScrollviews];
                                    [self updateInterface];
                                    
                                    if (!_exposeMode) {
                                        [self _enableInteractions];
                                    }
                                }];
    }
}

/*! Updates interface contents */
- (void)updateInterface {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    _titleLabel.text = [self selectedViewController].title;
    [_toolbar updateInterface];
    
    _tabsButton.enabled = !SG_CONTAINER_EMPTY;
    NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)self.count];
    [_tabsButton setTitle:text forState:UIControlStateNormal];
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
    _pageControl.frame = CGRectMake(0, b.size.height - 25., b.size.width, 25.);
    
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        _topOffset = [self.topLayoutGuide length];
    }
    CGFloat toolbarH = kSGToolbarHeight+_topOffset;
    if (_exposeMode) {
        _toolbar.frame = CGRectMake(0, -toolbarH, b.size.width, toolbarH);
        _scrollView.frame = CGRectMake(0, toolbarH, b.size.width, b.size.height - (toolbarH));
    } else {
        _toolbar.frame = CGRectMake(0, _toolbar.frame.origin.y, b.size.width, toolbarH);
        _scrollView.frame = b;
    }
    
    CGSize size = [[_addTabButton titleForState:UIControlStateNormal]
                   sizeWithAttributes:@{NSFontAttributeName:_addTabButton.titleLabel.font}];
    _addTabButton.frame = CGRectMake(5, _topOffset + 10, 40 + size.width, size.height);
    _menuButton.frame = CGRectMake(b.size.width - 80, _topOffset + 4, 36, 36);
    _tabsButton.frame = CGRectMake(b.size.width - 40, _topOffset + 4, 36, 36);
    _titleLabel.frame = CGRectMake(5, kSGToolbarHeight + _topOffset + 1,
                                   b.size.width - 5, _titleLabel.font.lineHeight);
}

- (void)_layoutScrollviews {
    NSUInteger current = _pageControl.currentPage;
    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * _viewControllers.count, 1);
    CGPoint off = CGPointMake(_scrollView.frame.size.width * current, 0);
    _scrollView.contentOffset = off;
    
    UIEdgeInsets ins = _exposeMode ? UIEdgeInsetsZero : UIEdgeInsetsMake(0, 0,
                                                                         _toolbar.frame.size.height, 0);
    UIViewController *vc = self.selectedViewController;
    if ([vc isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *web = (SGWebViewController *)vc;
        web.webView.scrollView.contentInset = ins;
    }
}

/*! Managing the visible viewcontrollers, only 3 are added to the scrollview at a time */
- (void)_layoutPages {
    
    NSInteger current = _pageControl.currentPage;
    for (NSInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *vc = _viewControllers[i];
        CGSize size = _scrollView.bounds.size;
        if (current - 1  <= i && i <= current + 1) {// Just keep a max of 3 views around
            
            // Just in case reset the transform
            vc.view.transform = CGAffineTransformIdentity;
            
            if (!_exposeMode
                && i == current
                && vc.view.userInteractionEnabled
                && [vc isKindOfClass:[SGWebViewController class]]) {
                CGFloat y = CGRectGetMaxY(_toolbar.frame);
                vc.view.frame = CGRectMake(size.width * i, y,
                                           size.width, size.height);
            } else {
                CGFloat y = _toolbar.frame.size.height;
                vc.view.frame = CGRectMake(size.width * i, y,
                                           size.width, size.height-y);
            }
            
            if (_exposeMode) {
                vc.view.transform = SG_EXPOSED_TRANSFORM;
            }
            if (!vc.view.superview) {
                [_scrollView addSubview:vc.view];
            }
        } else if (vc.view.superview) {
            [vc.view removeFromSuperview];
        }
    }
    if ([_viewControllers count] > 0) {
        UIViewController *vc = _viewControllers[current];
        CGPoint point = vc.view.frame.origin;
        _closeButton.center = [self.view convertPoint:point fromView:_scrollView];
    }
}

/*! Scale the child viewcontroller's if a user swipes left or right */
- (void)_scalePages {
    CGFloat offset = _scrollView.contentOffset.x;
    CGFloat width = _scrollView.frame.size.width;
    
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *vc = _viewControllers[i];
        if (_exposeMode) {
            vc.view.transform = SG_EXPOSED_TRANSFORM;
        } else {
            
            CGFloat y = i * width;// Position of view
            CGFloat rel = MIN(MAX(fabs(offset-y)/width, 0.f), 1.f);
            CGFloat scaleX = MAX(kSGMinXScale, expf(-rel));
            CGFloat scaleY = MAX(kSGMinYScale, expf(-rel));
            
            vc.view.transform = CGAffineTransformMakeScale(scaleX, scaleY);
        }
    }
}

- (void)_setCloseButtonHidden:(BOOL)hidden {
    if (!SG_CONTAINER_EMPTY) {
        _closeButton.hidden = !_exposeMode || hidden;
    } else {
        _closeButton.hidden = YES;
    }
}

/*! Setting the currently selecte view as the one which receives the scrolls to top gesture */
- (void)_enableInteractions {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        BOOL enable = (i == _pageControl.currentPage);
        
        UIViewController *vc = _viewControllers[i];
        if ([vc isKindOfClass:[SGWebViewController class]]) {
            
            SGWebViewController *webC = (SGWebViewController *)vc;
            webC.webView.scrollView.scrollsToTop = enable;
            webC.webView.scrollView.delegate = enable ? self : nil;
            
            if (enable && webC.view != _panGesture.view) {
                [webC.view addGestureRecognizer:_panGesture];
            }
        }
        vc.view.clipsToBounds = !enable;
        vc.view.userInteractionEnabled = enable;
    }
}

/*! Disabling the gesture for everyone */
- (void)_disableInteractions {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        
        UIViewController *vc = _viewControllers[i];
        if ([vc isKindOfClass:[SGWebViewController class]]) {
            SGWebViewController *webC = (SGWebViewController *)vc;
            webC.webView.scrollView.scrollsToTop = NO;
            webC.webView.scrollView.delegate = nil;
        }
        vc.view.clipsToBounds = YES;
        vc.view.userInteractionEnabled = NO;
    }
}

- (void)_setToolbarHidden:(BOOL)hidden animated:(BOOL)animated {
    if (!_exposeMode) {
        
        [UIView animateWithDuration:animated ? SG_DURATION : 0
                         animations:^{
                             CGRect b = self.view.bounds;
                             CGFloat h = _toolbar.frame.size.height;
                             if (hidden) {
                                 _toolbar.frame = CGRectMake(0, -kSGToolbarHeight, b.size.width, h);
                                 [_toolbar setSubviewsAlpha:0];
                             } else {
                                 _toolbar.frame = CGRectMake(0, 0, b.size.width, h);
                                 [_toolbar setSubviewsAlpha:1];
                             }
                             [self _layoutPages];

                         } completion:^(BOOL finished){
                             [self updateInterface];
                         }];
    }
}

- (void)setExposeMode:(BOOL)exposeMode animated:(BOOL)animated {
    _exposeMode = exposeMode;
    if (exposeMode) {
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
            [self setNeedsStatusBarAppearanceUpdate];
        }
        [_toolbar.searchField resignFirstResponder];
        [self _disableInteractions];
        [self _setCloseButtonHidden:NO];
        
        UITapGestureRecognizer *rec = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(_tappedViewController:)];
        rec.cancelsTouchesInView = NO;
        [self.view addGestureRecognizer:rec];
    } else {
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
            [self setNeedsStatusBarAppearanceUpdate];
        }
        [self _enableInteractions];
        [self _setCloseButtonHidden:YES];
        
        UITapGestureRecognizer *rec = [self.view.gestureRecognizers lastObject];
        if (rec != nil) {
            [self.view removeGestureRecognizer:rec];
        }
    }
    
    [UIView animateWithDuration:animated ? SG_DURATION : 0
                     animations:^{
                         if (!_exposeMode) {
                             CGRect frame = _toolbar.frame;
                             frame.origin.y = 0;
                             _toolbar.frame = frame;
                         }
                         [self _layout];
                         [self _layoutScrollviews];
                         [self _layoutPages];
                     }
                     completion:^(BOOL finished) {
                         _addTabButton.enabled = exposeMode;
                         _menuButton.enabled = exposeMode;
                         _tabsButton.enabled = exposeMode;
                         [self updateInterface];
                     }];
}

- (void)setExposeMode:(BOOL)exposeMode {
    [self setExposeMode:exposeMode animated:NO];
}


#pragma mark - UIGestureRecognizer

- (IBAction)_moveWebView:(UIPanGestureRecognizer *)recognizer {
    if (![self.selectedViewController isKindOfClass:[SGWebViewController class]]) return;
    
    SGWebViewController *webC = (SGWebViewController *)self.selectedViewController;
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:{
            _panTranslation = [recognizer translationInView:webC.view].y;
        }
            break;
            
        case UIGestureRecognizerStateChanged:{
            
            CGPoint trans = [recognizer translationInView:webC.view];
            CGFloat offset = trans.y - _panTranslation;
            _panTranslation = trans.y;
            
            CGRect next = CGRectOffset(_toolbar.frame, 0, offset);
            if (next.origin.y >= -kSGToolbarHeight && next.origin.y <= 0) {
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
            CGFloat y = _toolbar.frame.origin.y;
            if (y != -kSGToolbarHeight
                && y < -kSGToolbarHeight/2) {
                [self _setToolbarHidden:YES animated:YES];
            } else if (y != 0 && y > -kSGToolbarHeight/2) {
                [self _setToolbarHidden:NO animated:YES];
            }
            _panTranslation = 0;
        }
            break;
        default:
            break;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == _panGesture) {
        UIWebView *webC = (UIWebView *)_panGesture.view;
        if (CGRectGetMaxY(_toolbar.frame) == 0
            && webC.scrollView.contentSize.height < _scrollView.bounds.size.height) {
            return NO;
        }
    
        CGPoint trans = [_panGesture translationInView:webC];
        CGFloat offset = trans.y - _panTranslation;
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
    if (scrollView == _scrollView) {
        [self _setCloseButtonHidden:YES];
        [self _disableInteractions];
        if (CGRectGetMinY(_toolbar.frame) < 0) {
            [self _setToolbarHidden:NO animated:NO];
        }
        [self _layoutPages];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == _scrollView) {// In this case it's the horizontal scrollview
        
        CGFloat offset = scrollView.contentOffset.x;
        CGFloat width = scrollView.frame.size.width;
        
        // Don't do anything state changing when animating,
        NSInteger nextPage = (NSInteger)fabs((offset+(width/2))/width);
        if (nextPage != _pageControl.currentPage) {
            _pageControl.currentPage = nextPage;
            // Make the next page appear
            [self _layoutPages];
            [self updateInterface];
        }
        [self _scalePages];
        
        // Workaround in case scrollViewWillBeginDragging is not called
        UIViewController *vc = [self selectedViewController];
        if (vc.view.clipsToBounds == NO) {
            [self _disableInteractions];
        }
        // We need to unhide it if we scroll sideways
        if (_toolbar.frame.origin.y != 0) {
            [self _setToolbarHidden:NO animated:YES];
        }
    }
}

// Always called when animating
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (scrollView == _scrollView) {
        if (_exposeMode) {
            [self _disableInteractions];
        } else {
            [self _enableInteractions];
        }
        
        [self _setCloseButtonHidden:NO];
        [self _layout];
        [self _layoutScrollviews];
        [self _layoutPages];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        // This may need to be changed if -scrollViewDidEndDecelerating changes
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

// Only called when the user does it
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == _scrollView) {
        if (_exposeMode) {
            [self _disableInteractions];
        } else {
            [self _enableInteractions];
        }
        
        [self _setCloseButtonHidden:NO];
        [self _layoutPages];
        
    } else {// We got a webView scrolling
        CGFloat y = _toolbar.frame.origin.y;
        if (y != -kSGToolbarHeight
            && y < -kSGToolbarHeight/2) {
            [self _setToolbarHidden:YES animated:YES];
        } else if (y != 0 && y > -kSGToolbarHeight/2) {
            [self _setToolbarHidden:NO animated:YES];
        }
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    if (scrollView != _scrollView) {// Only for a webview
        [self _setToolbarHidden:NO animated:YES];
    }
}

#pragma mark - IBAction

/*! Update the displayed controller, if the user taps the UIPageControl */
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
