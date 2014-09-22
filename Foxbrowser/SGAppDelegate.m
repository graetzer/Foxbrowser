//
//  SGAppDelegate.m
//  Foxbrowser
//
//  Created by simon on 27.06.12.
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


#import "SGAppDelegate.h"

#import "SGTabsViewController.h"
#import "SGPageViewController.h"
#import "SGNavViewController.h"

#import "Reachability.h"
#import "Stockboy.h"
#import "Store.h"
#import "CryptoUtils.h"
#import "WelcomePage.h"
#import "SGFavouritesManager.h"

#import "SGActivityView.h"

#import "Appirater.h"

#import "FXSyncEngine.h"

SGAppDelegate *appDelegate;
id<WeaveService> weaveService;

NSString *const kSGEnableStartpageKey = @"org.graetzer.enableStartpage";
NSString *const kSGStartpageURLKey = @"org.graetzer.startpage";
NSString *const kSGOpenPagesInForegroundKey = @"org.graetzer.tabs.foreground";
NSString *const kSGEnableDoNotTrackKey = @"org.graetzer.track";
NSString *const kSGEnableHTTPStackKey = @"org.graetzer.httpauth";
NSString *const kSGEnableAnalyticsKey = @"org.graetzer.analytics";

@implementation SGAppDelegate {
    Reachability *_reachability;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    appDelegate = self;
    weaveService = self;
    _reachability = [Reachability reachabilityForInternetConnection];
    
    SGBrowserViewController *browser;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        browser = [SGPageViewController new];
    } else {
        browser = [SGTabsViewController new];
    }
    self.browserViewController = browser;
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    self.window.rootViewController = browser;
    [self.window makeKeyAndVisible];
    
    [self evaluateDefaultSettings];
    // Weave stuff. 0.5 delay as a workaround so that modal views work
//    [self performSelector:@selector(setupWeave) withObject:nil afterDelay:0.5];
    
    //-------------- Marketing stuff -------------------------
//    
//    [GAI sharedInstance].trackUncaughtExceptions = YES;
//    [GAI sharedInstance].dispatchInterval = 60*5;
//    [GAI sharedInstance].optOut = [[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableAnalyticsKey];
//    self.tracker = [[GAI sharedInstance] trackerWithTrackingId:@"UA-38223136-1"];
////#ifdef DEBUG
////    [GAI sharedInstance].debug =  YES;
////#endif
//    
//    [Appirater setAppId:@"550365886"];
//    [Appirater setDelegate:self];
//    [Appirater setDaysUntilPrompt:1];
//    [Appirater setUsesUntilPrompt:3];
//    [Appirater setTimeBeforeReminding:2];
//    
//    [Appirater appLaunched:YES];
//
    
    [[FXSyncEngine sharedInstance] startSync];
    
    return YES;
}

//- (void)applicationWillEnterForeground:(UIApplication *)application {
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//	if ([defaults boolForKey: @"needsFullReset"]) {
//		[self eraseAllUserData];
//		return;
//	}
//    //check to see if we were suspended for 5 minutes or more, and refresh if true
//    double slept = [defaults doubleForKey:kWeaveBackgroundedAtTime];
//    double now = [[NSDate date] timeIntervalSince1970];
//    if ((now - slept) >= 60 * 5) {
//        [Stockboy restock];
//    }
//    
//    // Analytics Opt out
//    [GAI sharedInstance].optOut = [defaults boolForKey:@"org.graetzer.analytics"];
//    [Appirater appEnteredForeground:YES];
//}


- (void)applicationWillTerminate:(UIApplication *)application {
//    [Stockboy cancel];
    [self.browserViewController saveCurrentTabs];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    //stop timers, threads, spinner animations, etc.
    // note the time we were suspended, so we can decide whether to do a refresh when we are resumed
    [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970]
                                              forKey:kWeaveBackgroundedAtTime];
//    [Stockboy cancel];
    [self stopProgressSpinners];
    [self.browserViewController saveCurrentTabs];
    [[GAI sharedInstance] dispatch];
    
    __block UIBackgroundTaskIdentifier identifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:identifier];
        identifier = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (identifier != UIBackgroundTaskInvalid) {
//            [[Store getStore] saveChanges];
            [[UIApplication sharedApplication] endBackgroundTask:identifier];
        }
    });
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    
    if ([SGActivityView handleURL:url
             sourceApplication:sourceApplication
                    annotation:annotation])
        return YES;
    
    NSString *urlS = url.resourceSpecifier;
    if ([url.scheme isEqualToString:@"foxbrowser"]) {
        urlS = [NSString stringWithFormat:@"http:%@", urlS];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlS]];
        [self.browserViewController addTabWithURLRequest:request title:sourceApplication];
        return YES;
    } else if ([url.scheme isEqualToString:@"foxbrowsers"]) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlS]];
        [self.browserViewController addTabWithURLRequest:request title:sourceApplication];
        return YES;
    } else if ([url.scheme hasPrefix:@"http"] || [url.scheme hasPrefix:@"https"]) {
        [self.browserViewController addTabWithURLRequest:[NSMutableURLRequest requestWithURL:url] title:sourceApplication];
        return YES;
    }
    return NO;
}

