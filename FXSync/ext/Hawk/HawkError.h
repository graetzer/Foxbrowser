//
//  HawkError.h
//  Hawk
//
//  Created by Jesse Stuart on 8/8/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, HawkErrorReason) {
    HawkErrorReply,
    HawkErrorInvalidPayloadHash,
    HawkErrorInvalidMac,
    HawkErrorBewitExpired,
    HawkErrorTimestampSkew,
    HawkErrorInvalidBewitMethod,
    HawkErrorUnknownId,
    HawkErrorMalformedBewit
};

@interface HawkError : NSObject

@property (nonatomic) HawkErrorReason errorReason;

+ (HawkError *)hawkErrorWithReason:(HawkErrorReason)reason;

+ (NSString *)messageForReason:(HawkErrorReason)reason;

@end
