//
//  SGPageViewController.m
//  SGPageController
//
//  Created by Simon Grätzer on 13.12.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGPageViewController.h"
#import "SGPageToolbar.h"

@implementation SGPageViewController {
    NSMutableArray *_viewControllers;
}

- (void)loadView {
    CGRect frame = [UIScreen mainScreen].bounds;
    self.view = [[UIView alloc] initWithFrame:frame];
    
    _viewControllers = [NSMutableArray arrayWithCapacity:10];
    _pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, frame.size.height - 25. - 30,
                                                                   frame.size.width, 25.)];
    [self.view addSubview:_pageControl];
    
    _toolbar = [[SGPageToolbar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 44.) browser:self];
    [self.view addSubview:_toolbar];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 45., frame.size.width, frame.size.height-45.)];
    [self.view addSubview:_scrollView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    self.scrollView.delegate = self;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight);
    
    self.pageControl.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
    [self.pageControl addTarget:self action:@selector(updatePage) forControlEvents:UIControlEventValueChanged];
    
    [self addSavedTabs];
    
//    CALayer *topShadowLayer = [CALayer layer];
//    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(-10, -10, 10000, 13)];
//    topShadowLayer.frame = CGRectMake(-320, 0, 10000, 20);
//    topShadowLayer.masksToBounds = YES;
//    topShadowLayer.shadowOffset = CGSizeMake(2.5, 2.5);
//    topShadowLayer.shadowOpacity = 0.5;
//    topShadowLayer.shadowPath = [path CGPath];
//    [self.scrollView.layer addSublayer:topShadowLayer];
//    
//    CALayer *bottomShadowLayer = [CALayer layer];
//    path = [UIBezierPath bezierPathWithRect:CGRectMake(10, 10, 10000, 13)];
//    bottomShadowLayer.frame = CGRectMake(-320, self.scrollView.frame.size.height-35, 10000, 20);//TODO
//    bottomShadowLayer.masksToBounds = YES;
//    bottomShadowLayer.shadowOffset = CGSizeMake(-2.5, -2.5);
//    bottomShadowLayer.shadowOpacity = 0.5;
//    bottomShadowLayer.shadowPath = [path CGPath];
//    [self.scrollView.layer addSublayer:bottomShadowLayer];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        
        viewController.view.transform = CGAffineTransformIdentity;
        viewController.view.frame = CGRectMake(self.scrollView.frame.size.width * i,
                                               0,
                                               self.scrollView.frame.size.width,
                                               self.scrollView.frame.size.height);
    }
    
    // go to the right page
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * _viewControllers.count, 1);
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*self.pageControl.currentPage, 0)
                             animated:NO];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Methods

- (void)addViewController:(UIViewController *)childController; {
    NSUInteger index = _viewControllers.count;
    [_viewControllers addObject:childController];
    [self addChildViewController:childController];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
        [childController beginAppearanceTransition:YES animated:NO];
    
    childController.view.transform = CGAffineTransformIdentity;
    childController.view.frame = CGRectMake(self.scrollView.frame.size.width * index,
                                           0,
                                           self.scrollView.frame.size.width,
                                           self.scrollView.frame.size.height);
    
    CALayer *layer = childController.view.layer;
    layer.shadowOpacity = .5f;
    layer.shadowOffset = CGSizeMake(10, 0);
    layer.shadowPath = [UIBezierPath bezierPathWithRect:childController.view.bounds].CGPath;
    
    [self.scrollView addSubview:childController.view];
    
    self.pageControl.numberOfPages = index+1;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * _viewControllers.count, 1);
        
    [childController didMoveToParentViewController:self];
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
        [childController endAppearanceTransition];
}

- (void)showViewController:(UIViewController *)viewController {
    NSUInteger index = [_viewControllers indexOfObject:viewController];
    if (index != NSNotFound) {
        self.pageControl.currentPage = index;
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*index, 0)
                                 animated:YES];
    }
}

- (void)removeViewController:(UIViewController *)childController withIndex:(NSUInteger)index {
    [childController willMoveToParentViewController:nil];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
        [childController beginAppearanceTransition:NO animated:NO];
    
    NSUInteger count = _viewControllers.count-1;
    if (count == index && index != 0) {
        self.pageControl.currentPage = index-1;
        [self updatePage];
    }
    
    self.pageControl.numberOfPages = count;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * count, 1);
    
    [childController.view removeFromSuperview];
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
        [childController endAppearanceTransition];
    
    [childController removeFromParentViewController];
}

