//
//  SGWeaveService.h
//  Foxbrowser
//
//  Created by simon on 10.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

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

extern NSString *kWeaveDataRefreshNotification;
extern NSString *kWeaveBackgroundedAtTime;
extern NSString *kWeaveSyncStatusChangedNotification;
extern NSString *kWeaveMessageKey;
extern NSString *kWeaveShowedFirstRunPage;
extern NSString *kWeaveUseNativeApps;
extern NSString *kWeavePrivateMode;

BOOL IsNativeAppURLWithoutChoice(NSURL* link);
BOOL IsNativeAppURL(NSURL* url);
BOOL IsSafariURL(NSURL* url);
BOOL IsBlockedURL(NSURL* url);

extern id<WeaveService> weaveService;

@interface WeaveOperations : NSObject
@property (strong, atomic) NSOperationQueue *queue;

- (NSURL *)parseURLString:(NSString *)input;
- (NSString *)urlEncode:(NSString *)string;
- (NSString *)searchURL:(NSString *)string;
- (BOOL)handleURLInternal:(NSURL *)url;
- (void)modifyRequest:(NSURLRequest *)request;
- (void)addHistoryURL:(NSURL *)url title:(NSString *)title;

+ (WeaveOperations *)sharedOperations;

@end