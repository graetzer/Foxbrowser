//
//  FXAccountClient.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 14.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>

@class HawkCredentials;

/*! Mirrors the Firefox Accounts API as in
 * https://github.com/mozilla/fxa-js-client/blob/master/client/FxAccountClient.js
 */
@interface FXAccountClient : NSObject

// Interval in seconds
@property (nonatomic, assign) NSTimeInterval localTimeOffsetSec;

/**
 * @method signIn
 * @param {String} email Email input
 * @param {String} password Password input
 * @return {Promise} A promise that will be fulfilled with JSON `xhr.responseText` of the request
 * Always with keys = true
 */
- (void)signInEmail:(NSString *)username
           password:(NSString *)password
         completion:(void(^)(NSDictionary *, NSError *))completion;

/**
 * @method recoveryEmailStatus
 * @param {String} sessionToken sessionToken obtained from signIn
 * @return {Promise} A promise that will be fulfilled with JSON `xhr.responseText` of the request
 */
- (void)recoveryEmailStatusWithToken:(NSString *)sessionToken
                            callback:(void(^)(NSDictionary *, NSError*))callback;

/**
 * Get the base16 bundle of encrypted kA|wrapKb.
 *
 * @method accountKeys
 * @param {String} keyFetchToken
 * @param {String} oldUnwrapBKey
 * @return {Promise} A promise that will be fulfilled with JSON of {kA, kB} of the key bundle
 */
- (void)accountKeysWithKeyFetchToken:(NSString *)keyFetchToken
                           unwrapKey:(NSString *)oldUnwrapBKey
                          completion:(void(^)(NSDictionary *))callback;

/**
 * Gets the collection of devices currently authenticated and syncing for the user.
 *
 * @method accountDevices
 * @param {String} sessionToken User session token
 * @return {Promise} A promise that will be fulfilled with JSON `xhr.responseText` of the request
 */
- (void)accountDevicesWithToken:(NSString *)sessionToken
                       callback:(void(^)(NSDictionary *))callback;

/**
 * Gets the status of an account
 *
 * @method accountStatus
 * @param {String} uid User account id
 * @return {Promise} A promise that will be fulfilled with JSON `xhr.responseText` of the request
 */
- (void)accountStatusUserId:(NSString *)uid callback:(void(^)(NSDictionary *))callback;

/**
 * Sign a BrowserID public key
 *
 * @method certificateSign
 * @param {String} sessionToken User session token
 * @param {Object} publicKey The key to sign
 * @param {int} duration Time interval from now when the certificate will expire in seconds
 * @return {Promise} A promise that will be fulfilled with JSON `xhr.responseText` of the request
 */
- (void)certificateSignWithToken:(NSString *)sessionToken
                       publicKey:(NSDictionary *)publicKey
                        duration:(NSInteger)seconds
                        callback:(void(^)(NSDictionary *, NSError *))callback;

/*! Appends the name to a certain string, used with HKDF for info */
- (NSData *)kwName:(NSString *)name;

/*! Helper method to send an hawk request, content type defaults the to application/json */
- (void)sendHawkRequest:(NSMutableURLRequest *)req
            credentials:(HawkCredentials *)creds
             completion:(void(^)(NSHTTPURLResponse *, id, NSError *))completion;
@end

/*! identity.mozilla.com/picl/v1/ */
FOUNDATION_EXPORT NSString *const kFXNamespace;
/*! Default endpoint for accounts server */
FOUNDATION_EXPORT NSString *const kFXAccountsServerDefault;
/*! Default timeout 120 seconds*/
FOUNDATION_EXPORT NSTimeInterval const kFXConnectionTimeout;

/*! Should generate an urlsafe random string http://en.wikipedia.org/wiki/Base64#RFC_4648 */
NSString * RandomString(NSUInteger length);
NSData * CreateDataWithHexString(NSString *inputString);
NSData * PBKDF2_HMAC_SHA256(NSData *data,NSData *salt, int iter, int keylen);
NSData * HKDF_SHA256(NSData *seed, NSData *info, NSData *salt, int outputSize);