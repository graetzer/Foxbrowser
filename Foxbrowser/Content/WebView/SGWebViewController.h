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

#import "SGToolbar.h"

@class SGTabsViewController;

@interface SGWebViewController : UIViewController <UITextFieldDelegate, UIWebViewDelegate, 
UIGestureRecognizerDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
}

@property (strong, nonatomic) IBOutlet UIWebView *webView;

@property (readonly, nonatomic) NSURLRequest *request;
@property (readonly, nonatomic, getter = isLoading) BOOL loading;

- (void)openURL:(NSURL *)url;
@end