#pragma mark - WeaveService

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

- (void)setupWeave {
    [Stockboy prepare];
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	if (userDefaults != nil) {
		NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
        dictionary[@"useCustomServer"] = @NO;
        dictionary[kWeaveUseNativeApps] = @YES;	
        [userDefaults registerDefaults: dictionary];
        [userDefaults synchronize];
	}
    
    BOOL showedFirstRunPage = [userDefaults boolForKey:kWeaveShowedFirstRunPage];
    if (!showedFirstRunPage) {
        //now show them the first launch page, which asks them if they have an account, or need to find out how to get one
        // afterwards, they will be taken to the login page, one way or ther other
        [self login];
    } else {
        //show the main page, and start up the Stockboy to get fresh data
//        [Stockboy restock];
    }
}

//put up an alert explaining what just went wrong
- (void) reportErrorWithInfo: (NSDictionary*)errInfo; {
    DLog(@"Error: %@", errInfo[@"message"]);
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:errInfo[@"title"]
                                                    message:errInfo[@"message"]
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles:nil];
    [alert show];
}

//put up an alert view specific to authentication issues, allowing the user to either ignore the problem, or sign out
- (void) reportAuthErrorWithMessage: (NSDictionary*)errInfo; {
    DLog(@"Error: %@", errInfo[@"message"]);
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: errInfo[@"title"]
                                                    message:errInfo[@"message"]
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Not Now", @"Not Now")
                                          otherButtonTitles:NSLocalizedString(@"Sign In", @"re-authenticate"), nil];
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    //this handler is only called by the alert made directly below, so we know that button 1 is the signout button
    if (buttonIndex == 1) //sign out
        [self login]; //also erases user data
}

- (BOOL) canConnectToInternet; {
    return [_reachability isReachable];
}

- (void) startProgressSpinnersWithMessage:(NSString*)msg {
	[[NSNotificationCenter defaultCenter] postNotificationName: kWeaveSyncStatusChangedNotification
                                                        object: nil userInfo: @{kWeaveMessageKey: msg}];
}

- (void) changeProgressSpinnersMessage:(NSString*)msg {
	[[NSNotificationCenter defaultCenter] postNotificationName: kWeaveSyncStatusChangedNotification
                                                        object: nil userInfo: @{kWeaveMessageKey: msg}];
}

- (void) stopProgressSpinners; {
    [[NSNotificationCenter defaultCenter] postNotificationName: kWeaveSyncStatusChangedNotification
                                                        object: nil userInfo: @{kWeaveMessageKey: @""}];
}

- (void) refreshViews; {
    [[NSNotificationCenter defaultCenter] postNotificationName:kWeaveDataRefreshNotification object:self];
}

- (void) login {
    // Workaround for the bug where the credentials seem to be not saved
    [CryptoUtils deletePrivateKeys];
    
    Class navClass = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ?
    [SGNavViewController class] : [UINavigationController class];
    
    // Present the WelcomePage with the TabBarController as it's parent
    WelcomePage* welcomePage = [WelcomePage new];
    UINavigationController *navController = [[navClass alloc] initWithRootViewController:welcomePage];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self.browserViewController presentViewController:navController animated:YES completion:NULL];
}

- (void) eraseAllUserData {		
    //erase the local database
    [Store deleteStore];
    //toss the crypto stuff we have
    [CryptoUtils discardManager];
    //delete the private key from the keychain
    [CryptoUtils deletePrivateKeys];
    //delete the web browser cookies
    NSHTTPCookieStorage* storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	NSHTTPCookie *cookie;
	for (cookie in [storage cookies])  {
		[storage deleteCookie: cookie];
	}
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    [[SGFavouritesManager sharedManager] resetFavourites];
    
	// Workaround for #602419 - If the wifi is turned off, it acts as if a blank account is signed in
	// See a more detailed description in LogoutController
	
    //	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"useCustomServer"];
    //	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"customServerURL"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: kWeaveShowedFirstRunPage];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"needsFullReset"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: kWeaveBackgroundedAtTime];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"useSafari"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: kWeaveUseNativeApps];
	[[NSUserDefaults standardUserDefaults] synchronize];
    
    //redraw everything
    [self refreshViews];  //make them all ditch their data
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
