//
//  NSURL+Compare.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 08.08.12.
//  Copyright (c) 2012 Cybercon GmbH. All rights reserved.
//

#import "NSURL+Compare.h"

@implementation NSURL (Compare)
- (BOOL)isEqualExceptFragment:(NSURL *)other; {
    return (!(self.scheme && other.scheme) || [self.scheme isEqualToString:other.scheme])
    && (!(self.user && other.user) || [self.user isEqualToString:other.user])
    && (!(self.password && other.password) || [self.password isEqualToString:other.password])
    && (!(self.host && other.host) || [self.host isEqualToString:other.host])
    && (!(self.port && other.port) || [self.port isEqual:other.port])
    && (!(self.path && other.path) || [self.path isEqualToString:other.path])
    && (!(self.query && other.query) || [self.query isEqualToString:other.query]);
}
@end
