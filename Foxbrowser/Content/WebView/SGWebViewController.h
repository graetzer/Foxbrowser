//
//  SGViewController.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer


#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import "SGURLProtocol.h"

@class SGTabsViewController;

@interface SGWebViewController : UIViewController <UIWebViewDelegate, UIGestureRecognizerDelegate,
UIActionSheetDelegate, UIAlertViewDelegate, SGAuthDelegate>

@property (strong, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) NSURL *location;
@property (assign, nonatomic, getter = isLoading) BOOL loading;

- (void)openURL:(NSURL *)url;

- (void)reload;
@end
