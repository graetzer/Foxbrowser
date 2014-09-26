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
    FXSyncStore *store = [FXSyncStore sharedInstance];
    
    // TODO load the info collection instead
    
    NSArray *collections = @[kFXTabsCollectionKey, kFXBookmarksCollectionKey];
    for (NSString *cName in collections) {
        NSTimeInterval lastModified = [store lastModifiedForCollection:cName];
        [self _downloadChanges:cName modified:lastModified offset:nil limit:NSIntegerMax];
    }
    
    NSTimeInterval lastModified = [store lastModifiedForCollection:kFXHistoryCollectionKey];
    [self _downloadChanges:kFXHistoryCollectionKey modified:lastModified offset:nil limit:2000];
}

- (void)_downloadChanges:(NSString *)cName
                modified:(NSTimeInterval)modified
                  offset:(NSString *)offset
                   limit:(NSInteger) limit {
    
    NSString *url = [NSString stringWithFormat:@"/storage/%@?newer=%.2f&full=1&limit=500", cName, modified];
    if (offset != nil) {
        url = [url stringByAppendingFormat:@"&offset=%@", offset];
    }
    [self _sendRequest:url
                method:@"GET"
               payload:nil
            completion:^(NSHTTPURLResponse *resp, id json, NSError *err){
                
                FXSyncStore *store = [FXSyncStore sharedInstance];
                NSDictionary *keyBundle = [self _keysForCollection:cName];
                NSArray *arr = json;
                NSUInteger count = 0;
                
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
                        [store saveItem:item];
                        count++;
                    }
                }
                
                NSString *nextOff = [resp allHeaderFields][kFXHeaderNextOffset];
                NSTimeInterval nextMod = [[resp allHeaderFields][kFXHeaderLastModified] doubleValue];
                NSInteger nextLimit = limit - count;
                
                if ([nextOff length] > 0 && nextLimit > 0) {
                    [self _downloadChanges:cName modified:modified offset:nextOff limit:nextLimit];
                } else if(nextMod > modified) {
                    [store setLastModifiedForCollection:cName modified:nextMod];
                }
            }];
}

- (void)_uploadChanges {
    
}

/*!
 * Contains information about the global storage version, should be 5
 * This should be queried to detect breaking updates
 */
- (void)_loadMetarecord:(void(^)(NSInteger))callback {
    [self _sendRequest:@"/storage/meta/global"
                method:@"GET"
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
               payload:nil
            completion:^(NSHTTPURLResponse *resp, id bso, NSError *err){
                if (bso != nil && resp.statusCode == 200) {
                    NSData *src = [self _decryptBSO:bso keyBundle:[self _keysForCollection:@"clients"]];
                    NSDictionary *payload;
                    @try {
                        payload = [NSJSONSerialization JSONObjectWithData:src
                                                                  options:0
                                                                    error:NULL];
                    } @catch (...) {
                        // Workaround for 622046 - Decryption failure on client record
                        // If decryptDataObject:mustVerify: throws an exception then we are using the incorrect
                        // sync key. We should handle this better, but for now we are simply going to ignore this
                        // exception so that the code below will upload a new client record. We will still fail
                        // later on when we try to decrypt a collection, but at least we will not leave incorrect
                        // client records on the server from which Home cannot recover.
                    }
                    if ([payload[@"id"] isEqualToString:myID]) {
                        DLog(@"found matching mobile client record");
                        return;
                    }
                }
                
                NSString *name = [[UIDevice currentDevice] name];
                if (!name.length) name = @"iOS Foxbrowser";
                
                NSDictionary *client = @{@"id" : myID, @"name":name, @"type" : @"mobile",
                                         @"version" : @"3.0", @"protocols": @[@"1.5"]};
                NSString *payload = [self _encryptJSON:client keyBundle:[self _keysForCollection:@"clients"]];
                NSDictionary *json = @{@"id":myID, @"payload" : payload};
                
                [self _sendRequest:url
                            method:@"PUT"
                           payload:json
                        completion:NULL];
            }];
}

#pragma mark - Crypto

- (void)_prepareKeys:(void(^)(void))callback {
    NSParameterAssert(callback);
    
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
                completion:^(NSHTTPURLResponse *resp, id json, NSError *err){
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
                    callback();
                }];
    } else if (callback) {
        callback();
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

- (NSString *)_encryptJSON:(id)json keyBundle:(NSDictionary *)bundle {
    NSData *plaintext = [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
    if (!plaintext) return nil;
    
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
             payload:(NSDictionary *)json
          completion:(void (^)(NSHTTPURLResponse *resp, id, NSError *))completion {
    
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
        // For some reason a genius at mozilla decided that even a GET request without body content needs to
        // have a hash for the body in it's hawk auth, but of course just on the sync service and nowhere else
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
