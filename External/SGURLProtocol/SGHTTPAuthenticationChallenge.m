//
//  SGHTTPAuthenticationChallenge.m
//  SGURLProtocol
//
//  Created by Simon Grätzer on 26.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGHTTPAuthenticationChallenge.h"

@implementation SGHTTPAuthenticationChallenge

/*  Returns nil if the ref is not suitable
 */
- (id)initWithResponse:(CFHTTPMessageRef)response
  previousFailureCount:(NSInteger)failureCount
       failureResponse:(NSHTTPURLResponse *)URLResponse
                sender:(id <NSURLAuthenticationChallengeSender>)sender
{
    NSParameterAssert(response);
    
    // Try to create an authentication object from the response
    _HTTPAuthentication = CFHTTPAuthenticationCreateFromResponse(NULL, response);
    if (![self CFHTTPAuthentication])
    {
        return nil;
    }
    
    // NSURLAuthenticationChallenge only handles user and password
    if (!CFHTTPAuthenticationIsValid([self CFHTTPAuthentication], NULL))
    {
        return nil;
    }
    
    if (!CFHTTPAuthenticationRequiresUserNameAndPassword([self CFHTTPAuthentication]))
    {
        return nil;
    }
    
    
    // Fail if we can't retrieve decent protection space info
    CFArrayRef authenticationDomains = CFHTTPAuthenticationCopyDomains([self CFHTTPAuthentication]);
    NSURL *URL = [(__bridge NSArray *)authenticationDomains lastObject];
    CFRelease(authenticationDomains);
    
    if (!URL || ![URL host])
    {
        return nil;
    }
    
    // Fail for an unsupported authentication method
    CFStringRef authMethod = CFHTTPAuthenticationCopyMethod([self CFHTTPAuthentication]);
    NSString *authenticationMethod;
    if ([(__bridge NSString *)authMethod isEqualToString:(NSString *)kCFHTTPAuthenticationSchemeBasic])
    {
        authenticationMethod = NSURLAuthenticationMethodHTTPBasic;
    }
    else if ([(__bridge NSString *)authMethod isEqualToString:(NSString *)kCFHTTPAuthenticationSchemeDigest])
    {
        authenticationMethod = NSURLAuthenticationMethodHTTPDigest;
    }
    else
    {
        CFRelease(authMethod);
        return nil;
    }
    CFRelease(authMethod);
    
    
    // Initialise
    CFStringRef realm = CFHTTPAuthenticationCopyRealm([self CFHTTPAuthentication]);
    
    
    NSInteger port = 80;
    
    if ([URL port]) {
        port = [[URL port] integerValue];
    } else {
        NSString *scheme = [[URL scheme] lowercaseString];
        if ([scheme isEqualToString:@"http"]) {
            port = 80;
        } else if ([scheme isEqualToString:@"https"]) {
            port = 443;
        }
    }
    
    
    NSURLProtectionSpace *protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:[URL host]
                                                                                  port:port
                                                                              protocol:[URL scheme]
                                                                                 realm:(__bridge NSString *)realm
                                                                  authenticationMethod:authenticationMethod];
    CFRelease(realm);
    
    NSURLCredential *credential = [[NSURLCredentialStorage sharedCredentialStorage]
                                   defaultCredentialForProtectionSpace:protectionSpace];
    
    NSError *error = [NSError errorWithDomain:@"org.graetzer.http.auth" code:401 userInfo:nil];
    self = [self initWithProtectionSpace:protectionSpace
                      proposedCredential:credential
                    previousFailureCount:failureCount
                         failureResponse:URLResponse
                                   error:error
                                  sender:sender];
    
    
    // Tidy up
    return self;
}

- (void)dealloc
{
    CFRelease(_HTTPAuthentication);
}

- (CFHTTPAuthenticationRef)CFHTTPAuthentication { return _HTTPAuthentication; }

@end