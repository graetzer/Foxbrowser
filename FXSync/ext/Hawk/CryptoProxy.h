//
//  CryptoProxy.h
//  Hawk
//
//  Created by Jesse Stuart on 8/9/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import <Foundation/Foundation.h>

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>

typedef NS_ENUM(NSUInteger, CryptoAlgorithm) {
    CryptoAlgorithmSHA1,
    CryptoAlgorithmSHA224,
    CryptoAlgorithmSHA256,
    CryptoAlgorithmSHA384,
    CryptoAlgorithmSHA512
};

@interface CryptoProxy : NSObject

@property (nonatomic) CryptoAlgorithm algorithm;

+ (CryptoProxy *)cryptoProxyWithAlgorithm:(CryptoAlgorithm)algorithm;

#pragma mark - Digest

+ (NSData *)sha1DigestFromData:(NSData *)input;

+ (NSData *)sha224DigestFromData:(NSData *)input;

+ (NSData *)sha256DigestFromData:(NSData *)input;

+ (NSData *)sha384DigestFromData:(NSData *)input;

+ (NSData *)sha512DigestFromData:(NSData *)input;

# pragma mark - Hmac

+ (NSData *)sha1HmacFromData:(NSData *)input withKey:(NSData *)key;

+ (NSData *)sha224HmacFromData:(NSData *)input withKey:(NSData *)key;

+ (NSData *)sha256HmacFromData:(NSData *)input withKey:(NSData *)key;

+ (NSData *)sha384HmacFromData:(NSData *)input withKey:(NSData *)key;

+ (NSData *)sha512HmacFromData:(NSData *)input withKey:(NSData *)key;

#pragma mark -

- (NSData *)digestFromData:(NSData *)input;

- (NSData *)hmacFromData:(NSData *)input withKey:(NSData *)key;

@end
