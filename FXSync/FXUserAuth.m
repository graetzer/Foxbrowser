//
//  FXUserAuth.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 22.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXUserAuth.h"

#import "NSString+Base64.h"
#import "NSData+Base64.h"
#import "NSData+Ext.h"

NSString *const  kFXPublicKeyTag = @"org.graetzer.fxsync.publickey";
NSString *const  kFXPrivateKeyTag  = @"org.graetzer.fxsync.privatekey";

//24*60*60*1000; not sure, doc says milliseconds and max an hour; node-fx-sync uses this
NSUInteger kFXCertDurationSeconds = 24*60*60*1000;// a day
// 3600 * 24 * 365;// certs last a year
NSString *const kFXSyncAuthUrl = @"https://token.services.mozilla.com";

// Private functions
static NSData* getPublicKeyExp(NSData *pk);
static NSData* getPublicKeyMod(NSData *pk);

@implementation FXUserAuth {
    // My keys
    SecKeyRef privateKeyRef;
    NSString *_cert;// BrowserID cert
}

- (void)dealloc {
    if (privateKeyRef != NULL) {
        CFRelease(privateKeyRef);
    }
}

/*!
 Get the users keys
 
 return {
 token: token,
 keys: this.keys,
 credentials: {
 sessionToken: user.creds.sessionToken,
 keyPair: user._keyPair
 }
 }
 */
- (void)signInFetchKeysEmail:(NSString *)email
                    password:(NSString *)pass
                  completion:(void(^)(BOOL))completion {
    NSParameterAssert(email && pass && completion != nil);
    
    [self signInEmail:email password:pass completion:^(NSDictionary *creds, NSError *err) {
        _accountCreds = creds;
        NSString *keyFetchToken = _accountCreds[@"keyFetchToken"];
        NSString *unwrapBKey = _accountCreds[@"unwrapBKey"];
        
        if (_accountCreds != nil
            && [keyFetchToken length] > 0
            && [unwrapBKey length] > 0) {
            
            [self accountKeysWithKeyFetchToken:keyFetchToken
                                     unwrapKey:unwrapBKey
                                    completion:^(NSDictionary *keys) {
                                        _accountKeys = keys;
                                        completion(_accountKeys != nil);
                                    }];
        } else {
            completion(NO);
        }
    }];
}

- (void)requestSyncInfo:(void(^)(NSDictionary *, NSError *))callback {
    NSParameterAssert(callback && _accountCreds);
    
    NSString *sessionToken = _accountCreds[@"sessionToken"];
    //[self recoveryEmailStatusWithToken:sessionToken callback:^(NSDictionary *status)
    NSNumber *verified = _accountCreds[@"verified"];
    if ([sessionToken length] && [verified boolValue]) {
        
        // Query the public and private key, create if necessary
        NSData* keyData = [self _getPublicKeyBits];
        if (keyData == nil || [keyData length] == 0) {
            [self _generateKeyPair];
            keyData = [self _getPublicKeyBits];
        } else {// We will need the private key later on
            [self _queryPrivateKeyRef];
        }
        if (keyData == nil || privateKeyRef == NULL) {
            NSString *msg = NSLocalizedStringFromTable(@"Cannot Load Private Key From Keychain",
                                                       @"FXSync", @"cannot load private key from keychain");
            callback(nil, [NSError errorWithDomain:@"org.graetzer.auth"
                                              code:-151
                                          userInfo:@{NSLocalizedDescriptionKey:msg}]);
            return;
        }
        
        // http://en.wikipedia.org/wiki/Abstract_Syntax_Notation_One#Example_encoded_in_DER
        const char *buffer = keyData.bytes;
        NSData* modulus;
        NSData* exponent;
        // Check for correct ASN.1 DER start
        if (buffer && buffer[0] == 0x30 && buffer[1] == keyData.length - 2) {
            if (buffer[2] == 0x02) {// Check for first int number,
                // supposed to be the modulus
                NSUInteger length = buffer[3];
                modulus = [keyData subdataWithRange:NSMakeRange(4, length)];
                
                NSUInteger expOffset = 4+length;
                if (buffer[expOffset] == 0x02) {// Check for seconds integer
                    length = buffer[expOffset + 1];
                    exponent = [keyData subdataWithRange:NSMakeRange(expOffset+2, length)];
                }
            }
        }
        
        if (exponent != nil && modulus != nil) {
            NSDictionary *public = @{@"algorithm":@"RS",
                                     @"n":[modulus decimalString],
                                     @"e":[exponent decimalString]};
            [self _requestTokenWithKey:public
                              callback:callback];
        }
    }
}

