//
//  FXHelpViewController.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 09.10.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//
#import <UIKit/UIKit.h>


@interface FXHelpViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, weak) UIWebView *webView;
@property (nonatomic, weak) UIActivityIndicatorView *activityIndicator;

@end
