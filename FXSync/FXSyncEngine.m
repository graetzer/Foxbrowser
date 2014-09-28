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
#import "NSData+Base64.h"
#import "Reachability.h"
#import "HawkCredentials.h"

#include <libkern/OSAtomic.h>

NSString *const kFXSyncEngineException = @"org.graetzer.fxsync.engine";
NSString *const kFXLocalTimeOffsetKey = @"org.graetzer.fxsync.localtimeoffset";

NSString *const kFXHeaderLastModified = @"X-Last-Modified";
NSString *const kFXHeaderTimestamp = @"X-Weave-Timestamp";
NSString *const kFXHeaderNextOffset = @"X-Weave-Next-Offset";
NSString *const kFXHeaderAlert = @"X-Weave-Alert";

NSString *const kFXHeaderIfModifiedSince = @"X-If-Modified-Since";
NSString *const kFXHeaderIfUnmodifiedSince = @"X-If-Unmodified-Since";

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
    
    int32_t _networkOps;
}
@dynamic localTimeOffsetSec, syncRunning;

- (instancetype)init {
    if (self = [super init]) {
        _reachability = [Reachability reachabilityForInternetConnection];
    }
    return self;
}

- (void)startSync {    
    if (![self isSyncRunning]
        && _userAuth != nil
        && [_reachability isReachable]) {
        
        if (_userAuth.syncInfo == nil) {
            [self _requestSyncInfo];
        } else if (_keyBundle != nil && _collectionKeys != nil) {
            [self _prepareKeys];
        } else {
            [self _performSync];
        }
    }
}

- (void)_requestSyncInfo {
    OSAtomicIncrement32(&_networkOps);
    [_userAuth requestSyncInfo:^(NSDictionary *syncInfo) {
        DLog(@"Sync Token %@", syncInfo);
        if (syncInfo[@"token"] != nil) {
            NSString *key = syncInfo[@"token"][@"key"];
            _credentials = [[HawkCredentials alloc] initWithHawkId:syncInfo[@"token"][@"id"]
                                                           withKey:[key dataUsingEncoding:NSUTF8StringEncoding]
                                                     withAlgorithm:CryptoAlgorithmSHA256];
            
            [self _prepareKeys];
        }
        OSAtomicDecrement32(&_networkOps);
    }];
}

- (void)_performSync {
    if (_keyBundle != nil && _collectionKeys != nil) {
        OSAtomicIncrement32(&_networkOps);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self _downloadChanges];
            [self _uploadChanges];
            OSAtomicDecrement32(&_networkOps);
        });
    }
}

- (void)_downloadChanges {
    FXSyncStore *store = [FXSyncStore sharedInstance];
    
    // TODO load the info collection instead
    
    NSDictionary *cols = [FXSyncEngine collectionNames];
    for (NSString *cName in cols) {
        NSTimeInterval newer = [store syncTimeForCollection:cName];
        NSNumber *max = cols[cName];
        [self _downloadChanges:cName
                     newerThan:newer
               unmodifiedSince:0
                        offset:nil
                       maximum:[max integerValue]];
    }
}

