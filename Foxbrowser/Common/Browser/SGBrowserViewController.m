//
//  SGBrowserViewController.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 15.12.12.
//
//
//  Copyright (c) 2012 Simon Peter Grätzer
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

#import "SGBrowserViewController.h"
#import "SGBlankController.h"
#import "SGWebViewController.h"
#import "SGAppDelegate.h"
#import "GAI.h"

#define HTTP_AGENT6 @"Mozilla/5.0 (iPad; CPU OS 6_1_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B146 Safari/8536.25"

@implementation SGBrowserViewController {
    NSTimer *_saveTimer;
    NSTimer *_interfaceTimer;
    
    int _dialogResult;
    NSMutableArray *_httpsHosts;
}

+ (void)initialize {
    NSMutableDictionary *dictionary;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        dictionary[@"User-Agent"] = HTTP_AGENT6;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableDoNotTrackKey]) {
        dictionary[@"X-Do-Not-Track"] = @"1";
        dictionary[@"DNT"] = @"1";
        dictionary[@"X-Tracking-Choice"] = @"do-not-track";
    }
    [CustomHTTPProtocol setHeaders:dictionary];
    [CustomHTTPProtocol start];
}

- (void)willEnterForeground {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableHTTPStackKey]) {
        [CustomHTTPProtocol setDelegate:self];
        [CustomHTTPProtocol start];
    } else {
        [CustomHTTPProtocol setDelegate:nil];
        [CustomHTTPProtocol stop];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self willEnterForeground];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _saveTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                              target:self
                                            selector:@selector(saveCurrentTabs)
                                            userInfo:nil repeats:YES];
    _interfaceTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                       target:self
                                                     selector:@selector(updateInterface)
                                                     userInfo:nil repeats:YES];
    
    [appDelegate.tracker set:kGAIScreenName value:@"SGBrowserViewController"];
    [appDelegate.tracker send:[[GAIDictionaryBuilder createAppView] build]];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_saveTimer invalidate];
    _saveTimer = nil;
    [_interfaceTimer invalidate];
    _interfaceTimer = nil;
}

- (BOOL)shouldAutorotate {
    return self.presentedViewController ? [self.presentedViewController shouldAutorotate] : YES;
}

#pragma mark - Abstract methods
- (void)addViewController:(UIViewController *)childController {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
- (void)showViewController:(UIViewController *)viewController {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
- (void)removeViewController:(UIViewController *)childController {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
- (void)removeIndex:(NSUInteger)index {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
- (void)swapCurrentViewControllerWith:(UIViewController *)viewController {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
- (void)updateInterface {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {return nil;}
- (UIViewController *)selectedViewController {return nil;}
- (NSUInteger)selectedIndex {return NSNotFound;}
- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
- (NSUInteger)count {return 0;}
- (NSUInteger)maxCount {return 0;}

#pragma mark - Implemented

- (void)addTab; {
    if (self.count >= self.maxCount)
        return;
    
    UIViewController *viewC;
    
    NSString *startpage = [[NSUserDefaults standardUserDefaults] stringForKey:kSGStartpageURLKey];
    NSURL *url = [NSURL URLWithString:startpage];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableStartpageKey] && url) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        SGWebViewController *webC = [SGWebViewController new];
        webC.title = request.URL.absoluteString;
        [webC openRequest:request];
        viewC = webC;
    } else {
        viewC = [SGBlankController new];
    }
    
    [self addViewController:viewC];
    [self showViewController:viewC];
    [self updateInterface];
}

- (void)addTabWithURLRequest:(NSURLRequest *)request title:(NSString *)title {
    if (!title)
        title = request.URL.absoluteString;
    title = [title stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    title = [title stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    
    SGWebViewController *webC = [[SGWebViewController alloc] initWithNibName:nil bundle:nil];
    webC.title = title;
    [webC openRequest:request];
    [self addViewController:webC];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.tabs.foreground"])
        [self showViewController:webC];
    
    if (self.count >= self.maxCount) {
        if ([self selectedIndex] != 0)
            [self removeIndex:0];
        else
            [self removeIndex:1];
    }
    [self updateInterface];
}

- (void)reload; {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC reload];
        [self updateInterface];
    }
}

- (void)stop {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC.webView stopLoading];
        [self updateInterface];
    }
}

- (BOOL)isLoading {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        return webC.loading;
    }
    return NO;
}

