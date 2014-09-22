//
//  NSString+Trim.m
//  Hawk
//
//  Created by Jesse Stuart on 10/17/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import "NSString+Trim.h"

@implementation NSString (Trim)

- (NSString *)stringByTrimmingLeadingAndTrailingWhitespace {
    if ([self length] == 0) {
        return self;
    }

    NSError *error;
    NSRegularExpression *leadingWhiteSpaceRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*" options:NSRegularExpressionCaseInsensitive error:&error];


    NSRegularExpression *trailingWhiteSpaceRegex = [NSRegularExpression regularExpressionWithPattern:@"\\s*$" options:NSRegularExpressionCaseInsensitive error:&error];

    NSMutableString *tmp = [NSMutableString stringWithString:self];

    [leadingWhiteSpaceRegex replaceMatchesInString:tmp options:NSMatchingWithoutAnchoringBounds range:NSRangeFromString([NSString stringWithFormat:@"0,%d", [tmp length]]) withTemplate:@""];

    [trailingWhiteSpaceRegex replaceMatchesInString:tmp options:NSMatchingWithoutAnchoringBounds range:NSRangeFromString([NSString stringWithFormat:@"0,%d", [tmp length]]) withTemplate:@""];

    return [NSString stringWithString:tmp];
}

@end
