//
//  SGAppDelegate.m
//  Foxbrowser
//
//  Created by simon on 27.06.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGAppDelegate.h"
#import "SGTabsViewController.h"
#import "SGWebViewController.h"
#import "Reachability.h"

#import "Stockboy.h"
#import "Store.h"
#import "CryptoUtils.h"
#import "WelcomePage.h"


SGAppDelegate *appDelegate;
id<WeaveService> weaveService;

@implementation SGAppDelegate
@synthesize window = _window;
@synthesize tabsController = _tabsController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    appDelegate = self;
    weaveService = self;
    _reachability = [Reachability reachabilityForInternetConnection];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    
    self.tabsController = [SGTabsViewController new];
    self.window.rootViewController = self.tabsController;
    [self.window makeKeyAndVisible];
    
    // Weave stuff
    [self performSelector:@selector(setupWeave) withObject:nil afterDelay:0.5];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([url.scheme isEqualToString: @"http"] || [url.scheme isEqualToString: @"https"]) {
        [self.tabsController addTabWithURL:url withTitle:url.host];
        return YES;
    }
    return NO;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [self.tabsController saveCurrentURLs];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    //stop timers, threads, spinner animations, etc.
    // note the time we were suspended, so we can decide whether to do a refresh when we are resumed
    [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"backgroundedAtTime"];
    [self stopProgressSpinners];
    [Stockboy cancel];
    
    [self.tabsController saveCurrentURLs];
}

#define FIVE_MINUTES_ELAPSED (60 * 5)

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"needsFullReset"]) {
		[self eraseAllUserData];
		return;
	}
    
    //check to see if we were suspended for 5 minutes or more, and refresh if true
    double slept = [[NSUserDefaults standardUserDefaults] doubleForKey:@"backgroundedAtTime"];
    double now =[[NSDate date] timeIntervalSince1970];
    
    if ((now - slept) >= FIVE_MINUTES_ELAPSED)
    {
        [Stockboy restock];
    }
}

#pragma mark - WeaveService

- (void)setupWeave {
    [Stockboy prepare];
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	if (userDefaults != nil)
	{
		NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
        [dictionary setObject: [NSNumber numberWithBool: NO] forKey: @"useCustomServer"];
        [dictionary setObject: [NSNumber numberWithBool: YES] forKey: kWeaveUseNativeApps];			
        [[NSUserDefaults standardUserDefaults] registerDefaults: dictionary];
        [[NSUserDefaults standardUserDefaults] synchronize];
	}
    
    BOOL showedFirstRunPage = [[NSUserDefaults standardUserDefaults] boolForKey:kWeaveShowedFirstRunPage];
    if (!showedFirstRunPage)
    {
        //now show them the first launch page, which asks them if they have an account, or need to find out how to get one
        // afterwards, they will be taken to the login page, one way or ther other
        WelcomePage* welcomePage = [[WelcomePage alloc] initWithNibName:nil bundle:nil];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:welcomePage];
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self.window.rootViewController presentViewController:navController animated:YES completion:NULL];
    }
    else
    {
        //show the main page, and start up the Stockboy to get fresh data
        [Stockboy restock];
    }
}

//put up an alert explaining what just went wrong
- (void) reportErrorWithInfo: (NSDictionary*)errInfo; {
#ifdef DEBUG
    NSLog(@"Error: %@", [errInfo objectForKey:@"message"]);
#endif
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:[errInfo objectForKey:@"title"] message:[errInfo objectForKey:@"message"] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles:nil];
    [alert show];
}

//put up an alert view specific to authentication issues, allowing the user to either ignore the problem, or sign out
- (void) reportAuthErrorWithMessage: (NSDictionary*)errInfo; {
#ifdef DEBUG
    NSLog(@"Error: %@", [errInfo objectForKey:@"message"]);
#endif
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: [errInfo objectForKey:@"title"]
                                                    message:[errInfo objectForKey:@"message"] delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Not Now", @"Not Now")
                                          otherButtonTitles:NSLocalizedString(@"Sign In", @"re-authenticate"), nil];
	[alert show];
}

- (BOOL) canConnectToInternet; {
    return [_reachability isReachable];
}

- (void) startProgressSpinnersWithMessage:(NSString*)msg
{
	[[NSNotificationCenter defaultCenter] postNotificationName: kWeaveSyncStatusChangedNotification
                                                        object: nil userInfo: [NSDictionary dictionaryWithObject: msg forKey: kWeaveMessageKey]];
}

- (void) changeProgressSpinnersMessage:(NSString*)msg
{
	[[NSNotificationCenter defaultCenter] postNotificationName: kWeaveSyncStatusChangedNotification
                                                        object: nil userInfo: [NSDictionary dictionaryWithObject: msg forKey: kWeaveMessageKey]];
}

- (void) stopProgressSpinners; {
    [[NSNotificationCenter defaultCenter] postNotificationName: kWeaveSyncStatusChangedNotification
                                                        object: nil userInfo: [NSDictionary dictionaryWithObject: @"" forKey: kWeaveMessageKey]];
}

- (void) refreshViews; {
    [[NSNotificationCenter defaultCenter] postNotificationName:kWeaveDataRefreshNotification object:self];
}

- (void) login{
    // Present the WelcomePage with the TabBarController as it's parent
    WelcomePage* welcomePage = [WelcomePage new];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:welcomePage];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.tabsController presentViewController:navController animated:YES completion:NULL];
}

- (void) eraseAllUserData
{		
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
    
	// Workaround for #602419 - If the wifi is turned off, it acts as if a blank account is signed in
	// See a more detailed description in LogoutController
	
    //	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"useCustomServer"];
    //	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"customServerURL"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: kWeaveShowedFirstRunPage];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"needsFullReset"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"backgroundedAtTime"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"useSafari"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey: kWeaveUseNativeApps];
	[[NSUserDefaults standardUserDefaults] synchronize];
    
    //redraw everything
    [self refreshViews];  //make them all ditch their data
}


@end
