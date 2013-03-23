//
//  SGURLProtocol.h
//  SGProtocol
//
//  Created by Simon Grätzer on 25.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import <Security/SecureTransport.h>

#import "SGURLProtocol.h"

@class SGHTTPURLProtocol, SGHTTPAuthenticationChallenge;

@protocol SGHTTPURLProtocolDelegate <NSObject>

@optional
- (void)URLProtocol:(SGHTTPURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (BOOL)URLProtocol:(SGHTTPURLProtocol *)protocol canIgnoreUntrustedHost:(SecTrustRef)trust;

@end


@interface SGHTTPURLProtocol : NSURLProtocol <NSStreamDelegate, NSURLAuthenticationChallengeSender>
@property (strong, nonatomic, readonly) SGHTTPAuthenticationChallenge *authChallenge;
@property (strong, nonatomic, readonly) NSHTTPURLResponse *URLResponse;


+ (void)registerProtocol;
+ (void)unregisterProtocol;

+ (id<SGHTTPURLProtocolDelegate>)protocolDelegate;
+ (void)setProtocolDelegate:(id<SGHTTPURLProtocolDelegate>)delegate;//weak

/// Set values for http request fields that overwrite any of the values in the requests
/// Useful for HTTP Agent
+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/// Default is YES
+ (BOOL)validatesSecureCertificate;
+ (void)setValidatesSecureCertificate:(BOOL)validate;

@end

typedef NS_ENUM(NSInteger, SGURLProtocolError) {
    SGURLProtocolErrorStreamCreation = -1, // HTTP request stream could not be created
    SGURLProtocolErrorInvalidResponse = -200, // HTTP Response was malformed
    SGURLProtocolErrorNoCachedResponse = -304 // response contained HTTP status code 304, but no cached response existed
};