- (void)_requestTokenWithKey:(NSDictionary *)publicKey
                    callback:(void(^)(NSDictionary *, NSError *))callback {
    
    NSString *sessionToken = _accountCreds[@"sessionToken"];
    [self certificateSignWithToken:sessionToken
                         publicKey:publicKey
                          duration:kFXCertDurationSeconds
                          callback:^(NSDictionary *json, NSError *error) {
                              // In this case the json probably just contains the error
                              if (error != nil) {
                                  callback(json, error);
                                  return ;
                              }
                              
                              _cert = json[@"cert"];
                              NSString *assert = [self _assertionWithAudience:kFXSyncAuthUrl
                                                                     duration:kFXCertDurationSeconds];
                              NSString *clientState = [self _computeClientState];
                              
                              [self _authTokenWithBrowserIDAssert:assert
                                                      clientState:clientState
                                                       completion:^(NSDictionary *token, NSError *error) {
                                                           if (error == nil && token != nil) {
                                                               _syncInfo  = @{@"token":token,
                                                                              @"syncKey":_accountKeys[@"kB"],
                                                                              @"sessionToken":sessionToken};
                                                               
                                                           }
                                                           ELog(error);
                                                           callback(_syncInfo, error);
                                                       }];
                          }];
}

/* Auth with the token server
 *
 * @param assertion Serialized BrowserID assertion
 * @param clientState hex(first16Bytes(sha256(kBbytes)))
 *
 * @return Promise result resolves to:
 * {
 * key: sync 1.5 Hawk key
 * id: sync 1.5 Hawk id
 * api_endpoint: sync 1.5 storage server uri
 * }
 */
- (void)_authTokenWithBrowserIDAssert:(NSString *)assertion
                          clientState:(NSString *)state
                           completion:(void(^)(NSDictionary *, NSError *))completion {
    NSParameterAssert(assertion && state && completion);
    
    NSString *url = [NSString stringWithFormat:@"%@/1.0/sync/1.5", kFXSyncAuthUrl];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:kFXConnectionTimeout];
    
    req.allHTTPHeaderFields = @{@"Authorization":[NSString stringWithFormat:@"BrowserID %@", assertion],
                                @"X-Client-State":state,
                                @"Accept":@"application/json"};

    [self sendHawkRequest:req
              credentials:nil
               completion:^(NSHTTPURLResponse *resp, id json, NSError *error) {
                   if (error != nil && json != nil && resp != nil) {
                       error = [NSError errorWithDomain:@"com.mozilla.token"
                                                   code:resp.statusCode
                                               userInfo:json];
                   }
                   completion(json, error);
               }];
}

- (NSString *)_computeClientState {
    uint8_t hashBytes[CC_SHA256_DIGEST_LENGTH];
    NSData *inData = CreateDataWithHexString(_accountKeys[@"kB"]);
    if (!CC_SHA256([inData bytes], (CC_LONG)[inData length], hashBytes)) {
        return nil;
    }
    NSData *hash = [NSData dataWithBytes:hashBytes
                                  length:CC_SHA256_DIGEST_LENGTH];
    return [[hash subdataWithRange:NSMakeRange(0, 16)] hexadecimalString];
}

- (NSString *)_assertionWithAudience:(NSString *)audience duration:(NSInteger)duration {
    
    int64_t now = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000);
    NSDictionary *header = @{@"alg":@"RS64"};
    NSDictionary *payload = @{@"aud": audience,
                             @"iss": kFXAccountsServerDefault,
                             @"exp": @(now + duration)};
    
    
    NSString *algBytes = [[NSJSONSerialization dataWithJSONObject:header options:0 error:NULL]
                        base64URLEncodedString];
    NSString *jsonBytes = [[NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL]
                           base64URLEncodedString];
    NSString *plain = [NSString stringWithFormat:@"%@.%@", algBytes, jsonBytes];
    
    // Create hash
    NSData *plainData = [plain dataUsingEncoding:NSUTF8StringEncoding];
    size_t signedHashBytesSize = SecKeyGetBlockSize(privateKeyRef);
    uint8_t signedHashBytes[signedHashBytesSize];
    
    uint8_t hashBytes[CC_SHA256_DIGEST_LENGTH];
    if (!CC_SHA256([plainData bytes], (CC_LONG)[plainData length], hashBytes)) {
        return nil;
    }
    
    SecKeyRawSign(privateKeyRef,
                  kSecPaddingPKCS1SHA256,
                  hashBytes,
                  CC_SHA256_DIGEST_LENGTH,
                  signedHashBytes,
                  &signedHashBytesSize);
    
    NSData* signedHash = [NSData dataWithBytes:signedHashBytes
                                        length:(NSUInteger)signedHashBytesSize];
    NSString *sHash = [signedHash base64URLEncodedString];
    return [NSString stringWithFormat:@"%@~%@.%@", _cert, plain, sHash];
}

