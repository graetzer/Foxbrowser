//
//  HawkCredentials.m
//  Hawk
//
//  Created by Jesse Stuart on 8/7/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import "HawkCredentials.h"

@implementation HawkCredentials

- (id)initWithHawkId:(NSString *)hawkId withKey:(NSData *)key withAlgorithm:(CryptoAlgorithm)algorithm
{
    self = [super init];

    self.hawkId = hawkId;
    self.key = key;
    self.algorithm = algorithm;

    return self;
}

@end
