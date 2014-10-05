//
//  FXAccountClient.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 14.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXAccountClient.h"
#import "HawkAuth.h"
#import "NSData+Ext.h"
#import "HawkAuth.h"

NSString *const kFXAccountsServerDefault = @"https://api.accounts.firefox.com/v1";
NSTimeInterval const kFXConnectionTimeout = 120.0;


NSUInteger const INVALID_TIMESTAMP = 111;
NSUInteger const INCORRECT_EMAIL_CASE = 120;


// Key wrapping and stretching configuration.
NSString *const kFXNamespace = @"identity.mozilla.com/picl/v1/";
uint const PBKDF2_ROUNDS = 1000;
uint const STRETCHED_PASS_LENGTH_BYTES = 32;

@implementation FXAccountClient {
    NSOperationQueue *_queue;
}

- (instancetype)init {
    if (self = [super init]) {
        _localTimeOffsetSec = @0;
        _queue = [NSOperationQueue new];
    }
    return self;
}

- (void)signInEmail:(NSString *)email
           password:(NSString *)password
         completion:(void(^)(NSDictionary *))completion {
    NSParameterAssert(email && password && completion);
    
    NSDictionary *setup = [self _setupEmail:email password:password];
    NSDictionary *body = @{@"email" : email,
                           @"authPW" : setup[@"authPW"]};
    
    NSString *urlStr = [NSString stringWithFormat:@"%@%@?keys=true", kFXAccountsServerDefault, @"/account/login"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:kFXConnectionTimeout];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    
    [self sendHawkRequest:req
              credentials:nil
               completion:^(NSHTTPURLResponse *resp, id json, NSError *error) {
                   if (error == nil && json[@"error"] == nil) {
                       NSMutableDictionary *accountData = [json mutableCopy];
                       accountData[@"unwrapBKey"] = setup[@"unwrapBKey"];
                       
                       // json[@"email"] == nil] && [json[@"errno"] isEqual:@(INVALID_TIMESTAMP) && json[@"skipCaseError"] == @NO
                       //    if (options.keys) {
                       //       accountData.unwrapBKey = sjcl.codec.hex.fromBits(result.unwrapBKey);
                       //   }
                       completion(accountData);
                   } else {
                       DLog(@"%@\n%@", json, error);
                       completion(nil);
                   }
               }];
}

- (void)recoveryEmailStatusWithToken:(NSString *)sessionToken
                            callback:(void(^)(NSDictionary *, NSError*))callback {
    
    HawkCredentials *creds = [self _deriveHawkCredentials:sessionToken context:@"sessionToken" size:2 * 32];
    
    [self _sendAccountRequest:@"/recovery_email/status"
                       method:@"GET"
                      payload:nil
                  credentials:creds
                   completion:^(NSHTTPURLResponse *resp, id json, NSError *error) {
                           callback(json, error);
                   }];
    
}

- (void)accountKeysWithKeyFetchToken:(NSString *)keyFetchToken
                           unwrapKey:(NSString *)oldUnwrapBKey
                          completion:(void(^)(NSDictionary *))callback {
    NSParameterAssert(keyFetchToken && oldUnwrapBKey);
    
    HawkCredentials *creds = [self _deriveHawkCredentials:keyFetchToken context:@"keyFetchToken" size:3 * 32];
    
    [self _sendAccountRequest:@"/account/keys"
                       method:@"GET"
                      payload:nil
                  credentials:creds
                   completion:^(NSHTTPURLResponse *resp, id json, NSError *error) {
                       if (error == nil && json != nil) {
                           NSString *bundle = json[@"bundle"];
                           NSDictionary *keys = [self _unbundleKeyFetchResponseWithKey:creds.bundleKey
                                                                                bundle:bundle];
                           
                           if (keys != nil) {
                               NSData *kA = keys[@"kA"];
                               NSData *wrapKB = keys[@"wrapKB"];
                               NSData *kB = [CreateDataWithHexString(oldUnwrapBKey) dataXORdWithData:wrapKB];
                               
                               callback(@{@"kB": [kB hexadecimalString],
                                          @"kA": [kA hexadecimalString]});
                               return;
                           }
                       }
                       callback(nil);
                   }];
}

- (void)accountDevicesWithToken:(NSString *)sessionToken
                       callback:(void(^)(NSDictionary *))callback {
    
    HawkCredentials *creds = [self _deriveHawkCredentials:sessionToken
                                                  context:@"sessionToken"
                                                     size:2 * 32];
    
    [self _sendAccountRequest:@"/account/devices"
                       method:@"GET"
                      payload:nil
                  credentials:creds
                   completion:^(NSHTTPURLResponse *resp, id json, NSError *error) {
                       callback(error == nil ? json : nil);
                   }];

}

