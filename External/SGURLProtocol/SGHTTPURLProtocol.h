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
@property (strong, nonatomic) NSHTTPURLResponse *URLResponse;


+ (void)registerProtocol;
+ (void)unregisterProtocol;

+ (id<SGHTTPAuthDelegate>)authDelegate;
+ (void)setAuthDelegate:(id<SGHTTPAuthDelegate>)delegate;//weak

/// Set values for http request fields that overwrite any of the values in the requests
/// Useful for HTTP Agent
+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

+ (BOOL)SSLValidatesCertificateChain;
+ (void)setSSLValidatesCertificateChain:(BOOL)validate;

@end