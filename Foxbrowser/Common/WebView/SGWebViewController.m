//
//  SGViewController.m
//  SGTabs
//
//  Created by simon on 07.06.12.
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


#import "SGWebViewController.h"
#import "UIViewController+SGBrowserViewController.h"
#import "UIWebView+WebViewAdditions.h"
#import "SGTabsViewController.h"
#import "SGAppDelegate.h"
#import "WeaveService.h"
#import "NSURL+IFUnicodeURL.h"
#import "SGFavouritesManager.h"
#import "SGTabDefines.h"

#import "GAI.h"

@implementation SGWebViewController {
    //NSTimer *_updateTimer;
    NSDictionary *_selected;
    
    BOOL _animating;
}

// TODO Allow to change this preferences in the Settings App
+ (void)load {
    // Enable cookies
    @autoreleasepool { // TODO private mode
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage
                                              sharedHTTPCookieStorage];
        [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        
        NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
        path = [path stringByAppendingPathComponent:@"WebCache"];
        NSURLCache *cache = [[NSURLCache alloc] initWithMemoryCapacity:1024*1024*5
                                                          diskCapacity:1024*1024*30
                                                              diskPath:path];
        [NSURLCache setSharedURLCache:cache];
        
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
    
    self.webView.frame = self.view.bounds;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor whiteColor];
    //UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? [UIColor colorWithWhite:1 alpha:0.2] : [UIColor clearColor];
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(_handleLongPressGesture:)];
    gr.delegate = self;
    [self.webView addGestureRecognizer:gr];
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    self.webView.allowsInlineMediaPlayback = YES;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        __strong UIActivityIndicatorView *ind = [[UIActivityIndicatorView alloc]
                                                 initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        ind.transform = CGAffineTransformMakeScale(2, 2);
        self.indicator = ind;
        ind.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.view addSubview:ind];
    }
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    [super willMoveToParentViewController:parent];
    if (!parent) {// View is removed
        for (UIGestureRecognizer *rec in self.webView.gestureRecognizers) {
            [rec removeTarget:self action:nil];
        }
        
        self.webView.delegate = nil;
        [self.webView stopLoading];
        [self.webView clearContent];
        
        _loading = NO;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.webView.request) {
        [self openRequest:nil];
    }
}


- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (!_animating) [self _layout];
}

- (void)_layout {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIActivityIndicatorView *ind = self.indicator;
        ind.center = CGPointMake(self.view.bounds.size.width - ind.frame.size.width/2 - 10, ind.frame.size.height/2 + 10);
    }
}



#pragma mark - UILongPressGesture

- (IBAction)_handleLongPressGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint at = [sender locationInView:self.webView];
        //CGPoint pt = at;
        
        // convert point from view to HTML coordinate system
        //CGPoint offset  = [self.webView scrollOffset];
        CGSize viewSize = [self.webView frame].size;
        CGSize windowSize = [self.webView windowSize];
        
        CGFloat f = windowSize.width / viewSize.width;
        CGPoint pt = CGPointMake(at.x*f, at.y*f);
