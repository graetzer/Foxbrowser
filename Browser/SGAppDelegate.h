//
//  SGAppDelegate.h
//  Foxbrowser
//
//  Created by simon on 27.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "AppiraterDelegate.h"

@class SGBrowserViewController;
@protocol GAITracker, AppiraterDelegate;

@interface SGAppDelegate : UIResponder <UIApplicationDelegate, AppiraterDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) SGBrowserViewController *browserViewController;
@property (strong, nonatomic) id<GAITracker> tracker;

- (BOOL)canConnectToInternet;

@end

extern SGAppDelegate *appDelegate;

FOUNDATION_EXPORT NSString *const kSGEnableStartpageKey;
FOUNDATION_EXPORT NSString *const kSGStartpageURLKey;
FOUNDATION_EXPORT NSString *const kSGOpenPagesInForegroundKey;
FOUNDATION_EXPORT NSString *const kSGSearchEngineURLKey;
FOUNDATION_EXPORT NSString *const kSGEnableHTTPStackKey;
FOUNDATION_EXPORT NSString *const kSGEnableAnalyticsKey;