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

typedef enum {
    SGWebTypeLink,
    SGWebTypeImage
} SGWebType;

@class SGTabsViewController, DDAlertPrompt;

@interface SGWebViewController : UIViewController <UITextFieldDelegate, UIWebViewDelegate, 
UIGestureRecognizerDelegate, UIActionSheetDelegate, SGToolbarDelegate, NSURLConnectionDelegate, UIAlertViewDelegate> {
    NSUInteger _historyPointer;
    BOOL _userConfirmedCert;
}

@property (strong, nonatomic) IBOutlet UIWebView *webView;

@property (readonly, nonatomic) NSURLRequest *request;
@property (readonly, nonatomic, getter = isLoading) BOOL loading;
@property (readonly, nonatomic) NSMutableArray *history;

- (void)openURL:(NSURL *)url;
@end