//        pt.x = pt.x * f ;//+ offset.x;
//        pt.y = pt.y * f ;//+ offset.y;
        
        [self _showContextMenuFor:pt atPoint:at];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
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
    
    NSURLRequest *nextRequest = [self _nextRequestForURL:[NSURL URLWithString:link]];
    
    if (link && imageSrc) {
        if (buttonIndex == 0) {
            [self openRequest:nextRequest];
        }
        else if (buttonIndex == 1) {
            [self.browserViewController addTabWithURLRequest:nextRequest title:nil];
        }
        else if (buttonIndex == 2) {
            [self performSelectorInBackground:@selector(saveImageURL:) withObject:[NSURL URLWithString:imageSrc]];
        } else if (buttonIndex == 3) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (link) {
        if (buttonIndex == 0) {
            [self openRequest:nextRequest];
        }
        else if (buttonIndex == 1) {
            [self.browserViewController addTabWithURLRequest:nextRequest title:nil];
        }
        else if (buttonIndex == 2) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (imageSrc) {
        if (buttonIndex == 0) {
            [self performSelectorInBackground:@selector(saveImageURL:) withObject:[NSURL URLWithString:imageSrc]];
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

#pragma mark - UIWebViewDelegate

-  (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
  navigationType:(UIWebViewNavigationType)navigationType {
    
    if ([request.URL.scheme isEqualToString:@"newtab"]) {
        NSString *urlString = [request.URL.resourceSpecifier stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSMutableURLRequest *mutableReq = [request mutableCopy];
        mutableReq.URL = [NSURL URLWithString:urlString relativeToURL:self.request.URL];
        [self.browserViewController addTabWithURLRequest:mutableReq title:nil];
        return NO;
    }
    
    if (navigationType != UIWebViewNavigationTypeOther) {
        if (![[WeaveOperations sharedOperations] handleURLInternal:request.URL]) {
            return NO;
        } else if (![request.mainDocumentURL isEqual:self.request.mainDocumentURL]) {
            // Change of webpage
            self.request = request;
        }
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    _loading = YES;
    [self _dismissSearchToolbar];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
    [self.indicator startAnimating];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _loading = NO;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.indicator stopAnimating];
    }
    
    [self.webView loadJSTools];
    [self.webView disableTouchCallout];
    self.title = [webView title];
    
    if (![self.webView.request.URL.scheme isEqualToString:@"file"]) {
        self.request = self.webView.request;
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSGEnableDoNotTrackKey]) {
        [self.webView enableDoNotTrack];
    }
    
    [[WeaveOperations sharedOperations] addHistoryURL:self.request.URL title:self.title];
    [[SGFavouritesManager sharedManager] webViewDidFinishLoad:self];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // If an error oocured, disable the loading stuff
    _loading = NO;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.indicator stopAnimating];
    }
    
    DLog(@"WebView error code: %d", error.code);
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
    
    NSString *title = NSLocalizedString(@"Error Loading Page", @"error loading page");
    [self.webView showPlaceholder:error.localizedDescription title:title];
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
    if (request) self.request = request;
    if (![self isViewLoaded]) return;
    
    // In case the webView is not empty, show the error on the site
    if (![appDelegate canConnectToInternet]) {
        [self.webView showPlaceholder:NSLocalizedString(@"No internet connection available", nil)
                                title:NSLocalizedString(@"Cannot Load Page", @"unable to load page")];
    } else {
        // Show some info if asked for it
        if ([self.request.URL.absoluteString isEqualToString:@"about:config"]) {
            NSString *version = [NSBundle mainBundle].infoDictionary[(NSString*)kCFBundleVersionKey];
            NSString *text = [NSString stringWithFormat:@"Version %@<br/>Developer simon@graetzer.org<br/>Thanks for using Foxbrowser!", version];
            [self.webView showPlaceholder:text title:@"Foxbrowser Configuration"];
        } else {
            _loading = YES;
            [self.webView loadRequest:self.request];
        }
    }
}

#pragma mark - Search on page

- (NSInteger)search:(NSString *)searchString {
    if (self.searchToolbar) [self.searchToolbar removeFromSuperview];
    
    NSInteger count = [self.webView highlightOccurencesOfString:searchString];
    DLog(@"Found the string %@ %i times", searchString, count);
    
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
    label.text = [NSString stringWithFormat:@"Found: %i", count];
    UIBarButtonItem *textItem = [[UIBarButtonItem alloc] initWithCustomView:label];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        searchToolbar.tintColor = kSGBrowserBarColor;
        done.tintColor = [UIColor lightGrayColor];
    }
    
    searchToolbar.items = @[last, next, space, textItem, space, done];
    [self.view addSubview:searchToolbar];
    self.searchToolbar = searchToolbar;
    
    return count;
}

- (IBAction)_lastHighlightedWord:(id)sender {
    [self.webView showLastHighlight];
}

- (IBAction)_nextHighlightedWord:(id)sender {
    [self.webView showNextHighlight];
}

- (IBAction)_dismissSearchToolbar {
    if (self.searchToolbar) {
        [self.webView removeHighlights];
        [UIView animateWithDuration:0.3
                         animations:^{
                             self.searchToolbar.alpha = 0;
                         }
                         completion:^(BOOL finished){
                             [self.searchToolbar removeFromSuperview];
                             self.searchToolbar = nil;
                         }];
    }
}

@end