- (void)_downloadChanges:(NSString *)cName
                newerThan:(NSTimeInterval)newer
           unmodifiedSince:(NSTimeInterval)unmodified
                  offset:(NSString *)offset
                   maximum:(NSInteger)limit {
    
    // Always sort by newest, we need all objects anyway expect with history items.
    NSString *url = [NSString stringWithFormat:@"/storage/%@?newer=%.2f&sort=newest&full=1&limit=250",
                     cName, newer];
    NSDictionary *headers = nil;
    if (offset != nil) {
        url = [url stringByAppendingFormat:@"&offset=%@", offset];
        headers = @{kFXHeaderIfUnmodifiedSince : @(unmodified)};
    }
    
    [self _sendRequest:url
                method:@"GET"
               headers:headers
               payload:nil
            completion:^(NSHTTPURLResponse *resp, id json, NSError *err){
                
                if (resp.statusCode == 200
                           && [json isKindOfClass:[NSArray class]]) {
                    
                    FXSyncStore *store = [FXSyncStore sharedInstance];
                    NSDictionary *keyBundle = [self _keysForCollection:cName];
                    NSUInteger count = 0;// Successfull inserts
                    for (NSDictionary *bso in json) {
                        NSData *payload = [self _decryptBSO:bso keyBundle:keyBundle];
                        if (payload != nil) {
                            FXSyncItem *item = [[FXSyncItem alloc] init];
                            item.syncId = bso[@"id"];
                            item.modified = [bso[@"modified"] doubleValue];
                            item.sortindex = [bso[@"sortindex"] integerValue];
                            item.payload = payload;
                            item.collection = cName;
                            [store saveItem:item];
                            count++;
                            
                            DLog(@"Storing item: %@", [NSJSONSerialization JSONObjectWithData:payload
                                                                                      options:0 error:NULL]);
                        }
                    }
                    
                    NSString *nextOff = [resp allHeaderFields][kFXHeaderNextOffset];
                    NSTimeInterval nextMod = [[resp allHeaderFields][kFXHeaderLastModified] doubleValue];
                    NSInteger nextLimit = limit - count;
                    
                    if ([nextOff length] > 0 && nextLimit > 0) {
                        // Guard this query with nexMod, so we do not miss an insert
                        // by a different client
                        [self _downloadChanges:cName
                                     newerThan:newer
                               unmodifiedSince:nextMod
                                        offset:nextOff
                                       maximum:nextLimit];
                    } else if(nextMod > newer) {
                        // Check (nextMod > newer) so that we make sure
                        // that this is monotone increasing
                        [store setSyncTime:nextMod forCollection:cName];
                    }
                } else if (resp.statusCode == 412 && [offset length] > 0) {
                    DLog(@"Concurrent modification, retrying loading");
                    // Plus 500, because we are at least one recursion in
                    [self _downloadChanges:cName newerThan:newer
                           unmodifiedSince:0 offset:nil maximum:limit+500];
                }
            }];
}

- (void)_uploadChanges {
    FXSyncStore *store = [FXSyncStore sharedInstance];
    NSDictionary *cols = [FXSyncEngine collectionNames];
    for (NSString *cName in cols) {
        NSTimeInterval newer = [store syncTimeForCollection:cName];
        NSArray *uploads = [store changedItemsForCollection:cName];
        
        for (FXSyncItem *item in uploads) {
            // We use the upload time for the entire collection,
            // rather than item.modified
            [self _uploadItem:item unmodifiedSince:newer];
        }
    }
}

- (void)_uploadItem:(FXSyncItem *)item unmodifiedSince:(NSTimeInterval)unmodified  {
    NSString *url = [NSString stringWithFormat:@"/storage/%@/%@", item.collection, item.syncId];
    
    NSString *payload = [self _encryptPayload:item.payload keyBundle:[self _keysForCollection:@"clients"]];
    NSDictionary *json = @{@"id":item.syncId,
                           @"sortindex":@(item.sortindex),
                           @"payload" : payload};
    
    [self _sendRequest:url
                method:@"PUT"
               headers:@{kFXHeaderIfUnmodifiedSince : @(unmodified)}
               payload:json
            completion:^(NSHTTPURLResponse *resp, id json, NSError *err){
                if (resp.statusCode == 200) {
                    NSTimeInterval modified = [resp.allHeaderFields[kFXHeaderLastModified] doubleValue];
                    if (modified > unmodified) {
                        item.modified = modified;
                        [[FXSyncStore sharedInstance] saveItem:item];
                    }
                } else if (resp.statusCode == 412) {
                    // Just overwrite the local changes for now
                    [self _sendRequest:url
                                method:@"GET"
                               headers:nil
                               payload:nil
                            completion:^(NSHTTPURLResponse *resp, id bso, NSError *err) {
                                if (resp.statusCode == 200
                                    && [bso isKindOfClass:[NSDictionary class]]) {
                                    
                                    NSDictionary *keyBundle = [self _keysForCollection:item.collection];
                                    NSData *payload = [self _decryptBSO:bso keyBundle:keyBundle];
                                    if (payload != nil) {
                                        FXSyncItem *item = [[FXSyncItem alloc] init];
                                        item.syncId = bso[@"id"];
                                        item.modified = [bso[@"modified"] doubleValue];
                                        item.sortindex = [bso[@"sortindex"] integerValue];
                                        item.payload = payload;
                                        item.collection = item.collection;
                                        [[FXSyncStore sharedInstance] saveItem:item];
                                    }
                                }
                            }];
                }
            }];
}