#pragma mark - Handling keys
- (void)_generateKeyPair {
    [self _deleteKeys];
    //NSUInteger keySize = 1024;//128 bytes
    NSUInteger keySize = 512;//64 bytes
    
    OSStatus sanityCheck = noErr;
    if (!(keySize == 512 || keySize == 1024 || keySize == 2048)) {
        DLog(@"%lu is an invalid and unsupported key size.", (unsigned long)keySize);
    }
    // First delete current keys.
    [self _deleteKeys];
    
    // Set the private key dictionary.
     NSMutableDictionary * privateKeyAttr = [NSMutableDictionary dictionaryWithCapacity:5];
    privateKeyAttr[(__bridge id)kSecAttrIsPermanent] = @YES;
    privateKeyAttr[(__bridge id)kSecAttrApplicationTag] = [kFXPrivateKeyTag
                                                           dataUsingEncoding:NSUTF8StringEncoding];
    
    // Set the public key dictionary.
    NSMutableDictionary * publicKeyAttr = [NSMutableDictionary dictionaryWithCapacity:8];
    publicKeyAttr[(__bridge id)kSecAttrIsPermanent] = @YES;
    publicKeyAttr[(__bridge id)kSecAttrApplicationTag] = [kFXPublicKeyTag
                                                          dataUsingEncoding:NSUTF8StringEncoding];
    
    // Set attributes to top level dictionary.
    NSMutableDictionary * keyPairAttr = [NSMutableDictionary dictionaryWithCapacity:5];
    keyPairAttr[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    keyPairAttr[(__bridge id)kSecAttrKeySizeInBits] = @(keySize);
    keyPairAttr[(__bridge id)kSecPrivateKeyAttrs] = privateKeyAttr;
    keyPairAttr[(__bridge id)kSecPublicKeyAttrs] = publicKeyAttr;
    
    // SecKeyGeneratePair returns the SecKeyRefs just for educational purposes.
    SecKeyRef publicKeyRef;
    sanityCheck = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &publicKeyRef, &privateKeyRef);
    
    if (!(sanityCheck == noErr && publicKeyRef != NULL && privateKeyRef != NULL)) {
        ELog(@"Something really bad went wrong with generating the key pair.")
    }
    CFRelease(publicKeyRef);
}

- (NSMutableDictionary *)_keyQuery {
    NSMutableDictionary * query = [[NSMutableDictionary alloc] init];
    query[(__bridge id)kSecClass] = (__bridge id)(kSecClassKey);
    query[(__bridge id)kSecAttrKeyType] = (__bridge id)(kSecAttrKeyTypeRSA);
    query[(__bridge id)kSecAttrApplicationTag] = kFXPublicKeyTag;
    return query;
}

- (NSData *)_getPublicKeyBits {
    NSMutableDictionary * query = [self _keyQuery];
    query[(__bridge id)kSecReturnData] = @YES;
    
    CFTypeRef result;// Get the key bits.
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query,
                            &result) == errSecSuccess) {
        return CFBridgingRelease(result);
    }
    return nil;
}

- (void)_queryPrivateKeyRef {
    NSMutableDictionary *query = [self _keyQuery];
    query[(__bridge id)kSecReturnRef] = @YES;
    query[(__bridge id)kSecAttrApplicationTag] = kFXPrivateKeyTag;
    
    CFTypeRef result;// Get the key bits.
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess) {
        privateKeyRef = (SecKeyRef)result;
    }
}

- (void)_deleteKeys {
    NSMutableDictionary * queryKey = [self _keyQuery];
    int res = SecItemDelete((__bridge CFDictionaryRef)queryKey);
    if (res != noErr && res != errSecItemNotFound) {
        ELog(@"Something really bad went wrong.")
    }
    
    queryKey[(__bridge id)kSecAttrApplicationTag] = kFXPrivateKeyTag;
    res = SecItemDelete((__bridge CFDictionaryRef)queryKey);
    if (res != noErr && res != errSecItemNotFound) {
        ELog(@"Something really bad went wrong.")
    }
}

@end