- (void)removeViewController:(UIViewController *)childController {
    [self removeViewController:childController withIndex:[_viewControllers indexOfObject:childController]];
}

- (void)removeIndex:(NSUInteger)index {
    [self removeViewController:_viewControllers[index] withIndex:index];
}

- (void)swapCurrentViewControllerWith:(UIViewController *)viewController {
    if (![_viewControllers containsObject:viewController]) {
        [self addChildViewController:viewController];
        
        UIViewController *old = [self selectedViewController];
        NSUInteger index = [self selected];
        
        viewController.view.frame = old.view.frame;
        
        [old willMoveToParentViewController:nil];
        [self transitionFromViewController:old
                          toViewController:viewController
                                  duration:0
                                   options:UIViewAnimationOptionAllowAnimatedContent
                                animations:NULL
                                completion:^(BOOL finished){
                                    [old removeFromParentViewController];
                                    [_viewControllers replaceObjectAtIndex:index withObject:viewController];
                                    
                                    [viewController didMoveToParentViewController:self];
                                    [self updateChrome];
                                }];
    }
}

- (void)updateChrome {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    [self.toolbar updateChrome];
};

- (UIViewController *)selectedViewController {
    return _viewControllers[self.pageControl.currentPage];
}

- (NSUInteger)selected {
    return self.pageControl.currentPage;
}

- (NSUInteger)count {
    return self.pageControl.numberOfPages;
}

- (NSUInteger)maxCount {
    return 50;
}

#pragma mark - Utility
- (IBAction)updatePage {
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*self.pageControl.currentPage, 0)
                             animated:YES];
}

- (void)arrangeChildViewControllers {
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width * _viewControllers.count, 1);
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*self.pageControl.currentPage, 0)
                             animated:NO];
    
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        viewController.view.frame = CGRectMake(self.scrollView.frame.size.width * i,
                                                0,
                                                self.scrollView.frame.size.width,
                                                self.scrollView.frame.size.height);
        
        CALayer *layer = viewController.view.layer;
        layer.shadowOpacity = .5f;
        layer.shadowOffset = CGSizeMake(10, 10);
        layer.shadowPath = [UIBezierPath bezierPathWithRect:viewController.view.bounds].CGPath;
    }
}

- (void)enableScrollsToTop {
    // FIXME: this code affects all scroll view
    for (UIViewController *viewController in _viewControllers) {
        if ([viewController.view respondsToSelector:@selector(scrollsToTop)])
            [(UIScrollView *)viewController.view setScrollsToTop:YES];
        else
            for (UIView *subview in [viewController.view subviews])
                if ([subview respondsToSelector:@selector(scrollsToTop)])
                    [(UIScrollView *)subview setScrollsToTop:YES];
    }
}

- (void)disableScrollsToTop {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        if (i == self.pageControl.currentPage)
            continue;
        
        UIViewController *viewController = _viewControllers[i];
        if ([viewController.view respondsToSelector:@selector(scrollsToTop)])
            [(UIScrollView *)viewController.view setScrollsToTop:NO];
        else
            for (UIView *subview in [viewController.view subviews])
                if ([subview respondsToSelector:@selector(scrollsToTop)])
                    [(UIScrollView *)subview setScrollsToTop:NO];
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self enableScrollsToTop];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self disableScrollsToTop];
    [self updateChrome];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offset = scrollView.contentOffset.x;
    
    CGFloat width = self.scrollView.frame.size.width;
    NSUInteger nextPage = (NSUInteger)fabsf((offset+(width/2))/width);
    if (nextPage != self.pageControl.currentPage) {
        self.pageControl.currentPage = nextPage;
        [self updateChrome];
    }
    
    
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        CGFloat y = i * width;
        CGFloat value = (offset-y)/width;
        CGFloat scale = 1.f-fabs(value);
        if (scale > 1.f) scale = 1.f;
        if (scale < .8f) scale = .8f;
        
        viewController.view.transform = CGAffineTransformMakeScale(scale, scale);
    }
    
    
//    for (UIViewController *viewController in _viewControllers) {
//        CALayer *layer = viewController.view.layer;
//        layer.shadowPath = [UIBezierPath bezierPathWithRect:viewController.view.bounds].CGPath;
//    }
}


@end
