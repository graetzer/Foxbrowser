//
//  SGViewController.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//


#import "SGWebViewController.h"

#import "UIWebView+WebViewAdditions.h"

#import "SGTabsViewController.h"
#import "SGAppDelegate.h"
#import "SGFavouritesManager.h"

#import "FXSyncStock.h"
#import "NSStringPunycodeAdditions.h"
#import "GAI.h"

#import "FillrSDK/Fillr.h"

@implementation SGWebViewController {
    NSDictionary *_selected;
    NJKWebViewProgress *_progressProxy;
    BOOL _restoring;
}

// TODO Allow to change this preferences in the Settings App
+ (void)load {
    // Enable cookies
    @autoreleasepool {
        NSDictionary *useragents = @{@7 : @{@"iPhone" :
                                                @"Mozilla/5.0 (iPhone; CPU iPhone OS 7_0 like Mac OS X) "
                                            "AppleWebKit/546.10 (KHTML, like Gecko) Version/6.0 Mobile/7E18WD Safari/8536.25",
                                            @"iPad":@"Mozilla/5.0 (iPad; CPU OS 7_0 like Mac OS X) AppleWebKit/537.51.1 "
                                            "(KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53"},
                                     @8 : @{@"iPhone" :
                                                @"Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) "
                                            "AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4",
                                            @"iPad":@"Mozilla/5.0 (iPad; CPU iPad OS 8_0 like Mac OS X) "
                                            "AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4"}};
        NSNumber *version = @7;
        NSInteger val = [[[UIDevice currentDevice] systemVersion] integerValue];
        if (val > 7) {
            version = @8;
        }
        NSString *device = @"iPhone";
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            device = @"iPad";
        }
        NSDictionary *dictionary = @{@"UserAgent":useragents[version][device]};
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
        
        
        // TODO private mode
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage
                                              sharedHTTPCookieStorage];
        [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        
        
        // Setting Audio so it plays while silent mode is on
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        BOOL ok;
        NSError *setCategoryError = nil;
        ok = [audioSession setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
        if (!ok) {
            ELog(setCategoryError);
        }
    }
}

- (void)dealloc {
    self.webView.delegate = nil;
}

#pragma mark - State Preservation and Restoration

+ (UIViewController *) viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder {
    SGWebViewController *vc = [SGWebViewController new];
    vc.restorationIdentifier = [identifierComponents lastObject];
    vc.restorationClass = [SGWebViewController class];
    return vc;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:_request forKey:@"request"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    _request = [coder decodeObjectForKey:@"request"];
    if (self.title == nil && _request != nil) {
        self.title = _request.URL.host;
    }
    
    // Workaround because after state restoration we need to reload,
    // Otherwise you get a blank page
    _restoring = YES;
}

#pragma mark - View initialization

- (void)loadView {
    __strong UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    self.view = webView;
    self.webView = webView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.restorationIdentifier = NSStringFromClass([self class]);
    self.restorationClass = [self class];
    self.view.restorationIdentifier = @"webView";
    
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webView.backgroundColor = [UIColor whiteColor];
    //UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? [UIColor colorWithWhite:1 alpha:0.2] : [UIColor clearColor];
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(_handleLongPressGesture:)];
    gr.delegate = self;
    [_webView addGestureRecognizer:gr];
    _webView.scalesPageToFit = YES;
    
    _progressProxy = [[NJKWebViewProgress alloc] init];
    _progressProxy.webViewProxyDelegate = self;
    _progressProxy.progressDelegate = self;
    _webView.delegate = _progressProxy;
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    [super willMoveToParentViewController:parent];
    if (parent == nil) {// View is removed
        _webView.delegate = nil;
        [_webView stopLoading];
        [_webView clearContent];
        _loading = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // We can't just load the request, this would add to the history
    if (_restoring) {// We have to reload, this is a bug wth apple
        [_webView reload];
        _restoring = NO;
    } else {
        // self.title == nil is a workaround, to get the uiwebview to load the page
        if (_webView.request == nil || self.title == nil) {
            [self openRequest:nil];
        }
    }
    
    //[[Fillr sharedInstance] trackWebview:_webView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_searchToolbar) {
        CGFloat y = self.view.frame.origin.y;
        _searchToolbar.frame = CGRectMake(0, self.view.bounds.size.height - 44 - y,
                                          self.view.bounds.size.width, 44);
    }
}

