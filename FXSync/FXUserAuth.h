//
//  FXUserAuth.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 22.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

#import "FXAccountClient.h"

/*! 
 * Extends the fxaccounts client with logic to
 * handle the syncstorage specific stuff like aquiring tokens etc
 * https://docs.services.mozilla.com/token/apis.html
 * https://docs.services.mozilla.com/sync/storageformat5.html 
 */
@interface FXUserAuth : FXAccountClient

@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *password;


- (instancetype)initEmail:(NSString *)email password:(NSString *)pass;
- (void)requestSyncInfo:(void(^)(NSDictionary *))callback;

@end
