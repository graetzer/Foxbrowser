//
//  FXSyncEngine.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 21.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSyncEngine.h"
#import "FXSyncStore.h"
#import "FXUserAuth.h"
#import "FXSyncItem.h"
#import "NSData+Ext.h"
#import "NSString+Base64.h"
#import "Reachability.h"
#import "HawkCredentials.h"

NSString *const kFXSyncEngineException = @"org.graetzer.fxsync.engine";
NSString *const kFXLocalTimeOffsetKey = @"org.graetzer.fxsync.localtimeoffset";

NSString *const kFXHeaderLastModified = @"X-Last-Modified";
NSString *const kFXHeaderTimestamp = @"X-Weave-Timestamp";
NSString *const kFXHeaderNextOffset = @"X-Weave-Next-Offset";
NSString *const kFXHeaderAlert = @"X-Weave-Alert";


NSString *const kFXTabsCollectionKey = @"tabs";
NSString *const kFXBookmarksCollectionKey = @"bookmarks";
NSString *const kFXHistoryCollectionKey = @"history";
NSString *const kFXPasswordsCollectionKey = @"passwords";
NSString *const kFXPrefsCollectionKey = @"prefs";
NSString *const kFXFormsCollectionKey = @"forms";

@implementation FXSyncEngine  {
    HawkCredentials *_credentials;
    NSDictionary *_keyBundle;
    NSDictionary *_collectionKeys;
}
@dynamic localTimeOffsetSec;

+ (instancetype)sharedInstance {
    static FXSyncEngine *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FXSyncEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _reachability = [Reachability reachabilityForInternetConnection];
        _userAuth = [[FXUserAuth alloc] initEmail:@"simon@graetzer.org"
                                       password:@"foochic923"];
    }
    return self;
}

- (void)startSync {    
    if (!_syncRunning && [_reachability isReachable]) {
        _syncRunning = YES;
        
//        if (_syncToken != nil && ) {
//            <#statements#>
//        }
        
        [self _requestSyncInfo];
    }
}

- (void)cancelSync {
    _syncRunning = NO;
}

- (void)_requestSyncInfo {
    [_userAuth requestSyncInfo:^(NSDictionary *syncInfo) {
        DLog(@"Sync Token %@", syncInfo);
        if (syncInfo != nil) {
            _syncInfo = syncInfo;
            
            NSString *key = _syncInfo[@"token"][@"key"];
            _credentials = [[HawkCredentials alloc] initWithHawkId:_syncInfo[@"token"][@"id"]
                                                           withKey:[key dataUsingEncoding:NSUTF8StringEncoding]
                                                     withAlgorithm:CryptoAlgorithmSHA256];
            
            [self _prepareKeys:^{
                [self _performSync];
            }];
        }
    }];
}

- (void)_performSync {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self _downloadChanges];
        [self _uploadChanges];
        [self cancelSync];
    });
}

- (void)_downloadChanges {
    NSArray *collections = [FXSyncEngine collectionNames];
    FXSyncStore *store = [FXSyncStore sharedInstance];
    
    [self _downloadChanges:kFXTabsCollectionKey modified:0 offset:nil];
//    for (NSString *cName in collections) {
//        NSTimeInterval lastModified = [store lastModifiedForCollection:cName];
//        
//        [self _downloadChanges:cName modified:lastModified offset:nil];
//    }
}

- (void)_downloadChanges:(NSString *)cName modified:(NSTimeInterval)modified offset:(NSString *)offset {
    NSString *url = [NSString stringWithFormat:@"/storage/%@?newer=%.2f&full=1&limit=500", cName, modified];
    if (offset != nil) {
        url = [url stringByAppendingFormat:@"&offset=%@", offset];
    }
    
    [self _sendRequest:url
                method:@"GET"
               payload:nil
            completion:^(NSDictionary *headers, id json, NSError *err){
                
                NSDictionary *keyBundle = [self _collectionKeyForCollection:cName];
                NSArray *arr = json;
                for (NSDictionary *bso in arr) {
                    NSData *payload = [self _decryptBSO:bso keyBundle:keyBundle];
                    if (payload != nil) {
                        FXSyncItem *item = [[FXSyncItem alloc] init];
                        item.syncId = bso[@"id"];
                        item.modified = [bso[@"modified"] doubleValue];
                        item.sortindex = [bso[@"sortindex"] integerValue];
                        item.payload = payload;
                        
                        DLog(@"Storing item: %@", [NSJSONSerialization JSONObjectWithData:payload
                                                                                  options:0 error:NULL]);
                        
                        item.collection = cName;
                        [[FXSyncStore sharedInstance] saveItem:item];
                    }
                }
                
//                NSTimeInterval nextMod = [headers[kFXHeaderLastModified] doubleValue];
                NSString *nextOff = headers[kFXHeaderNextOffset];
                if (nextOff != nil) {
                    [self _downloadChanges:cName modified:modified offset:nil];
                }
            }];
}

- (void)_uploadChanges {
    
}

#pragma mark - Crypto

