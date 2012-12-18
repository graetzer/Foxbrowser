//
//  UIViewController+SGBrowserViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 15.12.12.
//  Copyright (c) 2012 Simon Peter Grätzer. All rights reserved.
//

#import "UIViewController+SGBrowserViewController.h"
#import "SGBrowserViewController.h"

@implementation UIViewController (SGBrowserViewController)
- (SGBrowserViewController *)browserViewController {
    UIViewController *parent = self.parentViewController;
    return [parent isKindOfClass:[SGBrowserViewController class]] ?(SGBrowserViewController *)parent : nil;
}
@end
