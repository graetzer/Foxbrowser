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

#define SG_EXPOSED_SCALE (0.76f)
#define SG_EXPOSED_TRANSFORM (CGAffineTransformMakeScale(SG_EXPOSED_SCALE, SG_EXPOSED_SCALE))
#define SG_CONTAINER_EMPTY (_viewControllers.count == 0)

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
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 45., frame.size.width, frame.size.height-45.)];
    [self.view addSubview:_scrollView];
    
    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeButton.frame = CGRectMake(0, 0, 35, 35);
    [self.view addSubview:_closeButton];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    self.scrollView.delegate = self;
    self.scrollView.clipsToBounds = YES;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight);
    
    self.pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.pageControl addTarget:self action:@selector(updatePage) forControlEvents:UIControlEventValueChanged];
    
    NSString *text = NSLocalizedString(@"New Tab", @"New Tab");
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:20];
    CGSize size = [text sizeWithFont:font];
    
    UIButton *button  = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat lenght = 30;
    button.frame = CGRectMake(5, 10 + (size.height - lenght)/2, lenght, lenght);
    button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    button.backgroundColor  = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"plus-white"] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"plus-white"] forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchDown];
    [self.view insertSubview:button belowSubview:self.toolbar];
    
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(5 + lenght, 10, size.width, size.height);
    button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    [button setTitle:text forState:UIControlStateNormal];
    button.titleLabel.font = font;
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.backgroundColor  = [UIColor clearColor];
    [button addTarget:self action:@selector(addTab) forControlEvents:UIControlEventTouchDown];
    [self.view insertSubview:button belowSubview:self.toolbar];
    

    
    font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 45, self.view.bounds.size.width - 5, font.lineHeight)];
    _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    [self.view insertSubview:_titleLabel belowSubview:self.scrollView];
    
    self.closeButton.hidden = YES;
    self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    self.closeButton.backgroundColor  = [UIColor clearColor];
    [self.closeButton setImage:[UIImage imageNamed:@"close_x"] forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeTabButton:) forControlEvents:UIControlEventTouchDown];
    
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

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [self arrangeChildViewControllers];
    CGPoint point = self.selectedViewController.view.frame.origin;
    self.closeButton.center = [self.view convertPoint:point fromView:self.scrollView];
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

- (void)addViewController:(UIViewController *)childController; {
    NSUInteger index = 0;
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
    
    [UIView animateWithDuration:0.3
                     animations:^{
                         for (NSUInteger i = index+1; i < count; i++) {
                             UIViewController *vC = _viewControllers[i];
                             vC.view.center = CGPointMake(vC.view.center.x + self.scrollView.frame.size.width,
                                                          vC.view.center.y);
                         }
                         [self.scrollView addSubview:childController.view];
                     }
                     completion:^(BOOL done){
                         [childController didMoveToParentViewController:self];
                     }];
}

- (void)showViewController:(UIViewController *)viewController {
    NSUInteger index = [_viewControllers indexOfObject:viewController];
    if (index != NSNotFound) {
        self.pageControl.currentPage = index;
        self.closeButton.hidden = YES;//Enabled again by the scrollview delegate
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*index, 0)
                                 animated:YES];
    }
}

- (void)removeViewController:(UIViewController *)childController withIndex:(NSUInteger)index {
    if (!childController || index == NSNotFound)
        return;
    
    self.closeButton.hidden = YES;
    [childController willMoveToParentViewController:nil];
    [_viewControllers removeObjectAtIndex:index];
    
    NSUInteger count = _viewControllers.count;
    [UIView animateWithDuration:0.3
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
                         [self updateChrome];
                         
                         if (self.exposeMode)
                             self.closeButton.hidden = SG_CONTAINER_EMPTY;
                     }];
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
                                    [_viewControllers replaceObjectAtIndex:index withObject:viewController];
                                    
                                    [viewController didMoveToParentViewController:self];
                                    [self updateChrome];
                                }];
    }
}

- (void)updateChrome {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.isLoading];
    self.titleLabel.text = self.selectedViewController.title;
    [self.toolbar updateChrome];
};

