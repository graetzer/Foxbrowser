//
//  SGURLProtocol.m
//  SGProtocol
//
//  Created by Simon Grätzer on 25.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGHTTPURLProtocol.h"

static NSInteger RegisterCount = 0;
static NSLock* VariableLock;
static NSMutableArray *Requests;
static NSMutableArray *AuthDelegates;

typedef enum {
        SGIdentity = 0,
        SGGzip = 1,
        SGDeflate = 2
    } SGCompression;

@implementation SGHTTPURLProtocol {
    NSInputStream *_HTTPStream;
    CFHTTPMessageRef _HTTPMessage;
    
    NSInteger _authenticationAttempts;
    id<SGAuthDelegate> _authDelegate;
    
    NSMutableData *_buffer;
    SGCompression _compression;
}

+ (void)load {
    VariableLock = [[NSLock alloc] init];
    Requests = [[NSMutableArray alloc] initWithCapacity:10];
    AuthDelegates = [[NSMutableArray alloc] initWithCapacity:10];
}

+ (void)registerProtocol {
	[VariableLock lock];
	if (RegisterCount==0) {
        [NSURLProtocol registerClass:[self class]];
	}
	RegisterCount++;
	[VariableLock unlock];
}

+ (void)unregisterProtocol {
	[VariableLock lock];
	RegisterCount--;
	if (RegisterCount==0) {
		[NSURLProtocol unregisterClass:[self class]];
	}
	[VariableLock unlock];
}

+ (void)setAuthDelegate:(id<SGAuthDelegate>)delegate forRequest:(NSURLRequest *)request {
    [VariableLock lock];
	[AuthDelegates addObject:delegate];
    [Requests addObject:request];
	[VariableLock unlock];
}

+ (void)removeAuthDelegate:(id<SGAuthDelegate>)delegate {
    [VariableLock lock];
    
    NSUInteger index = NSNotFound;
    while ( (index = [AuthDelegates indexOfObject:delegate]) != NSNotFound) {
        [AuthDelegates removeObjectAtIndex:index];
        [Requests removeObjectAtIndex:index];
    };
	
	[VariableLock unlock];
}

+ (id<SGAuthDelegate>)authDelegateForRequest:(NSURLRequest *)request {
    [VariableLock lock];
    id<SGAuthDelegate> result;
	for (int i = 0; i < Requests.count; i++) {
        NSURLRequest *current = Requests[i];
        if ([current.URL isEqual:request.URL]) {
            result = AuthDelegates[i];
            [Requests removeObjectAtIndex:i];
            [AuthDelegates removeObjectAtIndex:i];
            break;
        }
    }
	[VariableLock unlock];
    return result;
}

#pragma mark - NSURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{
    NSString *scheme = [request.URL.scheme lowercaseString];
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    
    NSURL *url = request.URL;
	NSString *frag = url.fragment;
	if(frag.length > 0) { // map different fragments to same base file
        NSMutableURLRequest *mutable = [request mutableCopy];
        NSString *s = [url absoluteString];
        s  =[s substringToIndex:s.length - frag.length];// remove fragment
        mutable.URL = [NSURL URLWithString:s];
        return mutable;
    }
	return request;
}

- (id)initWithRequest:(NSURLRequest *)request
       cachedResponse:(NSCachedURLResponse *)cachedResponse
               client:(id<NSURLProtocolClient>)client {
    if (self = [super initWithRequest:request
                cachedResponse:cachedResponse
                        client:client]) {
        _compression = SGIdentity;
        _authenticationAttempts = -1;
        _authDelegate = [SGHTTPURLProtocol authDelegateForRequest:request];
    }
    return self;
}

- (void)dealloc {
    [self stopLoading];
    if (_HTTPMessage)
        CFRelease(_HTTPMessage);
    NSAssert(!_HTTPStream, @"Deallocating HTTP connection while stream still exists");
    NSAssert(!_authChallenge, @"HTTP connection deallocated mid-authentication");
}

