//
//  HawkCredentials.h
//  Hawk
//
//  Created by Jesse Stuart on 8/7/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import <Foundation/Foundation.h>
#import "CryptoProxy.h"

@interface HawkCredentials : NSObject

@property (copy) NSString *hawkId;
@property (copy) NSData *key;
@property (nonatomic) CryptoAlgorithm algorithm;

// FXSync extension, just used internally
@property (copy) NSString *bundleKey;

- (id)initWithHawkId:(NSString *)hawkId withKey:(NSData *)key withAlgorithm:(CryptoAlgorithm)algorithm;

@end
