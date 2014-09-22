//
//  HawkError.m
//  Hawk
//
//  Created by Jesse Stuart on 8/8/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import "HawkError.h"

@implementation HawkError

+ (HawkError *)hawkErrorWithReason:(HawkErrorReason)reason
{
    HawkError *error = [[HawkError alloc] init];
    error.errorReason = reason;

    return error;
}

+ (NSString *)messageForReason:(HawkErrorReason)reason
{
    NSString *message;

    switch (reason) {
        case HawkErrorBewitExpired:
            message = @"bewit expired";
            break;

        case HawkErrorInvalidBewitMethod:
            message = @"bewit only allows HEAD and GET requests";
            break;

        case HawkErrorInvalidMac:
            message = @"invalid MAC";
            break;

        case HawkErrorInvalidPayloadHash:
            message = @"invalid payload hash";
            break;

        case HawkErrorReply:
            message = @"request nonce is being replayed";
            break;

        case HawkErrorTimestampSkew:
            message = @"timestamp skew too high";
            break;

        case HawkErrorUnknownId:
            message = @"unknown id";
            break;

        case HawkErrorMalformedBewit:
            message = @"bewit is malformed";
            break;
    }

    return message;
}

@end
