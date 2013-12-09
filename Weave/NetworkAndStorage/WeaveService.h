//
//  SGWeaveService.h
//  Foxbrowser
//
//  Created by simon on 10.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol WeaveService <NSObject>

//put up an alert explaining what just went wrong
- (void) reportErrorWithInfo: (NSDictionary*)errInfo;

//put up an alert view specific to authentication issues, allowing the user to either ignore the problem, or sign out
- (void) reportAuthErrorWithMessage: (NSDictionary*)errInfo;

- (BOOL) canConnectToInternet;

- (void) startProgressSpinnersWithMessage:(NSString*)msg;
- (void) changeProgressSpinnersMessage:(NSString*)msg;
- (void) stopProgressSpinners;

- (void) login;
- (void) refreshViews;
- (void) eraseAllUserData;

- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)wait;
@end

FOUNDATION_EXTERN NSString *kWeaveDataRefreshNotification;
FOUNDATION_EXTERN NSString *kWeaveBackgroundedAtTime;
FOUNDATION_EXTERN NSString *kWeaveSyncStatusChangedNotification;
FOUNDATION_EXTERN NSString *kWeaveMessageKey;
FOUNDATION_EXTERN NSString *kWeaveShowedFirstRunPage;
FOUNDATION_EXTERN NSString *kWeaveUseNativeApps;
FOUNDATION_EXTERN NSString *kWeavePrivateMode;

BOOL IsNativeAppURLWithoutChoice(NSURL* link);
BOOL IsNativeAppURL(NSURL* url);
BOOL IsBlockedURL(NSURL* url);

extern id<WeaveService> weaveService;

@interface WeaveOperations : NSObject <UIAlertViewDelegate>

- (NSURL *)parseURLString:(NSString *)input;
- (NSString *)urlEncode:(NSString *)string;
- (NSURL *)queryURLForTerm:(NSString *)string;
- (BOOL)handleURLInternal:(NSURL *)url;
- (void)addHistoryURL:(NSURL *)url title:(NSString *)title;

+ (WeaveOperations *)sharedOperations;

@end