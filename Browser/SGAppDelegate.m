//
//  SGAppDelegate.m
//  Foxbrowser
//
//  Created by simon on 27.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//


#import "SGAppDelegate.h"

#import "NSStringPunycodeAdditions.h"
#import "SGTabsViewController.h"
#import "SGPageViewController.h"
#import "SGFavouritesManager.h"

#import "FXSyncStock.h"
#import "FXLoginViewController.h"

#import "Reachability.h"
#import "Appirater.h"

#import "FillrSDK/Fillr.h"

SGAppDelegate *appDelegate;
NSString *const kSGEnableStartpageKey = @"org.graetzer.enableStartpage";
NSString *const kSGStartpageURLKey = @"org.graetzer.startpageurl";
NSString *const kSGOpenPagesInForegroundKey = @"org.graetzer.tabs.foreground";
NSString *const kSGSearchEngineURLKey = @"org.graetzer.search";
NSString *const kSGEnableHTTPStackKey = @"org.graetzer.httpauth";
NSString *const kSGEnableAnalyticsKey = @"org.graetzer.analytics";

// Only used in the appdelegate
NSString *const kSGBackgroundedAtTimeKey = @"kSGBackgroundedAtTimeKey";
NSString *const kSGDidRunBeforeKey = @"kSGDidRunBeforeKey";

@implementation SGAppDelegate {
    Reachability *_reachability;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    appDelegate = self;
    _reachability = [Reachability reachabilityForInternetConnection];
    [self evaluateDefaultSettings];
    
    __strong SGBrowserViewController *browser;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        browser = [SGPageViewController new];
    } else {
        browser = [SGTabsViewController new];
    }
    _browserViewController = browser;
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _window.restorationIdentifier = NSStringFromClass([UIWindow class]);
    self.window.rootViewController = browser;
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self.window makeKeyAndVisible];
    // 0.5 delay as a workaround so that modal views work
    [self performSelector:@selector(setupSync) withObject:nil afterDelay:0.5];
    //-------------- Marketing stuff -------------------------

    [[GAI sharedInstance] setTrackUncaughtExceptions:YES];
    [GAI sharedInstance].dispatchInterval = 60*5;
    self.tracker = [[GAI sharedInstance] trackerWithTrackingId:@"UA-38223136-1"];
//#ifdef DEBUG
//    [GAI sharedInstance].debug =  YES;
//#endif

    [Appirater setAppId:@"550365886"];
    [Appirater setDelegate:self];
    [Appirater setDaysUntilPrompt:1];
    [Appirater setUsesUntilPrompt:3];
    [Appirater setTimeBeforeReminding:2];
    [Appirater appLaunched:YES];
    
    [[Fillr sharedInstance] initialiseWithDevKey:@"Hehe" andUrlSchema:@"com.fillr.foxbrowser"];
    [Fillr sharedInstance].overlayInputAccessoryView = YES;
    
    return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [Appirater appEnteredForeground:YES];
    // 0.5 delay as a workaround so that modal views work
    [self performSelector:@selector(setupSync) withObject:nil afterDelay:0.5];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Analytics Opt out
    [GAI sharedInstance].optOut = [[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableAnalyticsKey];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    //stop timers, threads, spinner animations, etc.
    // note the time we were suspended, so we can decide whether to do a refresh when we are resumed
    [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970]
                                              forKey:kSGBackgroundedAtTimeKey];
    [self.browserViewController saveCurrentTabs];
    [[GAI sharedInstance] dispatch];
    
    __block UIBackgroundTaskIdentifier identifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:identifier];
        identifier = UIBackgroundTaskInvalid;
    }];
    // Just wait 10 seconds to finish uploads
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), q, ^{
        if (identifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:identifier];
        }
    });
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [self.browserViewController saveCurrentTabs];
}

