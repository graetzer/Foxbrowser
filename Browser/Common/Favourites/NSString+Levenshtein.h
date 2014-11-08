//
//  NSString+Levenshtein.h
//  NextSearch
//
//  Created by Simon Grätzer on 07.04.14.
//  Copyright (c) 2014 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Levenshtein)

- (float)levenshteinDistance:(NSString *)comparisonString;

@end
