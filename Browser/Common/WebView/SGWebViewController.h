//
//  SGViewController.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <AVFoundation/AVFoundation.h>

#import "NJKWebViewProgress.h"

@interface SGWebViewController : UIViewController <UIWebViewDelegate, UIGestureRecognizerDelegate,
UIActionSheetDelegate, UIViewControllerRestoration, NJKWebViewProgressDelegate>

@property (weak, nonatomic) UIWebView *webView;
@property (weak, nonatomic) UIToolbar *searchToolbar;

@property (strong, nonatomic) NSURLRequest *request;
@property (nonatomic, readonly, assign) BOOL canGoBack;
@property (nonatomic, readonly, assign) BOOL canGoForward;
@property (assign, nonatomic, readonly, getter = isLoading) BOOL loading;
@property (assign, nonatomic, readonly) float progress;

/// Loads a request
/// If parameter request is nil, the last loaded request will be reloaded
- (void)openRequest:(NSURLRequest *)request;
- (NSInteger)search:(NSString *)searchString;

@end
