//
//  NSData+Ext.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 17.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Ext)
/*! Returns hexadecimal string of NSData. Empty string if data is empty. */
- (NSString *)hexadecimalString;

/*! BigInteger base 10 decimal string */
- (NSString *)decimalString;
- (NSData *)dataXORdWithData:(NSData *)data;

@end