- (void)goBack; {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC.webView goBack];
        [self updateInterface];
    }
}

- (void)goForward; {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC.webView goForward];
        [self updateInterface];
    }
}

- (BOOL)canGoBack; {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        return [webC.webView canGoBack];
    }
    return NO;
}

- (BOOL)canGoForward; {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        return [webC.webView canGoForward];
    }
    return NO;
}

- (BOOL)canStopOrReload {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        return YES;
    }
    return NO;
}

- (NSURL *)URL {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        return webC.request.URL;
    }
    return nil;
}

- (void)openURLRequest:(NSMutableURLRequest *)request title:(NSString *)title {
    NSParameterAssert(request);
    if (!title) title = request.URL.absoluteString;
    title = [title stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    title = [title stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    
    if ([self.selectedViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        webC.title = title;
        [webC openRequest:request];
    } else {
        SGWebViewController *webC = [SGWebViewController new];
        webC.title = title;
        [webC openRequest:request];
        [self swapCurrentViewControllerWith:webC];
    }
}

- (void)handleURLString:(NSString*)input title:(NSString *)title {
    NSURL *url = [[WeaveOperations sharedOperations] parseURLString:input];
    [self openURLRequest:[NSMutableURLRequest requestWithURL:url] title:title];
}

- (void)findInPage:(NSString *)searchPage {
    if ([self.selectedViewController isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC search:searchPage];
    }
}

- (NSString *)savedTabsCacheFile {
    NSString* path = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).lastObject;
    return [path stringByAppendingPathComponent:@"latestURLs.plist"];
}

- (void)loadSavedTabs {
    NSArray *latest = [NSArray arrayWithContentsOfFile:[self savedTabsCacheFile]];
    if (latest.count > 1) {
        
        for (id item in latest) {
            if (![item isKindOfClass:[NSString class]]) continue;
            
            NSURL *url = [NSURL URLWithString:item];
            id viewC;
            if ([url.scheme hasPrefix:@"http"]) {
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                SGWebViewController *webC = [[SGWebViewController alloc] initWithNibName:nil bundle:nil];
                webC.title = request.URL.absoluteString;
                [webC openRequest:request];
                [self addViewController:webC];
                viewC = webC;
            } else {
                SGBlankController *blank = [SGBlankController new];
                [self addViewController:blank];
                viewC = blank;
            }
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                [self showViewController:viewC];
            }
        }
    } else {
        NSString *startpage = [[NSUserDefaults standardUserDefaults] stringForKey:kSGStartpageURLKey];
        NSURL *url = [NSURL URLWithString:startpage];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableStartpageKey] && url) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            SGWebViewController *webC = [SGWebViewController new];
            webC.title = request.URL.absoluteString;
            [webC openRequest:request];
            [self addViewController:webC];
        } else {
            SGBlankController *latest = [SGBlankController new];
            [self addViewController:latest];
        }
    }
    
    if ([latest.lastObject isKindOfClass:[NSNumber class]])
        self.selectedIndex = [latest.lastObject unsignedIntegerValue];
}

- (void)saveCurrentTabs {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSMutableArray *latest = [NSMutableArray arrayWithCapacity:self.count];
        
        for (NSUInteger i = 0; i < self.count; i++) {
            UIViewController *controller = [self viewControllerAtIndex:i];

            if ([controller isKindOfClass:[SGWebViewController class]]) {
                NSURL *url = ((SGWebViewController *)controller).request.URL;
                if ([url.scheme hasPrefix:@"http"]) [latest addObject:[NSString stringWithFormat:@"%@",url]];
                
            } else [latest addObject:@"empty://about:blank"];
        }
        [latest addObject:@(self.selectedIndex)];
        [latest writeToFile:[self savedTabsCacheFile] atomically:YES];
    });
}

- (UIViewController *)createNewTabViewController {
    NSString *startpage = [[NSUserDefaults standardUserDefaults] stringForKey:kSGStartpageURLKey];
    NSURL *url = [NSURL URLWithString:startpage];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableStartpageKey] && url) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        SGWebViewController *webC = [SGWebViewController new];
        webC.title = request.URL.absoluteString;
        [webC openRequest:request];
        return webC;
    } else {
        return [SGBlankController new];
    }
}

#pragma mark - HTTP Authentication

