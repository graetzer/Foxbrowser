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

@interface SGWebViewController ()
@property (strong, nonatomic) NSDictionary *selected;
@end

@implementation SGWebViewController

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
    self.webView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] 
                                        initWithTarget:self action:@selector(handleLongPress:)];
    [self.webView addGestureRecognizer:gr];
    gr.delegate = self;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
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
    
    NSString *link = (self.selected)[@"A"];
    NSString *imageSrc = (self.selected)[@"IMG"];
    
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
        self.location = request.URL;
        [self.browserViewController updateChrome];
        return [[WeaveOperations sharedOperations] handleURLInternal:request.URL];
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    self.loading = YES;
    [self.browserViewController updateChrome];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.loading = NO;
    [webView loadJSTools];
    [webView disableContextMenu];
    [webView modifyLinkTargets];
    [webView modifyOpen];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"org.graetzer.track"])
        [webView enableDoNotTrack];
        
    self.title = [webView title];
    
    NSString *webLoc = [self.webView location];
    if (webLoc.length && ![webLoc hasPrefix:@"file:///"])
        self.location = [NSURL URLWithUnicodeString:webLoc];
    [self.browserViewController updateChrome];
    
    // Private mode
    //if (![[NSUserDefaults standardUserDefaults] boolForKey:kWeavePrivateMode]) {
        [[WeaveOperations sharedOperations] addHistoryURL:self.location title:self.title];
    //}
    
    // Do the screenshot if needed
    [[SGFavouritesManager sharedManager] webViewDidFinishLoad:self];
}

//there are too many spurious warnings, so I'm going to just ignore or log them all for now.
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    self.loading = NO;
    [self.browserViewController updateChrome];
    
    DLog(@"WebView error code: %d", error.code);
    //ignore these
    if (error.code == NSURLErrorCancelled || [error.domain isEqualToString:@"WebKitErrorDomain"]) return;
    
    if ([error.domain isEqualToString:@"NSURLErrorDomain"]) {
        DLog(@"Webview error code: %i", error.code);
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
    NSString *html = @"<html><head><title>%@</title>"
    "<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=no' /></head><body>"
    "<div style='margin:100px auto;width:18em'>"
    "<p style='color:#c0bfbf;font:bolder 100px HelveticaNeue;text-align:center;margin:25px'>Fx</p>"
    "<p style='color:#969595;font:bolder 17.5px HelveticaNeue;text-align:center'>%@</p> </div></body></html>";//
    NSString *errorPage = [NSString stringWithFormat:html,
                           NSLocalizedString(@"Error Loading Page", @"error loading page"),[error localizedDescription]];
    [self.webView loadHTMLString:errorPage baseURL:[[NSBundle mainBundle] bundleURL]];
}

#pragma mark - Networking
 
- (void)openURL:(NSURL *)url {
    if (url) {
        self.location = url;
    }
    if (![self isViewLoaded]) {
        return;
    }
   
    if (![appDelegate canConnectToInternet]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Load Page", @"unable to load page")
                                                        message:NSLocalizedString(@"No internet connection available", nil)
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.location];
        [[WeaveOperations sharedOperations] modifyRequest:request];
        [self.webView loadRequest:request];
    }
}

- (void)reload {
    [self openURL:nil];
}

@end
