//
//  UIViewController+TabsController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 29.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SGTabsViewController.h"

@interface UIViewController (TabsController)

@property(nonatomic, readonly) SGTabsViewController *tabsViewController;

@end