- (void)accountStatusUserId:(NSString *)uid callback:(void(^)(NSDictionary *))callback {
    NSString *path = [NSString stringWithFormat:@"/account/status?uid=%@", uid];
    [self _sendAccountRequest:path
                       method:@"GET"
                      payload:nil
                  credentials:nil
                   completion:^(NSHTTPURLResponse *resp, id json, NSError *error) {
                       callback(json);
                   }];
}

- (void)certificateSignWithToken:(NSString *)sessionToken
                       publicKey:(NSDictionary *)publicKey
                        duration:(NSInteger)seconds
                        callback:(void(^)(NSDictionary *, NSError *))callback {
    
    NSDictionary *data = @{@"publicKey":publicKey, @"duration":@(seconds)};
    HawkCredentials *creds = [self _deriveHawkCredentials:sessionToken context:@"sessionToken" size:2 * 32];
    [self _sendAccountRequest:@"/certificate/sign"
                       method:@"POST"
                      payload:data
                  credentials:creds
                   completion:^(NSHTTPURLResponse *resp, NSDictionary *json, NSError *error) {
                       callback(json, error);
                   }];
}

#pragma mark - Credentials setup

- (NSData *)kwName:(NSString *)name {
    return [[kFXNamespace stringByAppendingString:name] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)_kweName:(NSString *)name email:(NSString *)email {
    return [[NSString stringWithFormat:@"%@%@:%@", kFXNamespace, name, email]
            dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSDictionary *)_setupEmail:(NSString *)emailInput password:(NSString *)password {
    
    
    NSData *email = [self _kweName:@"quickStretch" email:emailInput];
    NSData *quickStretchedPW = PBKDF2_HMAC_SHA256([password dataUsingEncoding:NSUTF8StringEncoding],
                                                  email,
                                                  PBKDF2_ROUNDS,
                                                  STRETCHED_PASS_LENGTH_BYTES);
    
    NSData *salt = CreateDataWithHexString(@"00");
    NSData *authPW = HKDF_SHA256(quickStretchedPW, [self kwName:@"authPW"], salt, 32);
    NSData *unwrapBKey = HKDF_SHA256(quickStretchedPW, [self kwName:@"unwrapBkey"], salt, 32);
    
    return @{@"authPW":[authPW hexadecimalString],
             @"unwrapBKey":[unwrapBKey hexadecimalString]};
}

- (NSDictionary *)_unbundleKeyFetchResponseWithKey:(NSString *)key bundle:(NSString *)bundle {
    NSData *bitBundle = CreateDataWithHexString(bundle);
    
    NSData *ciphertext = [bitBundle subdataWithRange:NSMakeRange(0, 64)];
    NSData *expectedHmac = [bitBundle subdataWithRange:NSMakeRange(bitBundle.length-32, 32)];
    
    NSDictionary *keys = [self _deriveBundleKeys:key info:@"account/keys"];
    NSData *xorKey = keys[@"xorKey"];
    NSData *hmacKey = keys[@"hmacKey"];
    
    // Security check
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, hmacKey.bytes, hmacKey.length, ciphertext.bytes, (CC_LONG)ciphertext.length, hmac);
    NSData *output = [NSData dataWithBytes:hmac length:CC_SHA256_DIGEST_LENGTH];
    if (![output isEqual:expectedHmac]) {
        ELog(@"Bad HMac")
        return nil;
    }
    
    NSData *keyAWrapB = [ciphertext dataXORdWithData:xorKey];
    return @{@"kA":[keyAWrapB subdataWithRange:NSMakeRange(0, 32)],
             @"wrapKB":[keyAWrapB subdataWithRange:NSMakeRange(32, keyAWrapB.length - 32)]};
}

- (NSDictionary *)_deriveBundleKeys:(NSString *)key info:(NSString *)keyInfo {
    NSData *bitKeyInfo = [self kwName:keyInfo];
    NSData *keyMaterial = HKDF_SHA256(CreateDataWithHexString(key), bitKeyInfo, [NSData data], 3 * 32);
    return @{@"hmacKey":[keyMaterial subdataWithRange:NSMakeRange(0, 32)],
             @"xorKey":[keyMaterial subdataWithRange:NSMakeRange(32, keyMaterial.length - 32)]};
}


#pragma mark - Hawk Stuff


- (HawkCredentials *)_deriveHawkCredentials:(NSString *)tokenHex context:(NSString *)context size:(int)outSize  {
    NSString *info = [NSString stringWithFormat:@"%@%@", kFXNamespace, context];
    if (outSize == 0) {
        outSize = 3*32;
    }
    
    NSData *hkdfOut = HKDF_SHA256(CreateDataWithHexString(tokenHex),
                                  [info dataUsingEncoding:NSUTF8StringEncoding],
                                  [NSData data], outSize);
    NSData *hawkId = [hkdfOut subdataWithRange:NSMakeRange(0, 32)];
    NSData *authKey = [hkdfOut subdataWithRange:NSMakeRange(32, 32)];
    
    HawkCredentials *hawkCreds = [[HawkCredentials alloc] initWithHawkId:[hawkId hexadecimalString]
                                           withKey:authKey
                                     withAlgorithm:CryptoAlgorithmSHA256];
    if (outSize >= 3*32) {
        NSData *bundleKey = [hkdfOut subdataWithRange:NSMakeRange(64, 32)];
        hawkCreds.bundleKey = [bundleKey hexadecimalString];
    }
    return hawkCreds;
}

- (void)_sendAccountRequest:(NSString *)path
                     method:(NSString *)method
                    payload:(NSDictionary *)json
                credentials:(HawkCredentials *)creds
                 completion:(void (^)(NSHTTPURLResponse *, id, NSError *))completion {
    
    NSString *url = [NSString stringWithFormat:@"%@%@", kFXAccountsServerDefault, path];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:kFXConnectionTimeout];
    request.HTTPMethod = method;
    if (json != nil) {
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:json
                                                           options:0
                                                             error:NULL];
    }
    [self sendHawkRequest:request credentials:creds completion:completion];
}

