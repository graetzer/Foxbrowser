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

@interface SGWebViewController ()
@property (strong, nonatomic) NSDictionary *selected;
@end

@implementation SGWebViewController {
    NSTimer *_updateTimer;
}

// TODO Allow to change this preferences in the Settings App
+ (void)initialize {
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
    }
}

- (void)loadView {
    __strong UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    self.view = webView;
    self.webView = webView;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
        
    self.webView.frame = self.view.bounds;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] 
                                        initWithTarget:self action:@selector(handleLongPress:)];
    [self.webView addGestureRecognizer:gr];
    gr.delegate = self;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    [super didMoveToParentViewController:parent];
    if (!parent) {// View is removed
        [self.webView stopLoading];
        [self.webView clearContent];
        [self.webView removeGestureRecognizer:[self.webView.gestureRecognizers lastObject]];
    }
}

- (void)viewWillUnload {
    [super viewWillUnload];
    
    [self.webView removeGestureRecognizer:[self.webView.gestureRecognizers lastObject]];
    [self.webView stopLoading];
    self.webView.delegate = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    if (!self.webView.request) {
        [self openURL:nil];
    }
}

- (void)dealloc {
    self.webView.delegate = nil;
}

#pragma mark - UILongPressGesture
- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint at = [sender locationInView:self.webView];
        CGPoint pt = at;
        
        // convert point from view to HTML coordinate system
        //CGPoint offset  = [self.webView scrollOffset];
        CGSize viewSize = [self.webView frame].size;
        CGSize windowSize = [self.webView windowSize];
        
        CGFloat f = windowSize.width / viewSize.width;
        pt.x = pt.x * f ;//+ offset.x;
        pt.y = pt.y * f ;//+ offset.y;
        
        [self contextMenuFor:pt showAt:at];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - Contextual menu