- (BOOL)customHTTPProtocol:(CustomHTTPProtocol *)protocol canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
// A CustomHTTPProtocol delegate callback, called when the protocol needs to process
// an authentication challenge.  In this case we accept any server trust authentication
// challenges.
{
    assert(protocol != nil);
#pragma unused(protocol)
    assert(protectionSpace != nil);
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]
    || [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]
    || [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest];
}

- (void)customHTTPProtocol:(CustomHTTPProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        SecTrustResultType  trustResult;
        SecTrustRef         trust = challenge.protectionSpace.serverTrust;
        if (trust != NULL) {
            OSStatus err = SecTrustEvaluate(trust, &trustResult);
            if (err == noErr && ((trustResult == kSecTrustResultProceed) || (trustResult == kSecTrustResultUnspecified)) ) {
                [protocol resolveAuthenticationChallenge:challenge
                                          withCredential:[NSURLCredential credentialForTrust:trust]];
                return;
            }
        }
        // Decide if we can safely ignore this
        [self customHTTPProtocol:protocol canIgnoreAuthenticationChallenge:challenge];
    } else {
        [self customHTTPProtocol:protocol resolveAuthenticationChallenge:challenge];
    }
}

- (void)customHTTPProtocol:(CustomHTTPProtocol *)protocol resolveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    // The protocol states you shall execute the response on the same thread.
    // So show the prompt on the main thread and wait until the result is finished
    dispatch_async(dispatch_get_main_queue(), ^{
        self.credentialsPrompt = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Authorizing", @"Authorizing")
                                                            message:NSLocalizedString(@"Please enter your credentials", @"HTTP Basic auth")
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
                                                  otherButtonTitles:NSLocalizedString(@"OK", @"ok"), nil];
        self.credentialsPrompt.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
        if (challenge.proposedCredential != nil) {
            [self.credentialsPrompt textFieldAtIndex:0].text = challenge.proposedCredential.user;
            if (challenge.previousFailureCount == 0) {
                [self.credentialsPrompt textFieldAtIndex:1].text = challenge.proposedCredential.password;
            }
        }
        [self.credentialsPrompt show];
    });
    
    _dialogResult = -1;
    NSDate* LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
    while ((_dialogResult==-1) && ([[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:LoopUntil]))
        LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
    
    NSString *user = [self.credentialsPrompt textFieldAtIndex:0].text;
    NSString *password = [self.credentialsPrompt textFieldAtIndex:1].text;
    
    if (_dialogResult == 1) {
        NSURLCredential *credential = [NSURLCredential credentialWithUser:user
                                                                 password:password
                                                              persistence:NSURLCredentialPersistenceForSession];
        [[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential:credential
                                                            forProtectionSpace:challenge.protectionSpace];
        [protocol resolveAuthenticationChallenge:challenge withCredential:credential];
    } else {
        DLog(@"Cancel authenctication");
        [protocol resolveAuthenticationChallenge:challenge withCredential:nil];
    }
    self.credentialsPrompt = nil;
}

- (void)customHTTPProtocol:(CustomHTTPProtocol *)protocol canIgnoreAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    NSString *host = protocol.request.URL.host;
    if (!_httpsHosts) {
        _httpsHosts = [NSMutableArray arrayWithCapacity:10];
    } else if ([_httpsHosts containsObject:host]) {
        [protocol resolveAuthenticationChallenge:challenge
                                  withCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *warning = NSLocalizedString(@"Failed to verify the identity of \"%@\"\nThis is potentially dangerous. Would you like to continue anyway?", nil);
        NSString *message = [NSString stringWithFormat:warning, host];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Verify Server Identity", @"Untrusted certificate")
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
                                              otherButtonTitles:NSLocalizedString(@"Continue", nil), nil];
        [alert show];
    });
    
    [_httpsHosts addObject:host];// Remove it later if user taps cancel
    [protocol resolveAuthenticationChallenge:challenge
                              withCredential:nil];
}

- (void)customHTTPProtocol:(CustomHTTPProtocol *)protocol didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    _dialogResult = -1;
    [self.credentialsPrompt dismissWithClickedButtonIndex:-1 animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    _dialogResult = buttonIndex;
    
    if (alertView != self.credentialsPrompt) {
        if (buttonIndex == 1) [self reload];
        else [_httpsHosts removeLastObject];
    }
}

@end
