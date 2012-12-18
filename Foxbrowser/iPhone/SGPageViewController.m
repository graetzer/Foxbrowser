//
//  SGPageViewController.m
//  SGPageController
//
//  Created by Simon Grätzer on 13.12.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGPageViewController.h"
#import "SGPageToolbar.h"

@interface SGPageViewController ()

@end

@implementation SGPageViewController

- (void)loadView {
    CGRect frame = [UIScreen mainScreen].bounds;
    self.view = [[UIView alloc] initWithFrame:frame];
    
    _pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, frame.size.height - 25. - 30,
                                                                   frame.size.width, 25.)];
    [self.view addSubview:_pageControl];
    
    _toolbar = [[SGPageToolbar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 44.) browser:self];
    [self.view addSubview:_toolbar];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 44., frame.size.width, frame.size.height-44.)];
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
    for (NSUInteger i = 0; i < self.childViewControllers.count; i++) {
        UIViewController *viewController = self.childViewControllers[i];
        
        viewController.view.transform = CGAffineTransformIdentity;
        viewController.view.frame = CGRectMake(self.scrollView.frame.size.width * i,
                                               0,
                                               self.scrollView.frame.size.width,
                                               self.scrollView.frame.size.height);
    }
    
    // go to the right page
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * self.childViewControllers.count, 1);
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*self.pageControl.currentPage, 0)
                             animated:NO];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark - Methods

- (void)addViewController:(UIViewController *)childController; {
    NSUInteger index = self.childViewControllers.count;
    [self addChildViewController:childController];
    
    childController.view.transform = CGAffineTransformIdentity;
    childController.view.frame = CGRectMake(self.scrollView.frame.size.width * index,
                                           0,
                                           self.scrollView.frame.size.width,
                                           self.scrollView.frame.size.height);
    
    CALayer *layer = childController.view.layer;
    layer.shadowOpacity = .5f;
    layer.shadowOffset = CGSizeMake(10, 10);
    layer.shadowPath = [UIBezierPath bezierPathWithRect:childController.view.bounds].CGPath;
    
    [self.scrollView addSubview:childController.view];
    
    self.pageControl.numberOfPages = index+1;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * self.childViewControllers.count, 1);
    
    [childController didMoveToParentViewController:self];
}

- (void)showViewController:(UIViewController *)viewController {
    NSUInteger index = [self.childViewControllers indexOfObject:viewController];
    if (index != NSNotFound) {
        self.pageControl.currentPage = index;
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*index, 0)
                                 animated:YES];
    }
}

- (void)removeViewController:(UIViewController *)childController withIndex:(NSUInteger)index {
    [childController willMoveToParentViewController:nil];
    
    NSUInteger count = self.childViewControllers.count-1;
    if (count == index && index != 0) {
        self.pageControl.currentPage = index-1;
        [self updatePage];
    }
    
    self.pageControl.numberOfPages = count;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * count, 1);
    
    
    [childController.view removeFromSuperview];
    [childController removeFromParentViewController];
}

- (void)removeViewController:(UIViewController *)childController {
    [self removeViewController:childController withIndex:[self.childViewControllers indexOfObject:childController]];
}

- (void)removeIndex:(NSUInteger)index {
    [self removeViewController:self.childViewControllers[index] withIndex:index];
}

- (void)swapCurrentViewControllerWith:(UIViewController *)viewController {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}

- (void)updateChrome {
    //[NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    [self.toolbar updateChrome];
};

- (UIViewController *)selectedViewController {
    return self.childViewControllers[self.pageControl.currentPage];
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
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width * self.childViewControllers.count, 1);
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*self.pageControl.currentPage, 0)
                             animated:NO];
    
    for (NSUInteger i = 0; i < self.childViewControllers.count; i++) {
        UIViewController *viewController = self.childViewControllers[i];
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
    for (UIViewController *viewController in self.childViewControllers) {
        if ([viewController.view respondsToSelector:@selector(scrollsToTop)])
            [(UIScrollView *)viewController.view setScrollsToTop:YES];
        else
            for (UIView *subview in [viewController.view subviews])
                if ([subview respondsToSelector:@selector(scrollsToTop)])
                    [(UIScrollView *)subview setScrollsToTop:YES];
    }
}

- (void)disableScrollsToTop {
    for (NSUInteger i = 0; i < self.childViewControllers.count; i++) {
        if (i == self.pageControl.currentPage)
            continue;
        
        UIViewController *viewController = self.childViewControllers[i];
        if ([viewController.view respondsToSelector:@selector(scrollsToTop)])
            [(UIScrollView *)viewController.view setScrollsToTop:NO];
        else
            for (UIView *subview in [viewController.view subviews])
                if ([subview respondsToSelector:@selector(scrollsToTop)])
                    [(UIScrollView *)subview setScrollsToTop:NO];
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self enableScrollsToTop];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGFloat offset = self.scrollView.contentOffset.x;
    CGFloat width = self.scrollView.frame.size.width;
    self.pageControl.currentPage = (offset+(width/2))/width;
    
    [self disableScrollsToTop];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offset = scrollView.contentOffset.x;
    
    CGFloat width = self.scrollView.frame.size.width;
    self.pageControl.currentPage = fabsf((offset+(width/2))/width);
    
    for (NSUInteger i = 0; i < self.childViewControllers.count; i++) {
        UIViewController *viewController = self.childViewControllers[i];
        CGFloat y = i * width;
        CGFloat value = (offset-y)/width;
        CGFloat scale = 1.f-fabs(value);
        if (scale > 1.f) scale = 1.f;
        if (scale < .8f) scale = .8f;
        
        viewController.view.transform = CGAffineTransformMakeScale(scale, scale);
    }
    
    
//    for (UIViewController *viewController in self.childViewControllers) {
//        CALayer *layer = viewController.view.layer;
//        layer.shadowPath = [UIBezierPath bezierPathWithRect:viewController.view.bounds].CGPath;
//    }
}


@end
