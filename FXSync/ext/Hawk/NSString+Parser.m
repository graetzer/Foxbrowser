//
//  NSString+Parser.m
//  Hawk
//
//  Created by Jesse Stuart on 8/7/13.
//  Copyright (c) 2013 Tent.is, LLC. All rights reserved.
//  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
//

#import "NSString+Parser.h"

@implementation NSString (Parser)

- (NSUInteger *)firstIndexOf:(NSString *)substring
{
    for (int i=0; i<self.length; i++) {
        if ([[[self substringFromIndex:i] substringToIndex:substring.length] isEqualToString:substring]) {
            return (NSUInteger *)[[NSNumber numberWithInt:i] integerValue];
        }
    }

    return nil;
}

@end
