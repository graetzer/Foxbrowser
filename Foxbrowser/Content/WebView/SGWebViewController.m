//
//  SGViewController.m
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
//  


#import "SGWebViewController.h"
#import "UIViewController+TabsController.h"
#import "UIWebView+WebViewAdditions.h"
#import "SGTabsViewController.h"
#import "SGAppDelegate.h"
#import "Reachability.h"
#import "WeaveService.h"
#import "NSURL+IFUnicodeURL.h"
#import "SGURLProtocol.h"


#define HTTP_AGENT @"Mozilla/5.0 (iPad; U; CPU OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B334b Safari/531.21.10"

@interface SGWebViewController ()
@property (strong, nonatomic) NSDictionary *selected;
@end

@implementation SGWebViewController

// TODO Allow to change this preferences in the Settings App
+ (void)load {
    // Enable cookies
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

- (void)loadView {
    self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    self.view = self.webView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationIsLandscape(interfaceOrientation);
    } else {
        return YES;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [SGURLProtocol registerProtocol];
    
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

- (void)willMoveToParentViewController:(UIViewController *)parent {
    if (!parent) {// View is removed
        [self.webView stopLoading];
        self.webView.delegate = nil;
        [self.webView removeGestureRecognizer:[self.webView.gestureRecognizers lastObject]];
    }
}

- (void)viewWillUnload {
    [SGURLProtocol unregisterProtocol];
    
    [self.webView stopLoading];
    self.webView.delegate = nil;
    [self.webView removeGestureRecognizer:[self.webView.gestureRecognizers lastObject]];
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    if (!self.webView.request) {
        [self openURL:nil];
    }
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
    
    NSString *link = [self.selected objectForKey:@"A"];
    NSString *imageSrc = [self.selected objectForKey:@"IMG"];
    
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
    
    if (sheet)
        [sheet showFromRect:CGRectMake(at.x, at.y, 2.5, 2.5) inView:self.webView animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *link = [self.selected objectForKey:@"A"];
    NSString *imageSrc = [self.selected objectForKey:@"IMG"];
    
    if (link && imageSrc) {
        if (buttonIndex == 0) {
            NSURL *url = [NSURL URLWithString:link];
            [self openURL:url];
        } else if (buttonIndex == 1) {
            [self.tabsViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
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
            [self.tabsViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
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
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data) {
        UIImage *img = [UIImage imageWithData:data];
        UIImageWriteToSavedPhotosAlbum(img, self, 
                                       @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
}

- (void)               image: (UIImage *) image
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo {
    if (error) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                   message:NSLocalizedString(@"Error Retrieving Data", nil)
                                  delegate:nil
                         cancelButtonTitle:NSLocalizedString(@"OK", nil)
                          otherButtonTitles:nil] show];
    }
}

#pragma mark - UIWebViewDelegate

-  (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL.scheme isEqualToString:@"newtab"]) {
        NSString *urlString = [[request.URL resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *url = [NSURL URLWithString:urlString relativeToURL:self.location];
        [self.tabsViewController addTabWithURL:url withTitle:url.absoluteString];
        return NO;
    }
    
    if (navigationType != UIWebViewNavigationTypeOther) {
        self.location = request.URL;
        if ([request respondsToSelector:@selector(setValue:forHTTPHeaderField:)]) {
            [(id)request setValue:HTTP_AGENT forHTTPHeaderField:@"User-Agent"];
        }
        [self.tabsViewController updateChrome];
        return [WeaveOperations handleURLInternal:request.URL];
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self.tabsViewController updateChrome];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [webView loadJSTools];
    [webView disableContextMenu];
    [webView modifyLinkTargets];
    [webView modifyOpen];
    self.title = [webView title];
    
    NSString *webLoc = [self.webView location];
    if (webLoc.length) {
        self.location = [NSURL URLWithUnicodeString:webLoc];
    }
    
    [self.tabsViewController updateChrome];
    
    [WeaveOperations addHistoryURL:self.location title:self.title];
    
    // Do the screenshot if needed
    NSString *path = [UIWebView pathForURL:self.location];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:NULL];
        NSDate *modDate = [attr objectForKey:NSFileModificationDate];
        NSNumber *size = [attr objectForKey:NSFileSize];
        if ([modDate compare:[NSDate dateWithTimeIntervalSinceNow:-60*60*24*3]] == NSOrderedAscending || [size longLongValue] == 0) {
            [self.webView performSelector:@selector(saveScreenTo:) withObject:path afterDelay:1.5];
        }
    }
}

//there are too many spurious warnings, so I'm going to just ignore or log them all for now.
- (void)webView:(UIWebView *)theWebView didFailLoadWithError:(NSError *)error
{
    NSLog(@"Error code: %d", error.code);
    //ignore these
    if (error.code == NSURLErrorCancelled || [error.domain isEqualToString:@"WebKitErrorDomain"]) return;
    
    [self.tabsViewController updateChrome];
    
    if ([error.domain isEqualToString:@"NSURLErrorDomain"])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading Page", @"error loading page")
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
        [alert show];
        return;
    }
}

#pragma mark NSURLConnectionDelegate
 
- (void)openURL:(NSURL *)url {
    if (url) {
        self.location = url;
    }
    if (![self isViewLoaded]) {
        return;
    }
   
    if (![appDelegate canConnectToInternet]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                        message:NSLocalizedString(@"No connection aviable", nil)
                                                       delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
        [alert show];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.location
                                           cachePolicy:NSURLRequestReloadRevalidatingCacheData
                                       timeoutInterval:10.];
        [request setValue:HTTP_AGENT forHTTPHeaderField:@"User-Agent"];
        [self.webView loadRequest:request];
    }
}

@end
