//
//  FillrSDK.h
//  FillrSDK
//
//  Created by Alex Bin Zhao on 28/04/2015.
//  Copyright (c) 2015 Pop Tech Pty. Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

typedef enum {
    FillrStateDownloadingApp,
    FillrStateOpenApp,
    FillrStateFormFilled
} FillrSessionState;

@protocol FillrDelegate<NSObject>
- (void)fillrStateChanged:(FillrSessionState)state currentWebView:(UIView *)currentWebView;
@end

@interface Fillr : NSObject

@property (assign, nonatomic) BOOL overlayInputAccessoryView;
@property (assign, nonatomic) id <FillrDelegate> delegate;

+ (Fillr *)sharedInstance;

- (void)initialiseWithDevKey:(NSString *)devKey andUrlSchema:(NSString *)urlSchema;

- (BOOL)canHandleOpenURL:(NSURL *)url;
- (void)handleOpenURL:(NSURL *)url;

- (void)installFillr;
- (void)trackWebview:(UIView *)webViewToTrack;

- (void)setEnabled:(BOOL)enabled;

@end