- (void)startLoading {
    [self stopLoading];
    NSAssert(_HTTPStream == nil, @"HTTPStream is not nil, connection still ongoing");
    self.URLResponse = nil;
    
    _HTTPMessage = [self newMessageWithURLRequest:self.request];
    
    NSInputStream *bodyStream = self.request.HTTPBodyStream;
    CFReadStreamRef stream;
    if (bodyStream)
        stream = CFReadStreamCreateForStreamedHTTPRequest(NULL, _HTTPMessage, (__bridge CFReadStreamRef)bodyStream);
    else
        stream = CFReadStreamCreateForHTTPRequest(NULL, _HTTPMessage);
    
    if (stream == NULL) {
        ELog(@"Could not create stream");
        
        return;
    }
    
    CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanFalse);
    if([[self.request.URL.scheme lowercaseString] isEqualToString:@"https"]) {// TODO check against a list
        //Hey an https request
        CFMutableDictionaryRef pDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(pDict, kCFStreamSSLValidatesCertificateChain, kCFBooleanFalse);
        CFDictionarySetValue(pDict, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelSSLv3);
        CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings, pDict);
        CFRelease(pDict);
    }

    _HTTPStream = (NSInputStream *)CFBridgingRelease(stream);
    [_HTTPStream setDelegate:self];
    [_HTTPStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_HTTPStream open];
}

- (void)stopLoading {
    if (_HTTPStream && _HTTPStream.streamStatus != NSStreamStatusClosed)
        [_HTTPStream close];
        
    _HTTPStream = nil;
}

