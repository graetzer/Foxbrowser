//
//  SGHTTPAuthenticationChallenge.h
//  SGURLProtocol
//
//  Created by Simon Grätzer on 26.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>

@interface SGHTTPAuthenticationChallenge : NSURLAuthenticationChallenge
{
    CFHTTPAuthenticationRef _HTTPAuthentication;
}

- (id)initWithResponse:(CFHTTPMessageRef)response
  previousFailureCount:(NSInteger)failureCount
       failureResponse:(NSHTTPURLResponse *)URLResponse
                sender:(id <NSURLAuthenticationChallengeSender>)sender;

- (CFHTTPAuthenticationRef)CFHTTPAuthentication;

@end