- (void)sendHawkRequest:(NSMutableURLRequest *)req
            credentials:(HawkCredentials *)creds
             completion:(void(^)(NSHTTPURLResponse *, id, NSError *))completion {
    NSParameterAssert(req);
    
    NSString *contentType = [req valueForHTTPHeaderField:@"Content-Type"];
    if (contentType == nil || contentType.length == 0) {
        contentType = @"application/json";
        [req addValue:contentType forHTTPHeaderField:@"Content-Type"];
    }
    if (![req valueForHTTPHeaderField:@"Accept"]) {
        [req addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    }
    
    if (creds != nil) {
        HawkAuth *auth = [[HawkAuth alloc] init];
        auth.credentials = creds;
        
        auth.method = req.HTTPMethod;
        auth.payload = [req HTTPBody];
        auth.contentType = contentType;
        
        if ([[req.URL scheme] isEqualToString:@"https"]) {
            auth.port = @443;
        } else if ([[req.URL scheme] isEqualToString:@"http"]) {
            auth.port = @80;
        } else {
            auth.port = [req.URL port];
        }
        auth.host = [req.URL host];
        if ([[req.URL query] length]) {
            auth.requestUri = [NSString stringWithFormat:@"%@?%@",
                               [req.URL path], [req.URL query]];
        } else {
            auth.requestUri = [req.URL path];
        }
        auth.nonce = RandomString(6);
        auth.timestamp = [NSDate dateWithTimeIntervalSinceNow:[_localTimeOffsetSec doubleValue]];
        
        NSString *authorizationHeader = [[auth requestHeader] substringFromIndex:15];
        [req addValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
    }
    
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:_queue
                           completionHandler:^(NSURLResponse *resp, NSData *body, NSError *error){
                               NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
                               NSDictionary *json = nil;
                               //Workaround, because PUT gets a timestamp response and auth errors a '0'
                               if ([body length] > 1 && ![[req HTTPMethod] isEqualToString:@"PUT"]) {
                                   json = [NSJSONSerialization JSONObjectWithData:body options:0 error:&error];
                               }
                               
                               if (error != nil) {
                                   ELog(error);
                                   if (json != nil && json[@"errno"]){
                                       ELog(json);
                                       NSInteger code = [json[@"errno"] integerValue];
                                       error = [NSError errorWithDomain:@"com.mozilla.identity" code:code userInfo:json];
                                       
                                       // Let's try this
                                       if (code == INVALID_TIMESTAMP) {
                                           NSTimeInterval serverTime = [json[@"serverTime"] doubleValue];
                                           NSTimeInterval offset = serverTime - [[NSDate date] timeIntervalSince1970];
                                           _localTimeOffsetSec = @(offset);
                                           DLog(@"Resetting local time offset to: %.2f s", offset);
                                           // TODO retry
                                       }
                                   } else if (body != nil) {// in case of a json error
                                       DLog(@"Body %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
                                   }
                               }
                               if (completion) {
                                   completion(http, json, error);
                               }
                           }];
}

@end

NSString * RandomString(NSUInteger length) {
    // urlsafe alphabet
    static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:length];
    for (NSUInteger i=0; i < length; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    
    return randomString;
}

NSData * CreateDataWithHexString(NSString *inputString) {
    NSUInteger inLength = [inputString length];
    
    unichar *inCharacters = alloca(sizeof(unichar) * inLength);
    [inputString getCharacters:inCharacters range:NSMakeRange(0, inLength)];
    
    UInt8 *outBytes = malloc(sizeof(UInt8) * ((inLength / 2) + 1));
    
    NSInteger i, o = 0;
    UInt8 outByte = 0;
    for (i = 0; i < inLength; i++) {
        UInt8 c = inCharacters[i];
        SInt8 value = -1;
        
        if      (c >= '0' && c <= '9') value =      (c - '0');
        else if (c >= 'A' && c <= 'F') value = 10 + (c - 'A');
        else if (c >= 'a' && c <= 'f') value = 10 + (c - 'a');
        
        if (value >= 0) {
            if (i % 2 == 1) {
                outBytes[o++] = (outByte << 4) | value;
                outByte = 0;
            } else {
                outByte = value;
            }
            
        } else {
            if (o != 0) break;
        }
    }
    
    return [[NSData alloc] initWithBytesNoCopy:outBytes length:o freeWhenDone:YES];
}

// http://www.opensource.apple.com/source/OpenSSL/OpenSSL-12/openssl/crypto/evp/p5_crpt2.c
NSData * PBKDF2_HMAC_SHA256(NSData *data,NSData *salt, int iter, int keylen) {
    
    unsigned char digtmp[CC_SHA256_DIGEST_LENGTH], *p, *buffer, itmp[4];
    NSInteger cplen, j, k, tkeylen;
    unsigned long i = 1;
    CCHmacContext hctx;
    tkeylen = keylen;
    
    buffer = calloc(keylen, sizeof(unsigned char));
    p = buffer;
    
    while(tkeylen) {
        if(tkeylen > CC_SHA256_DIGEST_LENGTH) cplen = CC_SHA256_DIGEST_LENGTH;
        else cplen = tkeylen;
        
        /* We are unlikely to ever use more than 256 blocks (5120 bits!)
         * but just in case...
         */
        itmp[0] = (unsigned char)((i >> 24) & 0xff);
        itmp[1] = (unsigned char)((i >> 16) & 0xff);
        itmp[2] = (unsigned char)((i >> 8) & 0xff);
        itmp[3] = (unsigned char)(i & 0xff);
        
        CCHmacInit(&hctx, kCCHmacAlgSHA256, data.bytes, data.length);
        CCHmacUpdate(&hctx, salt.bytes, salt.length);
        CCHmacUpdate(&hctx, itmp, 4);
        CCHmacFinal(&hctx, digtmp);
        memcpy(p, digtmp, cplen);
        
        for(j = 1; j < iter; j++) {
            CCHmac(kCCHmacAlgSHA256, data.bytes, data.length,
                   digtmp, CC_SHA256_DIGEST_LENGTH, digtmp);
            for(k = 0; k < cplen; k++) p[k] ^= digtmp[k];
        }
        
        tkeylen-= cplen;
        i++;
        p+= cplen;
    }
    
    return [NSData dataWithBytesNoCopy:buffer length:keylen];
}

NSData * HKDF_SHA256(NSData *seed, NSData *info, NSData *salt, int outputSize) {
    char prk[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA256, [salt bytes], [salt length], [seed bytes], [seed length], prk);
    
    int             iterations = (int)ceil((double)outputSize/(double)CC_SHA256_DIGEST_LENGTH);
    NSData          *mixin = [NSData data];
    NSMutableData   *results = [NSMutableData data];
    
    for (int i=0; i<iterations; i++) {
        CCHmacContext ctx;
        CCHmacInit(&ctx, kCCHmacAlgSHA256, prk, CC_SHA256_DIGEST_LENGTH);
        CCHmacUpdate(&ctx, [mixin bytes], [mixin length]);
        if (info != nil) {
            CCHmacUpdate(&ctx, [info bytes], [info length]);
        }
        
        unsigned char c = i+1;
        CCHmacUpdate(&ctx, &c, 1);
        
        unsigned char T[CC_SHA256_DIGEST_LENGTH];
        memset(T, 0, CC_SHA256_DIGEST_LENGTH);
        CCHmacFinal(&ctx, T);
        NSData *stepResult = [NSData dataWithBytes:T length:sizeof(T)];
        [results appendData:stepResult];
        mixin = [stepResult copy];
    }
    
    return [NSData dataWithData:results];
}
