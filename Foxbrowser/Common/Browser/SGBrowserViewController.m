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
#import "SGCredentialsPrompt.h"

#import "GAI.h"

#define HTTP_AGENT5 @"Mozilla/5.0 (iPad; CPU OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3"
#define HTTP_AGENT6 @"Mozilla/5.0 (iPad; CPU OS 6_0_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B146 Safari/8536.25"

@implementation SGBrowserViewController {
    NSTimer *_timer;
    int _dialogResult;
    NSMutableArray *_allowedHosts;
}

+ (void)initialize {
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 6)
        [SGHTTPURLProtocol setValue:HTTP_AGENT5 forHTTPHeaderField:@"User-Agent"];
    else
        [SGHTTPURLProtocol setValue:HTTP_AGENT6 forHTTPHeaderField:@"User-Agent"];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.track"]) {
        [SGHTTPURLProtocol setValue:@"1" forHTTPHeaderField:@"X-Do-Not-Track"];
        [SGHTTPURLProtocol setValue:@"1" forHTTPHeaderField:@"DNT"];
        [SGHTTPURLProtocol setValue:@"do-not-track" forHTTPHeaderField:@"X-Tracking-Choice"];
    }
}

- (void)willEnterForeground {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.httpauth"]) {
        [SGHTTPURLProtocol setProtocolDelegate:self];
        [SGHTTPURLProtocol registerProtocol];
    } else {
        [SGHTTPURLProtocol setProtocolDelegate:nil];
        [SGHTTPURLProtocol unregisterProtocol];
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
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:10
                                              target:self
                                            selector:@selector(saveCurrentTabs)
                                            userInfo:nil repeats:YES];
    
    [[GAI sharedInstance].defaultTracker trackView:@"SGBrowserViewController"];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_timer invalidate];
    _timer = nil;
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
- (void)updateChrome {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
}
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
        
    SGBlankController *latest = [SGBlankController new];
    [self addViewController:latest];
    [self showViewController:latest];
    [self updateChrome];
}

- (void)addTabWithURLRequest:(NSMutableURLRequest *)request title:(NSString *)title {
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
    [self updateChrome];
}

- (void)reload; {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC reload];
        [self updateChrome];
    }
}

- (void)stop {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC.webView stopLoading];
        [self updateChrome];
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
        [self updateChrome];
    }
}

- (void)goForward; {
    if ([[self selectedViewController] isKindOfClass:[SGWebViewController class]]) {
        SGWebViewController *webC = (SGWebViewController *)[self selectedViewController];
        [webC.webView goForward];
        [self updateChrome];
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

- (BOOL)canRemoveTab:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[SGBlankController class]] && self.count == 1) {
        return NO;
    }
    return YES;
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
    if (!title)
        title = request.URL.absoluteString;
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

- (void)addSavedTabs {
    NSArray *latest = [NSArray arrayWithContentsOfFile:[self savedTabsCacheFile]];
    if (latest.count > 1) {
        for (id item in latest) {
            if (![item isKindOfClass:[NSString class]])
                continue;
            
            NSURL *url = [NSURL URLWithString:item];
            if ([url.scheme hasPrefix:@"http"]) {
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                SGWebViewController *webC = [[SGWebViewController alloc] initWithNibName:nil bundle:nil];
                webC.title = request.URL.absoluteString;
                [webC openRequest:request];
                [self addViewController:webC];
            } else {
                SGBlankController *latest = [SGBlankController new];
                [self addViewController:latest];
            }
        }
    } else {
        SGBlankController *latest = [SGBlankController new];
        [self addViewController:latest];
    }
    
    if ([latest.lastObject isKindOfClass:[NSNumber class]])
        self.selectedIndex = [latest.lastObject unsignedIntegerValue];
}

- (void)saveCurrentTabs {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSMutableArray *latest = [NSMutableArray arrayWithCapacity:self.count];
        for (UIViewController *controller in self.childViewControllers) {
            
            if ([controller isKindOfClass:[SGWebViewController class]]) {
                NSURL *url = ((SGWebViewController *)controller).request.URL;
                if ([url.scheme hasPrefix:@"http"])
                    [latest addObject:[NSString stringWithFormat:@"%@",url]];
            } else
                [latest addObject:@"empty://about:blank"];
        }
        [latest addObject:@(self.selectedIndex)];
        [latest writeToFile:[self savedTabsCacheFile] atomically:YES];
    });
}


#pragma mark - HTTP Authentication

- (void)URLProtocol:(SGHTTPURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (!self.credentialsPrompt) {
        // The protocol states you shall execute the response on the same thread.
        // So show the prompt on the main thread and wait until the result is finished
        dispatch_async(dispatch_get_main_queue(), ^{
            self.credentialsPrompt = [[SGCredentialsPrompt alloc] initWithChallenge:challenge delegate:self];
            [self.credentialsPrompt show];
        });
        
        _dialogResult = -1;
        NSDate* LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
        while ((_dialogResult==-1) && ([[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:LoopUntil]))
            LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
        
        SGCredentialsPrompt *creds = self.credentialsPrompt;
        if (_dialogResult == 1) {
            NSURLCredential *credential = [NSURLCredential credentialWithUser:creds.usernameField.text
                                                                     password:creds.passwordField.text
                                                                  persistence:creds.persistence];
            [[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential:credential
                                                                forProtectionSpace:creds.challenge.protectionSpace];
            [creds.challenge.sender useCredential:credential
                       forAuthenticationChallenge:creds.challenge];
        } else {
            DLog(@"Cancel authenctication");
            [creds.challenge.sender
             cancelAuthenticationChallenge:creds.challenge];
        }
        self.credentialsPrompt = nil;
    } else {
        DLog(@"Called while showing other credential");
    }
}

- (BOOL)URLProtocol:(SGHTTPURLProtocol *)protocol canIgnoreUntrustedHost:(SecTrustRef)trust {
    
    NSString *host = protocol.request.URL.host;
    if (!_allowedHosts)
        _allowedHosts = [NSMutableArray arrayWithCapacity:10];
    else if ([_allowedHosts containsObject:host])
        return YES;
    
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

    [_allowedHosts addObject:host];// Remove it later if user taps cancel
    
    return NO;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    _dialogResult = buttonIndex;
    
    if (alertView != self.credentialsPrompt) {
        if (buttonIndex == 1) [self reload];
        else [_allowedHosts removeLastObject];
    }
}

@end