/*!
 * Contains information about the global storage version, should be 5
 * This should be queried to detect breaking updates
 */
- (void)_loadMetarecord:(void(^)(NSInteger))callback {
    [self _sendRequest:@"/storage/meta/global"
                method:@"GET"
               headers:nil
               payload:nil
            completion:^(NSHTTPURLResponse *resp, id json, NSError *err){
                if (json != nil && resp.statusCode == 200) {
                    NSData *src = [json[@"payload"] dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:src
                                                                            options:0
                                                                              error:NULL];
                    NSInteger storageVersion = [payload[@"storageVersion"] integerValue];
                    callback(storageVersion);
                }
            }];
}

- (void)_updateClientRecord {
    NSUUID *uuid = [UIDevice currentDevice].identifierForVendor;
    NSString *myID = [uuid UUIDString];
    NSString *url = [NSString stringWithFormat:@"/storage/clients/%@", myID];
    
    [self _sendRequest:url
                method:@"GET"
               headers:nil
               payload:nil
            completion:^(NSHTTPURLResponse *resp, id bso, NSError *err){
                if (bso != nil && resp.statusCode == 200) {
                    NSData *src = [self _decryptBSO:bso keyBundle:[self _keysForCollection:@"clients"]];
                    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:src
                                                                  options:0
                                                                    error:NULL];
                    if ([payload[@"id"] isEqualToString:myID]) {
                        DLog(@"found matching mobile client record");
                        return;
                    }
                }
                
                NSString *name = [[UIDevice currentDevice] name];
                if (!name.length) name = @"iOS Foxbrowser";
                
                NSDictionary *client = @{@"id" : myID, @"name":name, @"type" : @"mobile",
                                         @"version" : @"3.0", @"protocols": @[@"1.5"]};
                NSData *plaintext = [NSJSONSerialization dataWithJSONObject:client options:0 error:NULL];
                if (plaintext != nil) {
                    NSString *payload = [self _encryptPayload:plaintext keyBundle:[self _keysForCollection:@"clients"]];
                    NSDictionary *json = @{@"id":myID, @"payload" : payload};
                    
                    [self _sendRequest:url
                                method:@"PUT"
                               headers:nil
                               payload:json
                            completion:NULL];
                }
            }];
}

#pragma mark - Crypto

- (void)_prepareKeys {
    
    // _deriveKeys
    NSString *syncKey = _userAuth.syncInfo[@"syncKey"];
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
        [self _sendRequest:@"/storage/crypto/keys"
                    method:@"GET" headers:nil payload:nil
                completion:^(NSHTTPURLResponse *resp, id json, NSError *err) {
                    
                    if(json) {
                        NSData *payload = [self _decryptBSO:json keyBundle:_keyBundle];
                        NSDictionary *decrypted = [NSJSONSerialization JSONObjectWithData:payload
                                                                                  options:NSJSONReadingMutableContainers
                                                                                    error:NULL];
                        
                        NSMutableDictionary *cols = decrypted[@"collections"];
                        cols[@"default"] = decrypted[@"default"];
                        
                        NSMutableDictionary *keys = [NSMutableDictionary dictionaryWithCapacity:[cols count]];
                        for (NSString *key in cols) {
                            NSArray *arr = cols[key];
                            if ([arr count] == 2) {
                                keys[key] =  @{@"encKey" : [arr[0] base64DecodedData],
                                               @"hmacKey": [arr[1] base64DecodedData]};
                            }
                        }
                        _collectionKeys = keys;
                    }
                    [self _performSync];
                }];
    } else {
        [self _performSync];
    }
}

- (NSDictionary *)_keysForCollection:(NSString *)cName {
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
            decrypted = [NSData dataWithBytesNoCopy:buffer length: dataOutMoved freeWhenDone: YES];
        } else {
            free(buffer);
        }
    }

    return decrypted;
}