- (void)contextMenuFor:(CGPoint)pt showAt:(CGPoint) at{    
    UIActionSheet *sheet;
    self.selected = [self.webView tagsForPosition:pt];
    
    NSString *link = self.selected[@"A"];
    NSString *imageSrc = self.selected[@"IMG"];
    
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
    
    if (sheet) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            [sheet showFromRect:CGRectMake(at.x, at.y, 2.5, 2.5) inView:self.webView animated:YES];
        else
            [sheet showInView:self.parentViewController.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *link = (self.selected)[@"A"];
    NSString *imageSrc = (self.selected)[@"IMG"];
    
    NSString *prefix = @"javascript:";
    if ([link hasPrefix:prefix])
        return;
    
    prefix = @"newtab:";
    if ([link hasPrefix:prefix]) {
        link = [link substringFromIndex:prefix.length];
        link = [link stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    if (link && imageSrc) {
        if (buttonIndex == 0) {
            NSURL *url = [NSURL URLWithString:link];
            [self openURL:url];
        } else if (buttonIndex == 1) {
            [self.browserViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
        } else if (buttonIndex == 2) {
            [self performSelectorInBackground:@selector(saveImageURL:) withObject:[NSURL URLWithString:imageSrc]];
        } else if (buttonIndex == 3) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (link) {
        if (buttonIndex == 0) {
            NSURL *url = [NSURL URLWithString:link];
            [self openURL:url];
        } else if (buttonIndex == 1) {
            [self.browserViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
        } else if (buttonIndex == 2) {
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
                                           @selector(image:didFinishSavingWithError:contextInfo:), nil);
        }
    }
}

- (void)               image: (UIImage *) image
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

-  (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL.scheme isEqualToString:@"newtab"]) {
        NSString *source = [request.URL resourceSpecifier];
        NSString *urlString = [source stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *url = [NSURL URLWithString:urlString relativeToURL:self.location];
        [self.browserViewController addTabWithURL:url withTitle:url.absoluteString];
        return NO;
    }
    
    if (navigationType != UIWebViewNavigationTypeOther) {
        self.location = request.mainDocumentURL;
        [self.browserViewController updateChrome];
        return [[WeaveOperations sharedOperations] handleURLInternal:request.URL];
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self dismissSearchToolbar];
    self.loading = YES;
    [self.browserViewController updateChrome];
    _updateTimer = [NSTimer scheduledTimerWithTimeInterval:2.5
                                                    target:self
                                                  selector:@selector(prepareWebView)
                                                  userInfo:nil repeats:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [_updateTimer invalidate];
    _updateTimer = nil;
    [self prepareWebView];
    
    self.title = [webView title];
    self.loading = NO;
    NSString *webLoc = [self.webView location];
    if (webLoc.length && ![webLoc hasPrefix:@"file:///"])
        self.location = [NSURL URLWithUnicodeString:webLoc];
    
    [self.browserViewController updateChrome];
    // Private mode
    //if (![[NSUserDefaults standardUserDefaults] boolForKey:kWeavePrivateMode]) {
        [[WeaveOperations sharedOperations] addHistoryURL:self.location title:self.title];
    //}
    
    [[SGFavouritesManager sharedManager] webViewDidFinishLoad:self];
}

//there are too many spurious warnings, so I'm going to just ignore or log them all for now.
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    self.loading = NO;
    [self.browserViewController updateChrome];
    
    DLog(@"WebView error code: %d", error.code);
    //ignore these
    if (error.code == NSURLErrorCancelled || [error.domain isEqualToString:@"WebKitErrorDomain"]) return;
    
    if ([error.domain isEqualToString:@"NSURLErrorDomain"]) {
        // Host not found, try adding www. in front?
        if (error.code == -1003 && [self.location.host rangeOfString:@"www"].location == NSNotFound) {
            NSMutableString *url = [self.location.absoluteString mutableCopy];
            NSRange range = [url rangeOfString:@"://"];
            if (range.location != NSNotFound) {
                [url insertString:@"www." atIndex:range.location+range.length];
                [self openURL:[NSURL URLWithString:url]];
                return;
            }
        }
    }
    
    NSString *title = NSLocalizedString(@"Error Loading Page", @"error loading page");
    if ([self.webView isEmpty]) {
        [self.webView showPlaceholder:error.localizedDescription title:title];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:error.localizedDescription
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"ok")
                                              otherButtonTitles: nil];
        [alert show];
    }
}

- (void)prepareWebView {
    [self.browserViewController updateChrome];
    if (![self.webView JSToolsLoaded]) {
        [self.webView loadJSTools];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.track"])
            [self.webView enableDoNotTrack];
    }
}

#pragma mark - Networking
 
- (void)openURL:(NSURL *)url {
    if (url)
        self.location = url;
    
    if (![self isViewLoaded])
        return;
    
    // In case the webView is empty, show the error on the site
    if (![appDelegate canConnectToInternet] && ![self.webView isEmpty]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Load Page", @"unable to load page")
                                                        message:NSLocalizedString(@"No internet connection available", nil)
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.location];
        [self.webView loadRequest:request];
    }
}

- (void)reload {
    [self openURL:nil];
}

#pragma mark - Search on page
- (NSInteger)search:(NSString *)searchString {
    if (self.searchToolbar)
        [self.searchToolbar removeFromSuperview];
    
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
    [button addTarget:self action:@selector(lastHighlightedWord:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *last = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = btnRect;
    button.backgroundColor = [UIColor clearColor];
    button.showsTouchWhenHighlighted = YES;
    [button setImage:down forState:UIControlStateNormal];
    [button addTarget:self action:@selector(nextHighlightedWord:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                          target:self
                                                                          action:@selector(dismissSearchToolbar)];
    
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
        searchToolbar.tintColor = kTabColor;
        done.tintColor = [UIColor lightGrayColor];
    }
    
    searchToolbar.items = @[last, next, space, textItem, space, done];
    [self.view addSubview:searchToolbar];
    self.searchToolbar = searchToolbar;
    
    return count;
}

- (IBAction)lastHighlightedWord:(id)sender {
    [self.webView showLastHighlight];
}

- (IBAction)nextHighlightedWord:(id)sender {
    [self.webView showNextHighlight];
}

- (IBAction)dismissSearchToolbar {
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