- (UIViewController *)application:(UIApplication *)application
viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents
                            coder:(NSCoder *)coder {
    
    NSString *last = [identifierComponents lastObject];
    if ([last isEqualToString:NSStringFromClass([SGTabsViewController class])]
        || [last isEqualToString:NSStringFromClass([SGPageViewController class])] ) {
        return _browserViewController;
    }
    return nil;
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder {
    return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder {
    NSString* version = [[NSBundle mainBundle].infoDictionary objectForKey:(NSString *)kCFBundleVersionKey];
    NSString* storedVersion = [coder decodeObjectForKey: UIApplicationStateRestorationBundleVersionKey];
    return [version isEqualToString:storedVersion];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    
    NSString *urlS = url.resourceSpecifier;
    if ([url.scheme isEqualToString:@"foxbrowser"]) {
        urlS = [NSString stringWithFormat:@"http:%@", urlS];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithUnicodeString:urlS]];
        [self.browserViewController addTabWithURLRequest:request title:sourceApplication];
        return YES;
    } else if ([url.scheme isEqualToString:@"foxbrowsers"]) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithUnicodeString:urlS]];
        [self.browserViewController addTabWithURLRequest:request title:sourceApplication];
        return YES;
    } else if ([url.scheme hasPrefix:@"http"] || [url.scheme hasPrefix:@"https"]) {
        [self.browserViewController addTabWithURLRequest:[NSMutableURLRequest requestWithURL:url] title:sourceApplication];
        return YES;
    } else if ([[Fillr sharedInstance] canHandleOpenURL:url]) {
        [[Fillr sharedInstance] handleOpenURL:url];
        
        return YES;
    }
    return NO;
}

#pragma mark - Methods

- (void)setupSync {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isReady = [[FXSyncStock sharedInstance] hasUserCredentials];
    if (isReady) {
        
        //check to see if we were suspended for 15 minutes or more, and refresh if true
        double slept = [defaults doubleForKey:kSGBackgroundedAtTimeKey];
        double now = [[NSDate date] timeIntervalSince1970];
        if ((now - slept) >= 60 * 15) {
            [[FXSyncStock sharedInstance] restock];
        }
    } else {
        
        // Only show this at start once
        BOOL didRunBefore = [defaults boolForKey:kSGDidRunBeforeKey];
        if (!didRunBefore) {
            [defaults setBool:YES forKey:kSGDidRunBeforeKey];
            [defaults synchronize];
            
            FXLoginViewController* login = [FXLoginViewController new];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:login];
            navController.modalPresentationStyle = UIModalPresentationFormSheet;
            navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            [self.browserViewController presentViewController:navController animated:YES completion:NULL];
        }
    }
}

- (void)evaluateDefaultSettings {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    id mutable = [NSMutableDictionary dictionary];
    id settings = [NSDictionary dictionaryWithContentsOfFile: [path stringByAppendingPathComponent:@"Root.plist"]];
    id specifiers = settings[@"PreferenceSpecifiers"];
    for (id prefItem in specifiers) {
        id key = prefItem[@"Key"];
        id value = prefItem[@"DefaultValue"];
        if ( key && value ) {
            mutable[key] = value;
        }
    }
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def registerDefaults:mutable];
    [def synchronize];
}

- (BOOL) canConnectToInternet; {
    return [_reachability isReachable];
}

#pragma mark - AppiraterDelegate
- (void)appiraterDidDeclineToRate:(Appirater *)appirater {
    [self.tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"Rating"
                                                               action:@"Decline"
                                                                label:nil
                                                                value:nil] build]];
}

- (void)appiraterDidOptToRate:(Appirater *)appirater {
    [self.tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"Rating"
                                                               action:@"Rate"
                                                                label:nil
                                                                value:nil] build]];
}

- (void)appiraterDidOptToRemindLater:(Appirater *)appirater {
    [self.tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"Rating"
                                                               action:@"Remind Later"
                                                                label:nil
                                                                value:nil] build]];
}

@end
