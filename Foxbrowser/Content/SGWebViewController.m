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
#import "SGToolbar.h"
#import "SGAppDelegate.h"
#import "Reachability.h"
#import "WeaveService.h"

#import "ASIFormDataRequest.h"
#import "JSON.h"

@interface SGWebViewController ()
@property (strong, nonatomic) NSDictionary *selected;
@end

@implementation SGWebViewController

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
    if (!parent && self.webView) {// View is removed
        [self.webView stopLoading];
        self.webView.delegate = nil;
        [self.webView removeGestureRecognizer:[self.webView.gestureRecognizers lastObject]];
    }
}

- (void)viewWillUnload {
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
    if (!self.webView.request || ![self.webView.request.URL isEqual:self.URL]) {
        [self openURL:self.URL];
    }
}

- (void)start {
    [self openURL:self.URL];
}

- (void)openURL:(NSURL *)url {
    Reachability *r = [Reachability reachabilityForInternetConnection];
    if (![r isReachable]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                        message:NSLocalizedString(@"No connection aviable", nil)
                                                       delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
        [alert show];
    } else {
        _loading = YES;
        //[self.webView clearContent];
        NSURLRequest *request = [NSURLRequest requestWithURL:url 
                                                 cachePolicy:NSURLCacheStorageAllowed 
                                             timeoutInterval:10.];
        [self.webView loadRequest:request];
    }
}

#pragma mark - UIWebViewDelegate

-  (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType != UIWebViewNavigationTypeOther) {
        self.URL = request.URL;
        
        NSString *ext = [self.URL pathExtension];
        if ([[UIWebView fileTypes] containsObject:ext])
            self.title = [self.URL lastPathComponent];
        else
            self.title = self.URL.absoluteString;
        
        [self.tabsViewController updateChrome];
        
        return [WeaveOperations handleURLInternal:self.URL];
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    _loading = YES;
    [self.tabsViewController updateChrome];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    _loading = NO;
    
    [webView disableContextMenu];
    self.title = [webView title];
    self.URL = webView.request.URL;
    [self.tabsViewController updateChrome];
    
    // Do the screenshot if needed
    NSString *path = [UIWebView pathForURL:self.URL];
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
    //ignore these
    if (error.code == NSURLErrorCancelled || [error.domain isEqualToString:@"WebKitErrorDomain"]) return;
    
    _loading = NO;
    
    if ([error.domain isEqualToString:@"NSURLErrorDomain"])
    {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading Page", @"error loading page") message:[error localizedDescription]
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
        [alert show];
        return;
    }
}

# pragma mark - SGBarDelegate
- (void)reload {
    [self start];
}

- (void)stop {
    [self.webView stopLoading];
    _loading = NO;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self.tabsViewController updateChrome];
}

- (void)goBack {
    [self.webView goBack];
}

- (void)goForward {
    [self.webView goForward];
}

- (BOOL)canGoBack {
    return [self.webView canGoBack];
}

- (BOOL)canGoForward {
    return [self.webView canGoForward];
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
            self.URL = [NSURL URLWithString:link];
            [self openURL:self.URL];
        } else if (buttonIndex == 1) {
            [self.tabsViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
        } else if (buttonIndex == 2) {
            [self performSelectorInBackground:@selector(saveImageURL:) withObject:[NSURL URLWithString:imageSrc]];
        } else if (buttonIndex == 3) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (link) {
        if (buttonIndex == 0) {
            self.URL = [NSURL URLWithString:link];
            [self openURL:self.URL];
        } else if (buttonIndex == 1) {
            [self.tabsViewController addTabWithURL:[NSURL URLWithString:link] withTitle:link];
        } else if (buttonIndex == 2) {
            [UIPasteboard generalPasteboard].string = link;
        }
    } else if (imageSrc) {
        if (buttonIndex == 0) {
            NSURL *url = [NSURL URLWithString:imageSrc];
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (data) {
                UIImage *img = [UIImage imageWithData:data];
                UIImageWriteToSavedPhotosAlbum(img, self, 
                                               @selector(image:didFinishSavingWithError:contextInfo:), nil);
            }
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

@end
