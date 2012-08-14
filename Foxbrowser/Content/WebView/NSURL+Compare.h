//
//  NSURL+Compare.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 08.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (Compare)

- (BOOL)isEqualExceptFragment:(NSURL *)other;

@end
