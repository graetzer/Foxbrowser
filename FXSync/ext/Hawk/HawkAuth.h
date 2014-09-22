//
//  HawkAuth.h
//  Hawk
//
//  Created by Jesse Stuart on 8/9/13.
//  nonatomicright (c) 2013 Tent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HawkCredentials.h"
#import "HawkError.h"

typedef NS_ENUM(NSUInteger, HawkAuthType) {
    HawkAuthTypeHeader,
    HawkAuthTypeResponse,
    HawkAuthTypeBewit
};

@interface HawkAuth : NSObject

@property (nonatomic) HawkCredentials *credentials;

@property (nonatomic) NSString *method;
@property (nonatomic) NSString *requestUri;
@property (nonatomic) NSString *host;
@property (nonatomic) NSNumber *port;

@property (nonatomic) NSDate *timestamp;
@property (nonatomic) NSString *nonce;
@property (nonatomic) NSString *ext;

@property (nonatomic) NSString *app;
@property (nonatomic) NSString *dig;

@property (nonatomic) NSData *payload;
@property (nonatomic) NSString *contentType;

@property (nonatomic) NSString *cryptoHash;
@property (nonatomic) NSString *hmac;

#pragma mark -

// Returns an instance of CryptoProxy using self.credentials.algorithm
- (CryptoProxy *)cryptoProxy;

// Returns input string for hmac functions
- (NSString *)normalizedStringWithType:(HawkAuthType)type;

// Returns input string for hash digest function
- (NSString *)normalizedPayloadString;

// Sets and returns hash property
- (NSString *)payloadHash;

// Sets and returns hmac property
- (NSString *)hmacWithType:(HawkAuthType)type;

// Returns hmac for timestamp skew header
- (NSString *)timestampSkewHmac;

- (NSString *)bewit;

#pragma mark -

- (NSString *)requestHeader;

- (NSString *)responseHeader;

- (NSString *)timestampSkewHeader;

#pragma mark -

// Parses header attributes
- (NSDictionary *)parseAuthorizationHeader:(NSString *)header;

// Returns an instance of HawkError if invalid or nil if valid
// Sets self.credentials if valid
// self.nonce, self.timestamp, and self.app are set with values from header when valid hawk id
// credentialsLookup(<hawk id>) block should return an instance of HawkCredentials or nil
// nonceLookup(<nonce>) block should return YES if nonce has been used before or NO
- (HawkError *)validateRequestHeader:(NSString *)header
                   credentialsLookup:(HawkCredentials *(^)(NSString *hawkId))credentialsLookup
                         nonceLookup:(BOOL (^)(NSString *nonce))nonceLookup;

- (HawkError *)validateResponseHeader:(NSString *)header;

- (HawkError *)validateBewit:(NSString *)bewit
           credentialsLookup:(HawkCredentials *(^)(NSString *hawkId))credentialsLookup
                  serverTime:(NSDate *)serverTime;

@end
