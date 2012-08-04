//
//  SGAppDelegate.h
//  Foxbrowser
//
//  Created by simon on 27.06.12.
//  Copyright (c) 2012 Cybercon GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WeaveService.h"

@class SGTabsViewController, Reachability;
@interface SGAppDelegate : UIResponder <UIApplicationDelegate, WeaveService> {
    Reachability *_reachability;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) SGTabsViewController *tabsController;

@end

extern SGAppDelegate *appDelegate;