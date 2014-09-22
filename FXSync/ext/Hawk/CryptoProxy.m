//
//  CryptoProxy.m
//  Hawk
//
//  Created by Jesse Stuart on 8/9/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import "CryptoProxy.h"

@implementation CryptoProxy

+ (CryptoProxy *)cryptoProxyWithAlgorithm:(CryptoAlgorithm)algorithm
{
    CryptoProxy *cryptoProxy = [[CryptoProxy alloc] init];

    cryptoProxy.algorithm = algorithm;

    return cryptoProxy;
}

#pragma mark - Digest

+ (NSData *)sha1DigestFromData:(NSData *)input
{
    unsigned char hash[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(input.bytes, (CC_LONG)input.length, hash);

    NSData *output = [NSData dataWithBytes:hash length:CC_SHA1_DIGEST_LENGTH];

    return output;
}

+ (NSData *)sha224DigestFromData:(NSData *)input
{
    unsigned char hash[CC_SHA224_DIGEST_LENGTH];
    CC_SHA224(input.bytes, (CC_LONG)input.length, hash);

    NSData *output = [NSData dataWithBytes:hash length:CC_SHA224_DIGEST_LENGTH];

    return output;
}

+ (NSData *)sha256DigestFromData:(NSData *)input
{
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(input.bytes, (CC_LONG)input.length, hash);

    NSData *output = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];

    return output;
}

+ (NSData *)sha384DigestFromData:(NSData *)input
{
    unsigned char hash[CC_SHA384_DIGEST_LENGTH];
    CC_SHA384(input.bytes, (CC_LONG)input.length, hash);

    NSData *output = [NSData dataWithBytes:hash length:CC_SHA384_DIGEST_LENGTH];

    return output;
}

+ (NSData *)sha512DigestFromData:(NSData *)input
{
    unsigned char hash[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(input.bytes, (CC_LONG)input.length, hash);

    NSData *output = [NSData dataWithBytes:hash length:CC_SHA512_DIGEST_LENGTH];

    return output;
}

# pragma mark - Hmac

+ (NSData *)sha1HmacFromData:(NSData *)input withKey:(NSData *)key
{
    unsigned char hmac[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, key.bytes, key.length, input.bytes, (CC_LONG)input.length, hmac);
    NSData *output = [NSData dataWithBytes:hmac length:CC_SHA1_DIGEST_LENGTH];
    return output;
}

+ (NSData *)sha224HmacFromData:(NSData *)input withKey:(NSData *)key
{
    unsigned char hmac[CC_SHA224_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA224, key.bytes, key.length, input.bytes, (CC_LONG)input.length, hmac);
    NSData *output = [NSData dataWithBytes:hmac length:CC_SHA224_DIGEST_LENGTH];
    return output;
}

+ (NSData *)sha256HmacFromData:(NSData *)input withKey:(NSData *)key
{
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, input.bytes, (CC_LONG)input.length, hmac);
    NSData *output = [NSData dataWithBytes:hmac length:CC_SHA256_DIGEST_LENGTH];
    return output;
}

+ (NSData *)sha384HmacFromData:(NSData *)input withKey:(NSData *)key
{
    unsigned char hmac[CC_SHA384_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA384, key.bytes, key.length, input.bytes, (CC_LONG)input.length, hmac);
    NSData *output = [NSData dataWithBytes:hmac length:CC_SHA384_DIGEST_LENGTH];
    return output;
}

+ (NSData *)sha512HmacFromData:(NSData *)input withKey:(NSData *)key
{
    unsigned char hmac[CC_SHA512_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA512, key.bytes, key.length, input.bytes, (CC_LONG)input.length, hmac);
    NSData *output = [NSData dataWithBytes:hmac length:CC_SHA512_DIGEST_LENGTH];
    return output;
}

# pragma mark -

- (NSData *)digestFromData:(NSData *)input
{
    NSData *output;

    switch (self.algorithm) {
        case CryptoAlgorithmSHA1:
            output = [CryptoProxy sha1DigestFromData:input];
            break;
        case CryptoAlgorithmSHA224:
            output = [CryptoProxy sha224DigestFromData:input];
            break;
        case CryptoAlgorithmSHA256:
            output = [CryptoProxy sha256DigestFromData:input];
            break;
        case CryptoAlgorithmSHA384:
            output = [CryptoProxy sha384DigestFromData:input];
            break;
        case CryptoAlgorithmSHA512:
            output = [CryptoProxy sha512DigestFromData:input];
            break;
    }

    return output;
}

- (NSData *)hmacFromData:(NSData *)input withKey:(NSData *)key
{
    NSData *output;

    switch (self.algorithm) {
        case CryptoAlgorithmSHA1:
            output = [CryptoProxy sha1HmacFromData:input withKey:key];
            break;
        case CryptoAlgorithmSHA224:
            output = [CryptoProxy sha224HmacFromData:input withKey:key];
            break;
        case CryptoAlgorithmSHA256:
            output = [CryptoProxy sha256HmacFromData:input withKey:key];
            break;
        case CryptoAlgorithmSHA384:
            output = [CryptoProxy sha384HmacFromData:input withKey:key];
            break;
        case CryptoAlgorithmSHA512:
            output = [CryptoProxy sha512HmacFromData:input withKey:key];
            break;
    }

    return output;
}

@end
