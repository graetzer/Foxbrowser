//
//  SGViewController.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer


#import <UIKit/UIKit.h>
#import "SGToolbar.h"

typedef enum {
    SGWebTypeLink,
    SGWebTypeImage
} SGWebType;

@class SGTabsViewController;

@interface SGWebViewController : UIViewController <UITextFieldDelegate, UIWebViewDelegate, 
UIGestureRecognizerDelegate, UIActionSheetDelegate, SGToolbarDelegate>
@property (strong, nonatomic) IBOutlet UIWebView *webView;

@property (strong, nonatomic) NSURL *URL;
@property (readonly, nonatomic, getter = isLoading) BOOL loading;

- (void)start;


@end
