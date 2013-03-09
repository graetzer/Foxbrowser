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

@end

@class SGHTTPAuthenticationChallenge;

@interface SGHTTPURLProtocol : NSURLProtocol <NSStreamDelegate, NSURLAuthenticationChallengeSender>
@property (strong, nonatomic) SGHTTPAuthenticationChallenge *authChallenge;

+ (void)registerProtocol;
+ (void)unregisterProtocol;

+ (void)setAuthDelegate:(id<SGHTTPAuthDelegate>)delegate;

/// Set values for http request fields that overwrite any of the values in the requests
/// Useful for HTTP Agent
+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

+ (BOOL)SSLValidatesCertificateChain;
+ (void)setSSLValidatesCertificateChain:(BOOL)validate;

@end