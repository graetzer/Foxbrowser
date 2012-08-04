//
//  UIViewController+TabsController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 29.07.12.
//  Copyright (c) 2012 Cybercon GmbH. All rights reserved.
//

#import "UIViewController+TabsController.h"

@implementation UIViewController (TabsController)

- (SGTabsViewController*)tabsViewController {
    return (SGTabsViewController*)self.parentViewController;
}

@end
