//
//  SGHTTPURLResponse.h
//  SGURLProtocol
//
//  Created by Simon Grätzer on 26.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>

@interface SGHTTPURLResponse : NSHTTPURLResponse
{
@private
    NSInteger       _statusCode;
    __strong NSDictionary    *_headerFields;
}

- (id)initWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message;
@end

@interface NSHTTPURLResponse (SGHTTPConnectionAdditions)

+ (NSHTTPURLResponse *)responseWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message;

@end
