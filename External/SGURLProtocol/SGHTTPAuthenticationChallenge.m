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
                sender:(id <NSURLAuthenticationChallengeSender>)sender {
    NSParameterAssert(response != nil);
    NSParameterAssert(sender != nil);
    
    // Try to create an authentication object from the response
    _HTTPAuthentication = CFHTTPAuthenticationCreateFromResponse(NULL, response);
    if (!_HTTPAuthentication || !CFHTTPAuthenticationIsValid(_HTTPAuthentication, NULL))
        return nil;
    
    if (!CFHTTPAuthenticationRequiresUserNameAndPassword(_HTTPAuthentication))
        return nil;
    
    // Fail if we can't retrieve decent protection space info
    CFArrayRef authenticationDomains = CFHTTPAuthenticationCopyDomains(_HTTPAuthentication);
    NSURL *URL = [(__bridge NSArray *)authenticationDomains lastObject];
    CFRelease(authenticationDomains);
    
    if (!URL || ![URL host])
        return nil;
    
    // Fail for an unsupported authentication method
    CFStringRef authMethod = CFHTTPAuthenticationCopyMethod(_HTTPAuthentication);
    NSString *authenticationMethod;
    if ([(__bridge NSString *)authMethod isEqualToString:(NSString *)kCFHTTPAuthenticationSchemeBasic]) {
        authenticationMethod = NSURLAuthenticationMethodHTTPBasic;
    } else if ([(__bridge NSString *)authMethod isEqualToString:(NSString *)kCFHTTPAuthenticationSchemeDigest]) {
        authenticationMethod = NSURLAuthenticationMethodHTTPDigest;
    } else {
        CFRelease(authMethod);
        return nil;
    }
    CFRelease(authMethod);
    
    // Initialise
    CFStringRef realm = CFHTTPAuthenticationCopyRealm(_HTTPAuthentication);
    
    NSInteger port = 80;
    if ([URL port]) {
        port = [URL.port integerValue];
    } else {
        NSString *scheme = [URL.scheme lowercaseString];
        if ([scheme isEqualToString:@"http"])
            port = 80;
        else if ([scheme isEqualToString:@"https"])
            port = 443;
    }
    
    NSURLProtectionSpace *protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:[URL host]
                                                                                  port:port
                                                                              protocol:[URL scheme]
                                                                                 realm:CFBridgingRelease(realm)
                                                                  authenticationMethod:authenticationMethod];
    
    NSURLCredential *credential = [[NSURLCredentialStorage sharedCredentialStorage]
                                   defaultCredentialForProtectionSpace:protectionSpace];
    
    NSError *error = [NSError errorWithDomain:@"org.graetzer.http"
                                         code:401
                                     userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Failed to authenticate", nil)}];
    self = [super initWithProtectionSpace:protectionSpace
                      proposedCredential:credential
                    previousFailureCount:failureCount
                         failureResponse:URLResponse
                                   error:error
                                  sender:sender];
    
    return self;
}

- (void)dealloc {
    CFRelease(_HTTPAuthentication);
}

- (CFHTTPAuthenticationRef)CFHTTPAuthentication { return _HTTPAuthentication; }

@end