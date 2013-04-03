//
//  SGPopoverController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 01.04.13.
//  Copyright (c) 2013 Simon Peter Grätzer. All rights reserved.
//

#import "SGPopoverController.h"
#import "SGPopoverView.h"

@implementation SGPopoverController {
    UIWindow *_myWindow;
    SGPopoverView *_popoverView;
}
@synthesize contentViewController = _contentViewController;

- (id)initWithContentViewController:(UIViewController *)viewController {
    if (self = [super init]) {
        self.popoverLayoutMargins = UIEdgeInsetsMake(10, 10, 10, 10);
        
        _myWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _myWindow.windowLevel = UIWindowLevelNormal;
        _myWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *viewC = [UIViewController new];
        viewC.view.frame = _myWindow.frame;
        viewC.view.backgroundColor = [UIColor clearColor];
        _myWindow.rootViewController = viewC;
        
        [viewC addChildViewController:viewController];
        _contentViewController = viewController;
        [viewController didMoveToParentViewController:viewC];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)setContentViewController:(UIViewController *)contentViewController {
    [self setContentViewController:contentViewController animated:NO];
}

- (void)setContentViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (!viewController) {
        [_contentViewController willMoveToParentViewController:nil];
        [_contentViewController.view removeFromSuperview];
        [_contentViewController removeFromParentViewController];
        _contentViewController = viewController;
    } else {
        [_myWindow.rootViewController transitionFromViewController:_contentViewController
                                                  toViewController:viewController
                                                          duration:animated ? 0.3 : 0
                                                           options:0
                                                        animations:NULL
                                                        completion:^(BOOL finished){
                                                            _contentViewController = viewController;
                                                        }];
    }
}

- (void)setPopoverContentSize:(CGSize)popoverContentSize {
    [self setPopoverContentSize:popoverContentSize animated:NO];
}

- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated {
    
}

- (BOOL)isPopoverVisible {
    return !_myWindow.hidden;
}

- (void)presentPopoverFromRect:(CGRect)rect
                        inView:(UIView *)view
      permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections
                      animated:(BOOL)animated; {
    
    _popoverView = [self popoverViewFromRect:rect inView:view permittedArrowDirections:arrowDirections];
    [_myWindow.rootViewController.view addSubview:_popoverView];
    
    [_myWindow makeKeyAndVisible];
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)item
               permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections
                               animated:(BOOL)animated {
    
}

- (void)dismissPopoverAnimated:(BOOL)animated {
    
}

#pragma mark - Private methods
- (void)orientationChanged:(NSNotification *)notification {
    [self dismissPopoverAnimated:NO];
}

- (SGPopoverView *)popoverViewFromRect:(CGRect)rect
                        inView:(UIView *)view
      permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections {
    
    
    
    return nil;
}

@end

