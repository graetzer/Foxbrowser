//
//  HawkAuth.m
//  Hawk
//
//  Created by Jesse Stuart on 8/9/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import "HawkAuth.h"
#import "NSData+Base64.h"
#import "NSString+Base64.h"
#import "NSString+Parser.h"
#import "NSString+Trim.h"

@implementation HawkAuth

- (CryptoProxy *)cryptoProxy
{
    return [CryptoProxy cryptoProxyWithAlgorithm:self.credentials.algorithm];
}

- (NSString *)normalizedStringWithType:(HawkAuthType)type
{
    NSMutableData *normalizedString = [[NSMutableData alloc] init];

    NSString *hawkType;
    switch (type) {
        case HawkAuthTypeHeader:
            hawkType = @"header";
            break;
        case HawkAuthTypeResponse:
            hawkType = @"response";
            break;
        case HawkAuthTypeBewit:
            hawkType = @"bewit";
            break;
    }

    // header
    [normalizedString appendData:[[NSString stringWithFormat:@"hawk.1.%@\n", hawkType] dataUsingEncoding:NSUTF8StringEncoding]];

    // timestamp
    [normalizedString appendData:[[NSString stringWithFormat:@"%.0f\n", [self.timestamp timeIntervalSince1970]] dataUsingEncoding:NSUTF8StringEncoding]];

    // nonce
    if (self.nonce) {
        [normalizedString appendData:[self.nonce dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // method
    [normalizedString appendData:[self.method dataUsingEncoding:NSUTF8StringEncoding]];
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // request uri
    [normalizedString appendData:[self.requestUri dataUsingEncoding:NSUTF8StringEncoding]];
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // host
    [normalizedString appendData:[self.host dataUsingEncoding:NSUTF8StringEncoding]];
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // port
    [normalizedString appendData:[[NSString stringWithFormat:@"%i\n", [self.port intValue]] dataUsingEncoding:NSUTF8StringEncoding]];

    // hash
    if (self.payload) {
        [normalizedString appendData:[[self payloadHash] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // ext
    if (self.ext) {
        [normalizedString appendData:[self.ext dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // app
    if (self.app) {
        if (!self.dig) {
            self.dig = @"";
        }

        [normalizedString appendData:[[NSString stringWithFormat:@"%@\n", self.app] dataUsingEncoding:NSUTF8StringEncoding]];
        [normalizedString appendData:[[NSString stringWithFormat:@"%@\n", self.dig] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    return [[NSString alloc] initWithData:normalizedString encoding:NSUTF8StringEncoding];
}

- (NSString *)normalizedPayloadString
{
    NSMutableData *normalizedString = [[NSMutableData alloc] init];

    [normalizedString appendData:[@"hawk.1.payload\n" dataUsingEncoding:NSUTF8StringEncoding]];

    NSString *contentType = [[[self.contentType componentsSeparatedByString:@";"] objectAtIndex:0] stringByTrimmingLeadingAndTrailingWhitespace];

    [normalizedString appendData:[contentType dataUsingEncoding:NSUTF8StringEncoding]];
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    [normalizedString appendData:self.payload];
    [normalizedString appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

    return [[NSString alloc] initWithData:normalizedString encoding:NSUTF8StringEncoding];
}

- (NSString *)payloadHash
{
    CryptoProxy *cryptoProxy = [CryptoProxy cryptoProxyWithAlgorithm:self.credentials.algorithm];

    NSData *hash = [cryptoProxy digestFromData:[[self normalizedPayloadString] dataUsingEncoding:NSUTF8StringEncoding]];

    self.cryptoHash = [hash base64EncodedString];

    return self.cryptoHash;
}

- (NSString *)hmacWithType:(HawkAuthType)type
{
    NSData *normalizedString = [[self normalizedStringWithType:type] dataUsingEncoding:NSUTF8StringEncoding];

    CryptoProxy *cryptoProxy = [self cryptoProxy];

    NSData *hmac = [cryptoProxy hmacFromData:normalizedString withKey:self.credentials.key];

    self.hmac = [hmac base64EncodedString];

    return self.hmac;
}

- (NSString *)timestampSkewHmac
{
    NSString *normalizedString = [NSString stringWithFormat:@"hawk.1.ts\n%.0f\n", [self.timestamp timeIntervalSince1970]];

    CryptoProxy *cryptoProxy = [self cryptoProxy];

    NSData *hmac = [cryptoProxy hmacFromData:[normalizedString dataUsingEncoding:NSUTF8StringEncoding] withKey:self.credentials.key];

    return [hmac base64EncodedString];
}

- (NSString *)bewit
{
    NSString *hmac = [self hmacWithType:HawkAuthTypeBewit];

    if (!self.ext) {
        self.ext = @"";
    }

    NSString *normalizedString = [NSString stringWithFormat:@"%@\\%.0f\\%@\\%@", self.credentials.hawkId, [self.timestamp timeIntervalSince1970], hmac, self.ext];

    NSString *bewit = [[normalizedString base64EncodedString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];

    bewit = [bewit stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    bewit = [bewit stringByReplacingOccurrencesOfString:@"/" withString:@"_"];

    return bewit;
}

#pragma mark -

- (NSString *)requestHeader
{
    NSMutableData *header = [[NSMutableData alloc] init];

    // id
    [header appendData:[[NSString stringWithFormat:@"Authorization: Hawk id=\"%@\"", self.credentials.hawkId] dataUsingEncoding:NSUTF8StringEncoding]];

    // mac
    [header appendData:[[NSString stringWithFormat:@", mac=\"%@\"", [self hmacWithType:HawkAuthTypeHeader]] dataUsingEncoding:NSUTF8StringEncoding]];

    // timestamp
    [header appendData:[[NSString stringWithFormat:@", ts=\"%.0f\"", [self.timestamp timeIntervalSince1970]] dataUsingEncoding:NSUTF8StringEncoding]];

    // nonce
    [header appendData:[[NSString stringWithFormat:@", nonce=\"%@\"", self.nonce] dataUsingEncoding:NSUTF8StringEncoding]];

    // hash
    if (self.payload) {
        [header appendData:[[NSString stringWithFormat:@", hash=\"%@\"", [self payloadHash]] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    // app
    if (self.app) {
        [header appendData:[[NSString stringWithFormat:@", app=\"%@\"", self.app] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    return [[NSString alloc] initWithData:header encoding:NSUTF8StringEncoding];
}

- (NSString *)responseHeader
{
    // mac
    NSMutableData *header = [[NSMutableData alloc] initWithData:[[NSString stringWithFormat:@"Server-Authorization: Hawk mac=\"%@\"", [self hmacWithType:HawkAuthTypeResponse]] dataUsingEncoding:NSUTF8StringEncoding]];

    // hash
    if (self.payload) {
        [header appendData:[[NSString stringWithFormat:@", hash=\"%@\"", [self payloadHash]] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    return [[NSString alloc] initWithData:header encoding:NSUTF8StringEncoding];
}

- (NSString *)timestampSkewHeader
{
    NSString *tsm = [self timestampSkewHmac];
    NSString *header = [NSString stringWithFormat:@"WWW-Authenticate: Hawk ts=\"%.0f\", tsm=\"%@\", error=\"timestamp skew too high\"", [self.timestamp timeIntervalSince1970], tsm];

    return header;
}

#pragma mark -

- (NSDictionary *)parseAuthorizationHeader:(NSString *)header
{
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];

    NSArray *parts = [[header substringFromIndex:(int)[header firstIndexOf:@"Hawk "] + 5] componentsSeparatedByString:@", "];

    NSString *partKey;
    NSString *partValue;
    NSUInteger *splitIndex;
    for (NSString *part in parts) {

        splitIndex = [part firstIndexOf:@"="];

        partKey = [part substringToIndex:(int)splitIndex];

        partValue = [part substringFromIndex:(int)splitIndex + 2]; // remove key="
        partValue = [partValue substringToIndex:partValue.length - 1]; // remove trailing "

        [attributes setObject:partValue forKey:partKey];
    }
    
    return [NSDictionary dictionaryWithDictionary:attributes];
}

- (HawkError *)validateRequestHeader:(NSString *)header
                   credentialsLookup:(HawkCredentials *(^)(NSString *hawkId))credentialsLookup
                         nonceLookup:(BOOL (^)(NSString *nonce))nonceLookup
{
    NSDictionary *headerAttributes = [self parseAuthorizationHeader:header];

    // id lookup

    NSString *hawkId = [headerAttributes objectForKey:@"id"];

    if (!hawkId) {
        return [HawkError hawkErrorWithReason:HawkErrorUnknownId];
    }

    HawkCredentials *credentials = credentialsLookup(hawkId);

    if (!credentials) {
        return [HawkError hawkErrorWithReason:HawkErrorUnknownId];
    }

    // set attributes

    self.credentials = credentials;

    self.nonce = [headerAttributes objectForKey:@"nonce"];

    self.timestamp = [[NSDate alloc] initWithTimeIntervalSince1970:[[[NSNumberFormatter alloc] numberFromString:[headerAttributes objectForKey:@"ts"]] doubleValue]];

    self.app = [headerAttributes objectForKey:@"app"];

    // validate payload hash

    NSString *hash = [headerAttributes objectForKey:@"hash"];
    if (hash) {
        NSString *expectedPayloadHash = [self payloadHash];

        if (![expectedPayloadHash isEqualToString:hash]) {
            return [HawkError hawkErrorWithReason:HawkErrorInvalidPayloadHash];
        }
    }

    // validate hmac

    NSString *expectedMac = [self hmacWithType:HawkAuthTypeHeader];
    NSString *mac = [headerAttributes objectForKey:@"mac"];

    if (![expectedMac isEqualToString:mac]) {
        return [HawkError hawkErrorWithReason:HawkErrorInvalidMac];
    }

    // valid
    return nil;
}

- (HawkError *)validateResponseHeader:(NSString *)header
{
    NSDictionary *headerAttribtues = [self parseAuthorizationHeader:header];

    NSString *hash = [headerAttribtues objectForKey:@"hash"];

    // validate payload hash

    if (hash) {
        NSString *expectedHash = [self payloadHash];

        if (![expectedHash isEqualToString:hash]) {
            return [HawkError hawkErrorWithReason:HawkErrorInvalidPayloadHash];
        }
    }

    // validate hmac

    NSString *mac = [headerAttribtues objectForKey:@"mac"];

    NSString *expectedMac = [self hmacWithType:HawkAuthTypeResponse];

    if (![expectedMac isEqualToString:mac]) {
        return [HawkError hawkErrorWithReason:HawkErrorInvalidMac];
    }

    // valid
    return nil;
}

- (HawkError *)validateBewit:(NSString *)bewit
           credentialsLookup:(HawkCredentials *(^)(NSString *hawkId))credentialsLookup
                  serverTime:(NSDate *)serverTime
{
    // parse bewit

    NSString *padding = [[[NSString alloc] init] stringByPaddingToLength:((4 - bewit.length) % 4) withString:@"=" startingAtIndex:0];

    NSString *normalizedString = [[bewit stringByAppendingString:padding] base64DecodedString];

    NSArray *parts = [normalizedString componentsSeparatedByString:@"\\"];

    // id\ts\mac\ext
    if (parts.count != 4) {
        return [HawkError hawkErrorWithReason:HawkErrorMalformedBewit];
    }

    // id lookup

    NSString *hawkId = [parts objectAtIndex:0];
    HawkCredentials *credentials = credentialsLookup(hawkId);

    if (!credentials) {
        return [HawkError hawkErrorWithReason:HawkErrorUnknownId];
    }

    // set attributes

    self.credentials = credentials;

    self.timestamp = [[NSDate alloc] initWithTimeIntervalSince1970:[[[NSNumberFormatter alloc] numberFromString:[parts objectAtIndex:1]] doubleValue]];

    self.ext = [parts objectAtIndex:3];

    NSString *mac = [parts objectAtIndex:2];

    // validate timestamp

    if ([self.timestamp timeIntervalSince1970] > [serverTime timeIntervalSince1970]) {
        return [HawkError hawkErrorWithReason:HawkErrorBewitExpired];
    }

    // validate hmac

    NSString *expectedMac = [self hmacWithType:HawkAuthTypeBewit];

    if (![expectedMac isEqualToString:mac]) {
        return [HawkError hawkErrorWithReason:HawkErrorInvalidMac];
    }

    // valid
    return nil;
}

@end
