//
//  NSData+Ext.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 17.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "NSData+Ext.h"
#include "tommath.h"

@implementation NSData (Ext)
#pragma mark - String Conversion
- (NSString *)hexadecimalString {
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer) {
        return [NSString string];
    }
    
    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
    }
    
    return [NSString stringWithString:hexString];
}

- (NSString *)decimalString {
    mp_int m_value;
    mp_init_size(&m_value, (int)[self length]*8);
    mp_read_unsigned_bin(&m_value, [self bytes], (int)[self length]);
    
    // Make the string
    int radix = 10;
    int stringSize;
    mp_radix_size(&m_value, radix, &stringSize);
    char cString[stringSize];
    mp_toradix(&m_value, cString, radix);
    for (int i = 0; i < stringSize; ++i) {
        cString[i] = (char)tolower(cString[i]);
    }
    mp_clear(&m_value);
    
    return [[NSString alloc] initWithBytes:cString
                                    length:stringSize
                                  encoding:NSUTF8StringEncoding];
}

- (NSData *)dataXORdWithData:(NSData *)data {
    //TODO: #warning This needs to be thoroughly audited, I'm not sure I follow this correctly
    // From SO post http://stackoverflow.com/questions/11724527/xor-file-encryption-in-ios
    NSMutableData *result = [self mutableCopy];
    
    // Get pointer to data to obfuscate
    char *dataPtr = (char *)result.mutableBytes;
    
    // Get pointer to key data
    char *keyData = (char *)data.bytes;
    
    // Points to each char in sequence in the key
    char *keyPtr = keyData;
    int keyIndex = 0;
    
    // For each character in data, xor with current value in key
    for (int x = 0; x < self.length; x++) {
        // Replace current character in data with
        // current character xor'd with current key value.
        // Bump each pointer to the next character
        *dataPtr = *dataPtr ^ *keyPtr;
        dataPtr++;
        keyPtr++;
        
        // If at end of key data, reset count and
        // set key pointer back to start of key value
        if (++keyIndex == data.length)
        {
            keyIndex = 0;
            keyPtr = keyData;
        }
    }
    
    return result;
}

@end