#pragma mark - CFStreamDelegate
- (void)stream:(NSInputStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    //NSParameterAssert(theStream == _HTTPStream);
    if (theStream != _HTTPStream) {
        DLog(@"Not my stream!");
        return;
    }
    
    // Handle the response as soon as it's available
    if (!self.URLResponse) {
        CFHTTPMessageRef response = (__bridge CFHTTPMessageRef)[theStream propertyForKey:(NSString *)kCFStreamPropertyHTTPResponseHeader];
        if (response && CFHTTPMessageIsHeaderComplete(response)) {
            // Construct a NSURLResponse object from the HTTP message
            NSURL *URL = [theStream propertyForKey:(NSString *)kCFStreamPropertyHTTPFinalURL];
            self.URLResponse = [NSHTTPURLResponse responseWithURL:URL HTTPMessage:response];
            
            if ([self.request HTTPShouldHandleCookies])
                [self handleCookiesWithURLResponse:self.URLResponse];
            
            NSUInteger code = [self.URLResponse statusCode];
            NSString *location = (self.URLResponse.allHeaderFields)[@"Location"];
            
            // If the response was an authentication failure, try to request fresh credentials.
            if (code == 401 || code == 407) {// The && statement is a workaround for servers who redirect with an 401 after an successful auth
                // Cancel any further loading and ask the delegate for authentication
                [self stopLoading];
                
                NSAssert(!self.authChallenge, @"Authentication challenge received while another is in progress");
                
                _authenticationAttempts++;
                self.authChallenge = [[SGHTTPAuthenticationChallenge alloc] initWithResponse:response
                                                                              previousFailureCount:_authenticationAttempts
                                                                                   failureResponse:self.URLResponse
                                                                                            sender:self];

                if (self.authChallenge) {
                    if (_authenticationAttempts == 0 && self.authChallenge.proposedCredential) {
                        [self useCredential:self.authChallenge.proposedCredential forAuthenticationChallenge:self.authChallenge];
                    } else {
                        if (_authDelegate) {
                            [_authDelegate URLProtocol:self didReceiveAuthenticationChallenge:self.authChallenge];
                        } else {
                            [self.client URLProtocol:self didReceiveAuthenticationChallenge:self.authChallenge];
                        }
                    }
                    return; // Stops the delegate being sent a response received message
                } else {
                    [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"org.graetzer.http" code:401 userInfo:nil]];
                }
            } else if (code == 301 ||code == 302 || code == 303) { // Workaround
                // Redirect with a new GET request, assume the server processed the request
                // http://en.wikipedia.org/wiki/HTTP_301 Handle 301 only if GET or HEAD
                // TODO: Maybe implement 301 differently.
                
                NSURL *nextURL = [NSURL URLWithString:location relativeToURL:URL];
                if (nextURL) {
                    DLog(@"Redirect to %@", location);
                    [self stopLoading];
                    
                    NSURLRequest *nextRequest = [NSURLRequest requestWithURL:nextURL
                                                                 cachePolicy:self.request.cachePolicy
                                                             timeoutInterval:self.request.timeoutInterval];
                    [self.client URLProtocol:self wasRedirectedToRequest:nextRequest redirectResponse:self.URLResponse];
                    return;
                }
            } else if (code == 307 || code == 308) { // Redirect but keep the parameters
                NSURL *nextURL = [NSURL URLWithString:location relativeToURL:URL];
                
                // If URL is valid, else just show the page
                if (nextURL) {
                    DLog(@"Redirect to %@", location);
                    [self stopLoading];
                    
                    NSMutableURLRequest *nextRequest = [self.request mutableCopy];
                    [nextRequest setURL:nextURL];
                    [self.client URLProtocol:self wasRedirectedToRequest:nextRequest redirectResponse:self.URLResponse];
                    return;
                }
            } else if (code == 304) { // Handle cached stuff
                NSCachedURLResponse *cached = self.cachedResponse;
                if (!cached)
                    cached = [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request];
                
                [self.client URLProtocol:self cachedResponseIsValid:cached];
                [self.client URLProtocol:self didLoadData:[cached data]];
                //actually no body expected, TODO: testing
                [self.client URLProtocolDidFinishLoading:self];
                return;
            }
            
            // So no redirect, no auth. Now we care about the body
            NSString *encoding = self.URLResponse.allHeaderFields[@"Content-Encoding"];
            if ([encoding isEqualToString:@"gzip"])
                _compression = SGGzip;
            else if ([encoding isEqualToString:@"deflate"])
                _compression = SGDeflate;
            else
                _compression = SGIdentity;
            
            if (!_buffer && _compression != SGIdentity) {
                long long capacity = self.URLResponse.expectedContentLength;
                if (capacity == NSURLResponseUnknownLength || capacity == 0)
                    capacity = 1024*1024;//10M buffer
                _buffer = [[NSMutableData alloc] initWithCapacity:capacity];
            }
            
            [self.client URLProtocol:self didReceiveResponse:self.URLResponse cacheStoragePolicy:NSURLCacheStorageAllowed];
        }
    }
    
    // Next course of action depends on what happened to the stream
    switch (streamEvent) {
        case NSStreamEventHasBytesAvailable: {
            while ([theStream hasBytesAvailable]) {
                uint8_t buf[1024];
                NSUInteger len = [theStream read:buf maxLength:1024];
                if (_buffer && len > 0)
                    [_buffer appendBytes:(const void *)buf length:len];
                else if (len > 0)
                    [self.client URLProtocol:self didLoadData:[NSData dataWithBytes:buf length:len]];
            }
            break;
        }
            
        case NSStreamEventEndEncountered: {   // Report the end of the stream to the delegate            
            if (_compression == SGGzip)
                [self.client URLProtocol:self didLoadData:[_buffer gzipInflate]];
            else if (_compression == SGDeflate)
                [self.client URLProtocol:self didLoadData:[_buffer zlibInflate]];
//            else
//                [self.client URLProtocol:self didLoadData:_buffer];
            
            [self.client URLProtocolDidFinishLoading:self];
            _buffer = nil;
            break;
        }
            
        case NSStreamEventErrorOccurred: {    // Report an error in the stream as the operation failing
            ELog(@"An stream error occured")
            [self.client URLProtocol:self didFailWithError:[theStream streamError]];
            _buffer = nil;
            break;
        }
            
        default: {
            DLog(@"Unhandled event %i", streamEvent);
        }
    }
}

#pragma mark - Helper

