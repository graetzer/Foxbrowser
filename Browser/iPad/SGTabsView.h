//
//  SGTabsView.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SGTabsViewController, SGAddButton;

@interface SGTabsView : UIView <UIGestureRecognizerDelegate>
@property (weak, nonatomic) SGAddButton *addButton;
@property (weak, nonatomic) SGTabsViewController *tabsController;
@property (strong, nonatomic, readonly) NSMutableArray *tabs;
@property (assign, nonatomic) NSUInteger selected;

- (NSUInteger)addTab:(UIViewController *)viewController;
- (void)removeTab:(NSUInteger)index;

- (NSUInteger)indexOfViewController:(UIViewController *)controller;
- (UIViewController *)viewControllerAtIndex:(NSUInteger)index;
@end