- (UIViewController *)selectedViewController {
    return _viewControllers.count > 0 ? _viewControllers[self.pageControl.currentPage] : nil;
}

- (NSUInteger)selectedIndex {
    return self.pageControl.currentPage;
}

- (NSUInteger)count {
    return self.pageControl.numberOfPages;
}

- (NSUInteger)maxCount {
    return 50;
}

#pragma mark - Utility
- (void)arrangeChildViewControllers {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        UIViewController *viewController = _viewControllers[i];
        viewController.view.transform = CGAffineTransformIdentity;
        viewController.view.frame = CGRectMake(self.scrollView.frame.size.width * i,
                                               0,
                                               self.scrollView.frame.size.width,
                                               self.scrollView.frame.size.height);
        if (_exposeMode)
            viewController.view.transform = SG_EXPOSED_TRANSFORM;
    }
    
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width * _viewControllers.count, 1);
    self.scrollView.contentOffset = CGPointMake(self.view.bounds.size.width*self.pageControl.currentPage, 0);
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

- (void)enableScrollsToTop {
    for (UIViewController *viewController in _viewControllers) {
        if ([viewController isKindOfClass:[UIWebView class]])
            [((UIWebView *)viewController).scrollView setScrollsToTop:YES];
        else if ([viewController.view respondsToSelector:@selector(scrollsToTop)])
            [(UIScrollView *)viewController.view setScrollsToTop:YES];
    }
}

- (void)disableScrollsToTop {
    for (NSUInteger i = 0; i < _viewControllers.count; i++) {
        if (i == self.pageControl.currentPage)
            continue;
        
        UIViewController *viewController = _viewControllers[i];
        if ([viewController isKindOfClass:[UIWebView class]])
            [((UIWebView *)viewController).scrollView setScrollsToTop:NO];
        else if ([viewController.view respondsToSelector:@selector(scrollsToTop)])
            [(UIScrollView *)viewController.view setScrollsToTop:NO];
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.exposeMode)
        self.closeButton.hidden = YES;
    else
        [self disableScrollsToTop];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (self.exposeMode)
        self.closeButton.hidden = SG_CONTAINER_EMPTY;
    else
        [self enableScrollsToTop];
    
    [self arrangeChildViewControllers];
    [self updateChrome];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (self.exposeMode)
        self.closeButton.hidden = SG_CONTAINER_EMPTY;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offset = scrollView.contentOffset.x;
    CGFloat width = scrollView.frame.size.width;
    
    NSUInteger nextPage = (NSUInteger)fabsf((offset+(width/2))/width);
    if (nextPage != self.pageControl.currentPage) {
        self.pageControl.currentPage = nextPage;
        [self updateChrome];
    }
    
    [self scaleChildViewControllers];
}

- (void)setExposeMode:(BOOL)exposeMode {
    _exposeMode = exposeMode;
    if (exposeMode) {
        [self.toolbar.searchField resignFirstResponder];
        [self disableScrollsToTop];
        
        [UIView animateWithDuration:0.3
                         animations:^{
                             self.toolbar.frame = CGRectOffset(self.toolbar.frame, 0, -self.toolbar.frame.size.height);
                             [self scaleChildViewControllers];
                         }
                         completion:^(BOOL finished) {
                             UITapGestureRecognizer *rec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedViewController:)];
                             [self.view addGestureRecognizer:rec];
                             
                             [self arrangeChildViewControllers];
                             
                             CGPoint point = self.selectedViewController.view.frame.origin;
                             self.closeButton.center = [self.view convertPoint:point fromView:self.scrollView];
                             self.closeButton.hidden = SG_CONTAINER_EMPTY;
                         }];

    } else {
        [self enableScrollsToTop];
        self.closeButton.hidden = YES;
        [UIView animateWithDuration:0.3
                         animations:^{
                             self.toolbar.frame = CGRectOffset(self.toolbar.frame, 0,
                                                               +self.toolbar.frame.size.height);
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

- (IBAction)closeTabButton:(UIButton *)button {
    [self removeViewController:self.selectedViewController];
}

@end