- (NSUInteger)lengthOfDataSent {
    return [[_HTTPStream propertyForKey:(NSString *)kCFStreamPropertyHTTPRequestBytesWrittenCount] unsignedIntValue];
}

- (CFHTTPMessageRef)newMessageWithURLRequest:(NSURLRequest *)request {
    DLog(@"Request method: %@", [request HTTPMethod]);
    CFHTTPMessageRef message = CFHTTPMessageCreateRequest(NULL,
                                              (__bridge CFStringRef)[request HTTPMethod],
                                              (__bridge CFURLRef)[request URL],
                                              kCFHTTPVersion1_1);

    
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Host"), (__bridge CFStringRef)request.URL.host);
    NSString *language = [[[NSLocale preferredLanguages] subarrayWithRange:NSMakeRange(0, 3)] componentsJoinedByString:@","];
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Language"), (__bridge CFStringRef)language);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Charset"), CFSTR("utf-8;q=1.0, ISO-8859-1;q=0.5"));
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Encoding"), CFSTR("gzip;q=1.0, deflate;q=0.6, identity;q=0.5, *;q=0"));
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Connection"), CFSTR("Keep-Alive"));

    if (request.HTTPShouldHandleCookies) {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSURL *url = request.URL;//request.mainDocumentURL; ? request.mainDocumentURL : 
        NSArray *cookies = [cookieStorage cookiesForURL:url];
        NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
        for (NSString *key in headers) {
            NSString *val = headers[key];
            CFHTTPMessageSetHeaderFieldValue(message,
                                             (__bridge CFStringRef)key,
                                             (__bridge CFStringRef)val);
        }

    }
    
    DLog(@"Request headers: %@", request.allHTTPHeaderFields);
    for (NSString *key in request.allHTTPHeaderFields) {
        NSString *val = (request.allHTTPHeaderFields)[key];
        CFHTTPMessageSetHeaderFieldValue(message,
                                         (__bridge CFStringRef)key,
                                         (__bridge CFStringRef)val);
    }
    
    if (request.HTTPBody)
        CFHTTPMessageSetBody(message, (__bridge CFDataRef)request.HTTPBody);
    
    return message;
}

- (void)handleCookiesWithURLResponse:(NSHTTPURLResponse *)response {
    NSString *cookieString = (response.allHeaderFields)[@"Set-Cookie"];
    if (cookieString) {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields
                                                                  forURL:response.URL];
        [cookieStorage setCookies:cookies
                           forURL:response.URL
                  mainDocumentURL:self.request.mainDocumentURL];
    }
}

#pragma mark - NSURLAuthenticationChallengeSender

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSParameterAssert(challenge == [self authChallenge]);
    self.authChallenge = nil;
    [self stopLoading];
    
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
    [self.client URLProtocol:self didFailWithError:challenge.error];
    //[self.client URLProtocol:self didReceiveResponse:[challenge failureResponse] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    //[self.client URLProtocolDidFinishLoading:self];
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self cancelAuthenticationChallenge:challenge];
}

- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSParameterAssert(challenge == [self authChallenge]);
    self.authChallenge = nil;
    
    DLog(@"Try to use user: %@", credential.user);
    // Retry the request, this time with authentication // TODO: What if this function fails?
    CFHTTPAuthenticationRef HTTPAuthentication = [(SGHTTPAuthenticationChallenge *)challenge CFHTTPAuthentication];
    if (HTTPAuthentication) {
        CFHTTPMessageApplyCredentials(_HTTPMessage,
                                      HTTPAuthentication,
                                      (__bridge CFStringRef)[credential user],
                                      (__bridge CFStringRef)[credential password],
                                      NULL);
        [self startLoading];
    } else {
        [self cancelAuthenticationChallenge:challenge];
    }
}

-  (void)performDefaultHandlingForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self cancelAuthenticationChallenge:challenge];
}

- (void)rejectProtectionSpaceAndContinueWithChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self cancelAuthenticationChallenge:challenge];
}

@end



#pragma mark -




