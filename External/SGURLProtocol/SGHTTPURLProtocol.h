//
//  SGURLProtocol.h
//  SGProtocol
//
//  Created by Simon Grätzer on 25.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import "SGURLProtocol.h"

@protocol SGHTTPAuthDelegate <NSObject>

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;

//
//@optional
//- (void)URLProtocol:(NSURLProtocol *)protocol didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;

@end

@class SGHTTPAuthenticationChallenge;

@interface SGHTTPURLProtocol : NSURLProtocol <NSStreamDelegate, NSURLAuthenticationChallengeSender>
@property (strong, nonatomic) SGHTTPAuthenticationChallenge *authChallenge;

+ (void)registerProtocol;
+ (void)unregisterProtocol;
+ (void)setAuthDelegate:(id<SGHTTPAuthDelegate>)delegate;
+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

@end