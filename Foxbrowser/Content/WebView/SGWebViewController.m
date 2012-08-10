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
#import "NSURL+Compare.h"
#import "DDAlertPrompt.h"

@interface SGWebViewController ()
@property (strong, nonatomic) NSDictionary *selected;

// For custom loading
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *buffer;
@property (nonatomic, strong) DDAlertPrompt *credPrompt;

- (void)addHistoryRequest:(NSURLRequest *)request;
@end

@implementation SGWebViewController

+ (void)load {
    // Enable cookies
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage
                                          sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
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

#pragma mark - Propertys

@synthesize history = _history;
- (NSMutableArray *)history {
    if (!_history) {
        _history = [[NSMutableArray alloc] initWithCapacity:5];
    }
    return _history;
}

# pragma mark - SGBarDelegate

- (void)reload {
    [self openURL:nil];
}

- (void)stop {
    [self.webView stopLoading];
    [self cancelConnection];
}

- (void)goBack {
    _historyPointer--;
    NSURLRequest *request = [self.history objectAtIndex:_historyPointer];
    if ([self.request.URL isEqualExceptFragment:request.URL]) {
        [self.webView setLocationHash:request.URL.fragment];
    } else {
        [self loadRequest:request];
    }
}

- (void)goForward {
    _historyPointer++;
    NSURLRequest *request = [self.history objectAtIndex:_historyPointer];
    if ([self.request.URL isEqualExceptFragment:request.URL]) {
        [self.webView setLocationHash:request.URL.fragment];
    } else {
        [self loadRequest:request];
    }
}

- (BOOL)canGoBack {
    return _historyPointer >= 1;
}

- (BOOL)canGoForward {
    return self.history.count && _historyPointer < self.history.count - 1;
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
    if (navigationType != UIWebViewNavigationTypeOther) {
        [self addHistoryRequest:request];
        if ([self.request.URL isEqualExceptFragment:request.URL]) {
            // Switch to an anchor in the same page
            _request = request;
            [self.tabsViewController updateChrome];
            return YES;
        }
        
        if ([WeaveOperations handleURLInternal:request.URL])
            [self loadRequest:request];
        
        return NO;
    }
    [self.tabsViewController updateChrome];
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    _loading = YES;
    [self.tabsViewController updateChrome];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [webView disableContextMenu];
    self.title = [webView title];
    _request = webView.request;
    
    _loading = NO;
    [self.tabsViewController updateChrome];
    
    // Do the screenshot if needed
    NSString *path = [UIWebView pathForURL:self.request.URL];
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
    
    _loading = NO;
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

- (void)addHistoryRequest:(NSURLRequest *)request {
    //if (![self.history containsObject:request]) {
        if (self.history.count && _historyPointer < self.history.count - 1) {
            [self.history removeObjectsAtIndexes:
             [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(_historyPointer + 1, self.history.count - _historyPointer - 1)]];
        }
        _historyPointer = self.history.count;
        [self.history addObject:request];
    //}
}

#pragma mark NSURLConnectionDelegate
 
- (void)openURL:(NSURL *)url {
    if (url) {
        _request = [NSURLRequest requestWithURL:url
                                    cachePolicy:NSURLRequestReloadRevalidatingCacheData
                                timeoutInterval:10.];
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
        //[self.webView clearContent];
        [self addHistoryRequest:self.request];
        [self loadRequest:self.request];
    }
}

- (void)loadRequest:(NSURLRequest *)request {
    if (_request != request)
        _request = request;
    
    _loading = YES;
    [self.tabsViewController updateChrome];
    
    [self.connection cancel];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (self.connection != connection) {
        [challenge.sender cancelAuthenticationChallenge:challenge];
        return;
    }
    
    if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
    {
        SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        SecTrustResultType result;
        SecTrustEvaluate(serverTrust, &result);
        
        if(result == kSecTrustResultProceed) {
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        } else if(result == kSecTrustResultConfirm) {
            if (_userConfirmedCert) {
                // Cert not trusted, but user is OK with that
                [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
                _userConfirmedCert = NO;
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Untrusted server certificate", @"The cert the server provided is not trusted")
                                                                message:NSLocalizedString(@"Caution: use at own risk", @"Caution: use at own risk")
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
                                                      otherButtonTitles:NSLocalizedString(@"OK", @"ok"), nil];
                [alert show];
                [self cancelConnection];
            }
        } else {
            // invalid or revoked certificate
            //[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
            //[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
//            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading Page", @"error loading page")
//                                                            message:NSLocalizedString(@"Invalid or revoked certificate", @"The Servert cert is not valid")
//                                                           delegate:nil
//                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"ok")
//                                                  otherButtonTitles:nil];
//            [alert show];
            [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    }
    else if(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
            || challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest
            || challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodNTLM)
    {
        if (self.credPrompt && challenge.previousFailureCount == 0) {
            NSString *user = [self.credPrompt.plainTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *pass = [self.credPrompt.secretTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            //NSURLCredentialPersistencePermanent TODO: ask user if he wants to save it 
            NSURLCredential *credential = [NSURLCredential credentialWithUser:user
                                                                     password:pass
                                                                  persistence:NSURLCredentialPersistenceForSession];
            [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
            self.credPrompt = nil;
        } else {
            self.credPrompt = [[DDAlertPrompt alloc] initWithTitle:NSLocalizedString(@"Authorizing", @"Authorizing")
                                                      delegate:self
                                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
                                              otherButtonTitle:NSLocalizedString(@"OK", @"ok")];
            
            if (challenge.proposedCredential) {
                if (challenge.proposedCredential.hasPassword && challenge.previousFailureCount == 0) {
                    [challenge.sender useCredential:challenge.proposedCredential forAuthenticationChallenge:challenge];
                    return;
                } else {
                    self.credPrompt.plainTextField.text = challenge.proposedCredential.user;
                }
            }
            // Cancel the request and show the prompt
            // If the user entert everything, retry the request
            [self.credPrompt show];
            [self cancelConnection];
        }
    } else {
        [challenge.sender cancelAuthenticationChallenge:challenge];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
//    if (self.credPrompt == alertView) {
        if (buttonIndex == 0) {
            [self cancelConnection];
            self.credPrompt = nil;
        }else if (buttonIndex == 1) {
            [self loadRequest:self.request];// Reload the request
        }
//    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (self.connection == connection) {
        [self cancelConnection];
        self.response = nil;
        self.credPrompt = nil;
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading Page", @"error loading page")
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"ok") otherButtonTitles: nil];
        [alert show];
    }
}

// http://stackoverflow.com/questions/1446509/handling-redirects-correctly-with-nsurlconnection
- (NSURLRequest *)connection: (NSURLConnection *)inConnection
             willSendRequest: (NSURLRequest *)inRequest
            redirectResponse: (NSURLResponse *)inRedirectResponse;
{
    if (inRedirectResponse) {
        DLog(@"Redirected to %@", [[inRequest URL] absoluteString]);
        NSMutableURLRequest *r = [self.request mutableCopy];
        [r setURL: [inRequest URL]];
        _request = r;
        return r;
    } else {
        return inRequest;
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return cachedResponse;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if (self.connection == connection) {
        long long length = response.expectedContentLength != NSURLResponseUnknownLength ? response.expectedContentLength : 1024*512;
        self.buffer = [[NSMutableData alloc] initWithCapacity:length];
        self.response = response;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (self.connection == connection) {
        [self.buffer appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (self.connection != connection)
        return;
    
    [self.webView loadData:self.buffer
                  MIMEType:_response.MIMEType
          textEncodingName:_response.textEncodingName
                   baseURL:_response.URL];
    
    self.connection = nil;
    self.buffer = nil;
    _loading = NO;
    [self.tabsViewController updateChrome];
}

- (void)cancelConnection {
    [self.connection cancel];
    self.connection = nil;
    self.buffer = nil;
    
    _loading = NO;
    [self.tabsViewController updateChrome];
}

@end
