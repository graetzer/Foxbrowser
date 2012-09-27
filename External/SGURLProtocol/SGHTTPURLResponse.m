//
//  SGHTTPURLResponse.m
//  SGURLProtocol
//
//  Created by Simon Grätzer on 26.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGHTTPURLResponse.h"
#import "SGURLProtocol.h"

@implementation NSHTTPURLResponse (SGHTTPConnectionAdditions)

+ (NSHTTPURLResponse *)responseWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message
{
    return [[SGHTTPURLResponse alloc] initWithURL:URL HTTPMessage:message];
}

@end

@implementation SGHTTPURLResponse

- (id)initWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message
{
    _headerFields = (__bridge NSDictionary *)CFHTTPMessageCopyAllHeaderFields(message);
    
    NSArray *input = [[_headerFields objectForKey:@"Content-Type"] componentsSeparatedByString:@";"];
    NSString *MIMEType = @"text/html";
    if (input.count >= 1) {
        MIMEType = [input objectAtIndex:0];
    }
    
    NSInteger contentLength = [[_headerFields objectForKey:@"Content-Length"] integerValue];
    
    NSString *encoding = @"UTF-8";
    if (input.count >= 2) {
        encoding = [input objectAtIndex:1];
        encoding = [encoding stringByReplacingOccurrencesOfString:@"charset=" withString:@""];
    }
    
    if (self = [super initWithURL:URL MIMEType:MIMEType expectedContentLength:contentLength textEncodingName:encoding])
    {
        _statusCode = CFHTTPMessageGetResponseStatusCode(message);
        DLog(@"Status code: %i", _statusCode);
        DLog(@"Response headers: %@", _headerFields);
    }
    return self;
}

- (NSDictionary *)allHeaderFields { return _headerFields;  }

- (NSInteger)statusCode { return _statusCode; }

@end