- (void)_prepareKeys:(void(^)(void))callback {
    
    // _deriveKeys
    NSString *syncKey = _syncInfo[@"syncKey"];
    if (syncKey != nil && _keyBundle == nil) {
        NSData *bundle = HKDF_SHA256(CreateDataWithHexString(syncKey),
                                     [_userAuth kwName:@"oldsync"],
                                     [NSData data], 2 * 32);
        
        _keyBundle = @{@"encKey":[bundle subdataWithRange:NSMakeRange(0, 32)],
                       @"hmacKey":[bundle subdataWithRange:NSMakeRange(32, 32)]};
        DLog(@"Key Bundle: %@", _keyBundle);
    }
    
    // _fetchCollectionKeys
    if (_collectionKeys == nil && _keyBundle != nil) {
        [self _sendRequest:@"/storage/crypto/keys" method:@"GET" payload:nil
                completion:^(NSDictionary *headers, id json, NSError *err){
                    if(json) {
                        NSData *payload = [self _decryptBSO:json keyBundle:_keyBundle];
                        NSDictionary *decrypted = [NSJSONSerialization JSONObjectWithData:payload options:0 error:NULL];
                        NSString *encKey = decrypted[@"default"][0];
                        NSString *hmacKey = decrypted[@"default"][1];
                            
                        if (encKey && hmacKey) {
                            DLog(@"Collection Keys: %@", decrypted);
                            _collectionKeys = @{@"default" : @{
                                                        @"encKey" : [encKey base64DecodedData],
                                                        @"hmacKey":[hmacKey base64DecodedData]}
                                                };
                        }
                    }
                    callback();
                }];
    } else if (callback) {
        callback();
    }
}

- (NSDictionary *)_collectionKeyForCollection:(NSString *)cName {
    return _collectionKeys[cName] != nil ? _collectionKeys[cName] : _collectionKeys[@"default"];
}

- (NSData *)_decryptBSO:(NSDictionary *)bso keyBundle:(NSDictionary *)bundle {
    NSParameterAssert(bundle);
    if (bso[@"payload"] == nil) {
        @throw [NSException exceptionWithName:kFXSyncEngineException
                                       reason:@"BSO has no payload: nothing to decrypt?"
                                     userInfo:bso];
    }
    NSData *src = [bso[@"payload"] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:src
                                                            options:0
                                                              error:NULL];
    if (payload[@"ciphertext"] == nil) {
        @throw [NSException exceptionWithName:kFXSyncEngineException
                                       reason:@"BSO has no ciphertext: nothing to decrypt?"
                                     userInfo:bso];
    }
    NSData *encKey = bundle[@"encKey"];
    NSData *hmacKey = bundle[@"hmacKey"];
    NSData *ciphertext = [payload[@"ciphertext"] dataUsingEncoding:NSUTF8StringEncoding];
    
    // Security check
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, hmacKey.bytes, hmacKey.length, ciphertext.bytes, (CC_LONG)ciphertext.length, hmac);
    NSString *computedHMAC = [[NSData dataWithBytes:hmac length:CC_SHA256_DIGEST_LENGTH] hexadecimalString];
    
    if (![computedHMAC isEqualToString:payload[@"hmac"]]) {
        @throw [NSException exceptionWithName:kFXSyncEngineException
                                       reason:@"Incorrect HMAC"
                                     userInfo:bso];
    }
    
    NSData *IV = [payload[@"IV"] base64DecodedData];
    ciphertext = [payload[@"ciphertext"] base64DecodedData];
    
    NSData *decrypted = nil;
    size_t bufferSize = [ciphertext length];
    void *buffer = calloc(bufferSize, sizeof(uint8_t));
    if (buffer != nil) {
        size_t dataOutMoved = 0;
        BOOL padding = YES;
        CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                              kCCAlgorithmAES,
                                              padding ? kCCOptionPKCS7Padding : 0,
                                              [encKey bytes],
                                              kCCKeySizeAES256,
                                              [IV bytes],
                                              [ciphertext bytes],
                                              [ciphertext length],
                                              buffer,
                                              bufferSize,
                                              &dataOutMoved);
        
        if (cryptStatus == kCCSuccess) {
            decrypted = [NSData dataWithBytesNoCopy: buffer length: dataOutMoved freeWhenDone: YES];
        } else {
            free(buffer);
        }
    }
    
//    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:decrypted options:0 error:NULL];
//    if (![result[@"id"] isEqual:bso[@"id"]]) {
//        @throw [NSException exceptionWithName:kFXSyncEngineException
//                                       reason:@"Record id mismatch"
//                                     userInfo:result];
//    }

    return decrypted;
}


#pragma mark - Helper Methods


- (void)_sendRequest:(NSString *)path
              method:(NSString *)method
             payload:(NSDictionary *)json
          completion:(void (^)(NSDictionary *, id, NSError *))completion {
    
    NSString *base = _syncInfo[@"token"][@"api_endpoint"];
    NSString *url = [NSString stringWithFormat:@"%@%@", base, path];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:kFXConnectionTimeout];
    request.HTTPMethod = method;
    if (json != nil) {
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:json
                                                           options:0
                                                             error:NULL];
    } else {
        request.HTTPBody = [NSData data];
    }
    [_userAuth sendHawkRequest:request credentials:_credentials completion:completion];
}

+ (NSArray *)collectionNames {
    return @[kFXTabsCollectionKey, kFXBookmarksCollectionKey,
             kFXHistoryCollectionKey, kFXPasswordsCollectionKey, kFXFormsCollectionKey];
}

- (void)setLocalTimeOffsetSec:(NSNumber *)localTimeOffsetSec {
    [[NSUserDefaults standardUserDefaults] setObject:localTimeOffsetSec
                                              forKey:kFXLocalTimeOffsetKey];
}

- (NSNumber *)localTimeOffsetSec {
    NSNumber *num = [[NSUserDefaults standardUserDefaults] objectForKey:kFXLocalTimeOffsetKey];
    return num != nil ? num : @0;
}

@end