- (NSString *)_encryptPayload:(NSData *)plaintext keyBundle:(NSDictionary *)bundle {

    NSData *encKey = bundle[@"encKey"];
    NSData *hmacKey = bundle[@"hmacKey"];
    // AES blocksize is always 128 bit
    NSData *IV = [RandomString(16) dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *ciphertext = nil;
    size_t bufferSize = [plaintext length];
    void *buffer = calloc(bufferSize, sizeof(uint8_t));
    if (buffer != nil) {
        size_t dataOutMoved = 0;
        BOOL padding = YES;
        CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                              kCCAlgorithmAES,
                                              padding ? kCCOptionPKCS7Padding : 0,
                                              [encKey bytes],
                                              kCCKeySizeAES256,
                                              [IV bytes],
                                              [plaintext bytes],
                                              [plaintext length],
                                              buffer,
                                              bufferSize,
                                              &dataOutMoved);
        
        if (cryptStatus == kCCSuccess) {
            ciphertext = [NSData dataWithBytesNoCopy:buffer length: dataOutMoved freeWhenDone: YES];
        } else {
            free(buffer);
        }
    }
    
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, hmacKey.bytes, hmacKey.length, ciphertext.bytes, (CC_LONG)ciphertext.length, hmac);
    NSString *computedHMAC = [[NSData dataWithBytes:hmac length:CC_SHA256_DIGEST_LENGTH] hexadecimalString];
    
    NSDictionary *payload = @{@"IV" : [IV base64EncodedString],
                              @"hmac" : computedHMAC,
                              @"ciphertext" : [ciphertext base64EncodedString]};

    NSData *jsonPayload = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    return [[NSString alloc] initWithData:jsonPayload encoding:NSUTF8StringEncoding];
}


#pragma mark - Helper Methods


- (void)_sendRequest:(NSString *)path
              method:(NSString *)method
             headers:(NSDictionary *)headers
             payload:(NSDictionary *)json
          completion:(void (^)(NSHTTPURLResponse *resp, id, NSError *))completion {
    
    NSString *base = _userAuth.syncInfo[@"token"][@"api_endpoint"];
    NSString *url = [NSString stringWithFormat:@"%@%@", base, path];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:kFXConnectionTimeout];
    request.HTTPMethod = method;
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    if (json != nil) {
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:json
                                                           options:0
                                                             error:NULL];
    } else {
        // For some reason a genius at mozilla decided that even a GET request without body content needs to
        // have a hash for the body in it's hawk auth (but of course just on the sync service and nowhere else)
        request.HTTPBody = [NSData data];
    }
    OSAtomicIncrement32(&_networkOps);
    [_userAuth sendHawkRequest:request credentials:_credentials completion:^(NSHTTPURLResponse *resp, id json, NSError *err) {
        if (completion) {
            completion(resp, json, err);
        }
        OSAtomicDecrement32(&_networkOps);
    }];
}

/*! Handle Alerts, Backoff, timestamp + offset calculations */
- (void)_handleSpecialHeaders:(NSHTTPURLResponse *)headers {
    
}

+ (NSDictionary *)collectionNames {
    return @{kFXTabsCollectionKey : @(NSIntegerMax),
             kFXBookmarksCollectionKey : @(NSIntegerMax),
             kFXHistoryCollectionKey : @(2000)
             //kFXPasswordsCollectionKey : @(NSIntegerMax),
             //kFXFormsCollectionKey : @(NSIntegerMax)
             };
//    return @[kFXTabsCollectionKey, kFXBookmarksCollectionKey,
//             kFXHistoryCollectionKey, kFXPasswordsCollectionKey, kFXFormsCollectionKey];
}

- (void)setLocalTimeOffsetSec:(NSNumber *)localTimeOffsetSec {
    [[NSUserDefaults standardUserDefaults] setObject:localTimeOffsetSec
                                              forKey:kFXLocalTimeOffsetKey];
}

- (NSNumber *)localTimeOffsetSec {
    NSNumber *num = [[NSUserDefaults standardUserDefaults] objectForKey:kFXLocalTimeOffsetKey];
    return num != nil ? num : @0;
}

- (BOOL)isSyncRunning {
    return _networkOps > 0;
}

@end