#pragma mark - UILongPressGesture

- (IBAction)_handleLongPressGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint at = [sender locationInView:self.webView];
        at.y -= self.webView.scrollView.contentInset.top;
        // convert point from view to HTML coordinate system
        //CGPoint offset  = [self.webView scrollOffset];
        CGSize viewSize = [self.webView frame].size;
        CGSize windowSize = [self.webView windowSize];
        
        CGFloat f = windowSize.width / viewSize.width;
        CGPoint pt = CGPointMake(at.x*f, at.y*f);
        [self _showContextMenuFor:pt atPoint:at];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
  navigationType:(UIWebViewNavigationType)navigationType {
    
    NSString *scheme = request.URL.scheme;
    SGBrowserViewController *browser = (SGBrowserViewController *)self.parentViewController;
    if ([scheme isEqualToString:@"newtab"]) {
        NSString *urlString = [request.URL.resourceSpecifier stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSMutableURLRequest *mutableReq = [request mutableCopy];
        mutableReq.URL = [NSURL URLWithString:[urlString encodedURLString] relativeToURL:self.request.URL];
        [browser addTabWithURLRequest:mutableReq title:nil];
        return NO;
    } else if ([scheme isEqualToString:@"closetab"]) {
        [browser removeViewController:self];
        return NO;
    }
    
    if (navigationType != UIWebViewNavigationTypeOther) {
        if (IsNativeAppURLWithoutChoice(request.URL)) {
            [[UIApplication sharedApplication] openURL:request.URL];
            return NO;
        } else if (![request.mainDocumentURL isEqual:_request.mainDocumentURL]) {
            // Change of webpage
            _request = request;
        }
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    _loading = YES;
    [self _dismissSearchToolbar];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _loading = NO;
    
    [webView loadJSTools];
    [webView disableTouchCallout];
    self.title = [webView title];
    
    if (![self.webView.request.URL.scheme isEqualToString:@"file"]) {
        _request = webView.request;
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // If an error oocured, disable the loading stuff
    _loading = NO;
    
    DLog(@"WebView error code: %ld", (long)error.code);
    //ignore these
    if ([error.domain isEqual:NSURLErrorDomain]
        && error.code == NSURLErrorCancelled) return;
    
    if (error.code == NSURLErrorCannotFindHost
        || error.code == NSURLErrorDNSLookupFailed
        || ([(id)kCFErrorDomainCFNetwork isEqualToString:error.domain] && error.code == 2)) {
        
        // Host not found, try adding www. in front?
        if ([self.request.URL.host rangeOfString:@"www"].location == NSNotFound) {
            NSMutableString *urlS = [self.request.URL.absoluteString mutableCopy];
            NSRange range = [urlS rangeOfString:@"://"];
            if (range.location != NSNotFound) {
                [urlS insertString:@"www." atIndex:range.location+range.length];
                NSMutableURLRequest *next = [self.request mutableCopy];
                next.URL = [NSURL URLWithString:urlS];
                [self openRequest:next];
                return;
            }
        }
    }
    
    // Ignore "Fame Load Interrupted" errors. Seen after app store links.
    if ([error.domain isEqual:@"WebKitErrorDomain"]) {
        // if (error.code == 102) return;
        NSURL *url = [NSURL URLWithString:error.userInfo[@"NSErrorFailingURLStringKey"]];
        if (error.code == 101 && [[UIApplication sharedApplication]canOpenURL:url]) {
            [[UIApplication sharedApplication]openURL:url];
        }
        return;
    }
    
    NSString *title = NSLocalizedString(@"Error Loading Page", @"error loading page");
    [self.webView showPlaceholder:error.localizedDescription title:title];
}

/* This should be called everytime, so we do not need to call updateInterface in the other methods */
- (void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress; {
    _progress = progress;
    _canGoBack = [_webView canGoBack];
    _canGoForward = [_webView canGoForward];
    
    SGBrowserViewController *browser = (SGBrowserViewController *)self.parentViewController;
    [browser updateInterface];
    
    if (progress >= 1 && ![self.webView.request.URL.scheme isEqualToString:@"file"]) {
        [[FXSyncStock sharedInstance] addHistoryURL:_request.URL];
        [[SGFavouritesManager sharedManager] webViewDidFinishLoad:self];
    }
}

#pragma mark - Networking

/*! Build a request that contains the referrer etc */
- (NSURLRequest *)_nextRequestForURL:(NSURL *)url {
    if (url == nil) return nil;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:self.request.URL.absoluteString forHTTPHeaderField:@"Referer"];
    return request;
}

- (void)openRequest:(NSURLRequest *)request {
    if (request != nil) _request = request;
    if (![self isViewLoaded] || _request == nil) return;
    
    // In case the webView is not empty, show the error on the site
    if (![appDelegate canConnectToInternet]) {
        [_webView showPlaceholder:NSLocalizedString(@"No internet connection available", nil)
                                title:NSLocalizedString(@"Cannot Load Page", @"unable to load page")];
    } else {
        // Show some info if asked for it
        if ([self.request.URL.absoluteString isEqualToString:@"about:config"]) {
            NSString *version = [NSBundle mainBundle].infoDictionary[(NSString*)kCFBundleVersionKey];
            NSString *text = [NSString stringWithFormat:@"Version %@<br/>Developer simon@graetzer.org<br/>Thanks for using Foxbrowser!", version];
            [_webView showPlaceholder:text title:@"Foxbrowser Configuration"];
        } else {
            _loading = YES;
            [_webView loadRequest:self.request];
        }
    }
    SGBrowserViewController *browser = (SGBrowserViewController *)self.parentViewController;
    [browser updateInterface];
}

#pragma mark - Contextual menu

- (void)_showContextMenuFor:(CGPoint)pt atPoint:(CGPoint) at {
    if (![self.webView JSToolsLoaded]) {
        [self.webView loadJSTools];
    }
    
    UIActionSheet *sheet;
    _selected = [self.webView tagsForPosition:pt];
    
    NSString *link = _selected[@"A"];
    NSString *imageSrc = _selected[@"IMG"];
    
    NSString *prefix = @"newtab:";
    if ([link hasPrefix:prefix]) {
        link = [link substringFromIndex:prefix.length];
        link = [link stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    if (link && imageSrc) {
        sheet = [[UIActionSheet alloc] initWithTitle:link
                                            delegate:self
                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                              destructiveButtonTitle:nil
                                   otherButtonTitles:
                 NSLocalizedString(@"Open", @"Open a link"),
                 NSLocalizedString(@"Open in a new Tab", nil),
                 NSLocalizedString(@"Save Picture", nil),
                 NSLocalizedString(@"Copy URL", nil), nil];
    } else if (link) {
        sheet = [[UIActionSheet alloc] initWithTitle:link
                                            delegate:self
                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                              destructiveButtonTitle:nil
                                   otherButtonTitles:
                 NSLocalizedString(@"Open", @"Open a link"),
                 NSLocalizedString(@"Open in a new Tab", nil),
                 NSLocalizedString(@"Copy URL", nil), nil];
    } else if (imageSrc) {
        sheet = [[UIActionSheet alloc] initWithTitle:imageSrc
                                            delegate:self
                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                              destructiveButtonTitle:nil
                                   otherButtonTitles:
                 NSLocalizedString(@"Save Picture", nil),
                 NSLocalizedString(@"Copy URL", nil), nil];
        
    }
    
    if (sheet != nil) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            [sheet showFromRect:CGRectMake(at.x, at.y, 2.5, 2.5) inView:self.webView animated:YES];
        else
            [sheet showInView:self.parentViewController.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *link = _selected[@"A"];
    NSString *imageSrc = _selected[@"IMG"];
    
    NSString *prefix = @"javascript:";
    if ([link hasPrefix:prefix]) return;
    
    NSURLRequest *nextRequest = [self _nextRequestForURL:[NSURL URLWithUnicodeString:link]];
    SGBrowserViewController *browser = (SGBrowserViewController *)self.parentViewController;
    
    if (link && imageSrc) {
        if (buttonIndex == 0) {
            [self openRequest:nextRequest];
        }
        else if (buttonIndex == 1) {
            [browser addTabWithURLRequest:nextRequest title:nil];
        }
        else if (buttonIndex == 2) {
            [self performSelectorInBackground:@selector(saveImageURL:)
                                   withObject:[NSURL URLWithUnicodeString:imageSrc]];
        } else if (buttonIndex == 3) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (link) {
        if (buttonIndex == 0) {
            [self openRequest:nextRequest];
        }
        else if (buttonIndex == 1) {
            [browser addTabWithURLRequest:nextRequest title:nil];
        }
        else if (buttonIndex == 2) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (imageSrc) {
        if (buttonIndex == 0) {
            [self performSelectorInBackground:@selector(saveImageURL:)
                                   withObject:[NSURL URLWithUnicodeString:imageSrc]];
        } else if (buttonIndex == 1) {
            [UIPasteboard generalPasteboard].string = imageSrc;
        }
    }
}

- (void)saveImageURL:(NSURL *)url {
    @autoreleasepool {
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            UIImageWriteToSavedPhotosAlbum(img, self,
                                           @selector(_image:didFinishSavingWithError:contextInfo:), nil);
        }
    }
}

- (void)              _image: (UIImage *) image
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo {
    if (error) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Submit", nil)
                                    message:NSLocalizedString(@"Error Retrieving Data", nil)
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                          otherButtonTitles:nil] show];
    }
}

#pragma mark - Search on page

- (NSInteger)search:(NSString *)searchString {
    if (_searchToolbar) [_searchToolbar removeFromSuperview];
    
    NSInteger count = [self.webView highlightOccurencesOfString:searchString];
    DLog(@"Found the string %@ %ld times", searchString, (long)count);
    
    __strong UIToolbar *searchToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 44,
                                                                                    self.view.bounds.size.width, 44)];
    searchToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    searchToolbar.translucent = YES;
    
    UIImage *arrow = [UIImage imageNamed:@"left"];
    UIImage *up = [UIImage imageWithCGImage:arrow.CGImage scale:arrow.scale orientation:UIImageOrientationRight];
    UIImage *down = [UIImage imageWithCGImage:arrow.CGImage scale:arrow.scale orientation:UIImageOrientationRightMirrored];
    
    CGRect btnRect = CGRectMake(0, 0, 35, 40);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = btnRect;
    button.backgroundColor = [UIColor clearColor];
    button.showsTouchWhenHighlighted = YES;
    [button setImage:up forState:UIControlStateNormal];
    [button addTarget:self action:@selector(_lastHighlightedWord:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *last = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = btnRect;
    button.backgroundColor = [UIColor clearColor];
    button.showsTouchWhenHighlighted = YES;
    [button setImage:down forState:UIControlStateNormal];
    [button addTarget:self action:@selector(_nextHighlightedWord:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                          target:self
                                                                          action:@selector(_dismissSearchToolbar)];
    
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                           target:nil action:nil];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:18];
    label.textColor = [UIColor darkGrayColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [NSString stringWithFormat:@"Found: %li", (long)count];
    UIBarButtonItem *textItem = [[UIBarButtonItem alloc] initWithCustomView:label];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone
        && NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_1) {
        searchToolbar.tintColor = kSGBrowserBarColor;
        done.tintColor = [UIColor lightGrayColor];
    }
    
    searchToolbar.items = @[last, next, space, textItem, space, done];
    [self.view addSubview:searchToolbar];
    _searchToolbar = searchToolbar;
    
    return count;
}

- (IBAction)_lastHighlightedWord:(id)sender {
    [self.webView showLastHighlight];
}

- (IBAction)_nextHighlightedWord:(id)sender {
    [self.webView showNextHighlight];
}

- (IBAction)_dismissSearchToolbar {
    if (_searchToolbar) {
        [self.webView removeHighlights];
        [UIView animateWithDuration:0.3
                         animations:^{
                             _searchToolbar.alpha = 0;
                         }
                         completion:^(BOOL finished){
                             [_searchToolbar removeFromSuperview];
                             _searchToolbar = nil;
                         }];
    }
}

@end



