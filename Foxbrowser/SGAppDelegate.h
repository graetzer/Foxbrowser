//
//  SGAppDelegate.h
//  Foxbrowser
//
//  Created by simon on 27.06.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WeaveService.h"

@class SGBrowserViewController;
@interface SGAppDelegate : UIResponder <UIApplicationDelegate, WeaveService>

@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) SGBrowserViewController *browserViewController;

@end

extern SGAppDelegate *appDelegate;