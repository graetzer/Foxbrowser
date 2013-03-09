//
//  SGURLProtocol.m
//  SGProtocol
//
//  Created by Simon Grätzer on 25.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGHTTPURLProtocol.h"

static NSInteger RegisterCount = 0;
static BOOL SSLValidatesCertificateChain = NO;
__strong static NSLock* VariableLock;
__strong static id<SGHTTPAuthDelegate> AuthDelegate;
__strong static NSMutableDictionary *HTTPHeaderFields;

typedef enum {
        SGIdentity = 0,
        SGGzip = 1,
        SGDeflate = 2
    } SGCompression;

@implementation SGHTTPURLProtocol {
    //Request
    NSInputStream *_HTTPStream;
    CFHTTPMessageRef _HTTPMessage;
    
    //Response
    NSHTTPURLResponse *_URLResponse;
    NSInteger _authenticationAttempts;
    
    NSMutableData *_buffer;
    SGCompression _compression;
}

+ (void)initialize {
    VariableLock = [[NSLock alloc] init];
    HTTPHeaderFields = [[NSMutableDictionary alloc] initWithCapacity:10];
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

+ (void)setAuthDelegate:(id<SGHTTPAuthDelegate>)delegate {
    [VariableLock lock];
    AuthDelegate = delegate;
	[VariableLock unlock];
}

+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [VariableLock lock];
    HTTPHeaderFields[field] = value;
	[VariableLock unlock];
}

+ (BOOL)SSLValidatesCertificateChain {
    return SSLValidatesCertificateChain;
}

+ (void)setSSLValidatesCertificateChain:(BOOL)validate; {
    [VariableLock lock];
    SSLValidatesCertificateChain = validate;
	[VariableLock unlock];
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
        s = [s substringToIndex:s.length - frag.length];// remove fragment
        mutable.URL = [NSURL URLWithString:s];
        return mutable;
    }
	return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (id)initWithRequest:(NSURLRequest *)request
       cachedResponse:(NSCachedURLResponse *)cachedResponse
               client:(id<NSURLProtocolClient>)client {
    if (self = [super initWithRequest:request
                cachedResponse:cachedResponse
                        client:client]) {
        _compression = SGIdentity;
        _authenticationAttempts = -1;
        _HTTPMessage = [self newMessageWithURLRequest:request];
        NSLog(@"Headers:\n%@", request.allHTTPHeaderFields);
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
    NSAssert(_URLResponse, @"URLResponse is not nil, connection still ongoing");
    NSAssert(_HTTPStream == nil, @"HTTPStream is not nil, connection still ongoing");
    
    if (self.cachedResponse) {// Doesn't seem to happen
        DLog(@"Have cached response: %@", self.cachedResponse.userInfo);
        [self.client URLProtocol:self cachedResponseIsValid:self.cachedResponse];
        [self.client URLProtocol:self didReceiveResponse:self.cachedResponse.response
              cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:self.cachedResponse.data];
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }
    
    NSInputStream *bodyStream = self.request.HTTPBodyStream;
    CFReadStreamRef stream;
    if (bodyStream)
        stream = CFReadStreamCreateForStreamedHTTPRequest(NULL, _HTTPMessage, (__bridge CFReadStreamRef)bodyStream);
    else
        stream = CFReadStreamCreateForHTTPRequest(NULL, _HTTPMessage);
    
    if (stream != NULL) {
        if (self.request.HTTPShouldUsePipelining)
            CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanTrue);
        else
            CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanFalse);
        
        CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanFalse);
        if([[self.request.URL.scheme lowercaseString] isEqualToString:@"https"]) {
            // Ignore SSL stuff, because there seems to be no way of getting notified
            CFMutableDictionaryRef pDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 2,
                                                                     &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            if (SSLValidatesCertificateChain)
                CFDictionarySetValue(pDict, kCFStreamSSLValidatesCertificateChain, kCFBooleanTrue);
            else
                CFDictionarySetValue(pDict, kCFStreamSSLValidatesCertificateChain, kCFBooleanFalse);
            CFDictionarySetValue(pDict, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelSSLv3);
            CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings, pDict);
            CFRelease(pDict);
        }

        _HTTPStream = (NSInputStream *)CFBridgingRelease(stream);
        [_HTTPStream setDelegate:self];
        [_HTTPStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_HTTPStream open];
    } else {
        NSString *desc = @"Could not create HTTP stream";
        ELog(desc);
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"org.graetzer.http"
                                                                           code:999
                                                                       userInfo:@{NSLocalizedDescriptionKey:desc}]];
    }
}

- (void)stopLoading {
    if (_HTTPStream && _HTTPStream.streamStatus != NSStreamStatusClosed)
        [_HTTPStream close];
        
    _HTTPStream = nil;
    _URLResponse = nil;
}

#pragma mark - CFStreamDelegate
- (void)stream:(NSInputStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    //NSParameterAssert(theStream == _HTTPStream);
    if (theStream != _HTTPStream) {
        ELog(@"Not my stream!");
        return;
    }
    
    if (!_URLResponse)// Handle the response as soon as it's available
        [self parseStreamHttpHeader:theStream];
    
    // Next course of action depends on what happened to the stream
    switch (streamEvent) {
        case NSStreamEventHasBytesAvailable: {
            while ([theStream hasBytesAvailable]) {
                uint8_t buf[1024];
                NSInteger len = [theStream read:buf maxLength:1024];
                if (len > 0) {
                    if (_buffer)
                        [_buffer appendBytes:(const void *)buf length:len];
                    else
                        [self.client URLProtocol:self didLoadData:[NSData dataWithBytes:buf length:len]];
                }
            }
            break;
        }
            
        case NSStreamEventEndEncountered: { // Report the end of the stream to the delegate            
            if (_compression == SGGzip)
                [self.client URLProtocol:self didLoadData:[_buffer gzipInflate]];
            else if (_compression == SGDeflate)
                [self.client URLProtocol:self didLoadData:[_buffer zlibInflate]];
            
            [self.client URLProtocolDidFinishLoading:self];
            _buffer = nil;
            break;
        }
            
        case NSStreamEventErrorOccurred: { // Report an error in the stream as the operation failing
            ELog(@"An stream error occured")
            [self.client URLProtocol:self didFailWithError:[theStream streamError]];
            _buffer = nil;
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Helper

- (void)parseStreamHttpHeader:(NSInputStream *)theStream {
    
    CFHTTPMessageRef response = (__bridge CFHTTPMessageRef)[theStream propertyForKey:(NSString *)kCFStreamPropertyHTTPResponseHeader];
    if (response && CFHTTPMessageIsHeaderComplete(response)) {
        
        // Construct a NSURLResponse object from the HTTP message
        NSURL *URL = [theStream propertyForKey:(NSString *)kCFStreamPropertyHTTPFinalURL];
        NSInteger statusCode = (NSInteger)CFHTTPMessageGetResponseStatusCode(response);
        NSString *HTTPVersion = CFBridgingRelease(CFHTTPMessageCopyVersion(response));
        NSDictionary *headerFields = CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(response));
        _URLResponse = [[NSHTTPURLResponse alloc] initWithURL:URL
                                                   statusCode:statusCode
                                                  HTTPVersion:HTTPVersion
                                                 headerFields:headerFields];
        if (_URLResponse == nil) {
            ELog(@"Invalid HTTP response");
            [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"org.graetzer.http"
                                                                               code:200
                                                                           userInfo:@{NSLocalizedDescriptionKey:@"Invalid HTTP response"}]];
            [self stopLoading];
            return;
        }
        
        if ([self.request HTTPShouldHandleCookies])
            [self handleCookiesWithURLResponse:_URLResponse];
        
        NSString *location = (_URLResponse.allHeaderFields)[@"Location"];
        
        // If the response was an authentication failure, try to request fresh credentials.
        if (location &&((statusCode >= 301 && statusCode <= 303) || statusCode == 307 || statusCode == 308)) {
            DLog(@"Redirect status code %d, Loc: %@", statusCode, location);

            NSURL *nextURL = [NSURL URLWithString:location];
            if (!nextURL)
                nextURL = [NSURL URLWithString:location relativeToURL:URL];
            
            if (nextURL) {
                NSMutableURLRequest *nextRequest;//
                if (statusCode == 301 || statusCode == 307 || statusCode == 308) {
                    nextRequest = [self.request mutableCopy];
                    nextRequest.URL = nextURL;
                } else {
                    nextRequest = [NSMutableURLRequest requestWithURL:nextURL
                                                          cachePolicy:self.request.cachePolicy
                                                      timeoutInterval:self.request.timeoutInterval];
                }
                NSString *referer = [self.request valueForHTTPHeaderField:@"Referer"];
                if (!referer)
                    referer = self.request.URL.absoluteString;
                
                [nextRequest setValue:referer forHTTPHeaderField:@"Referer"];
                [self.client URLProtocol:self wasRedirectedToRequest:nextRequest redirectResponse:_URLResponse];
            }
        } else if (statusCode == 304) { // Handle cached stuff
            
            NSCachedURLResponse *cached = [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request];
            if (cached) {
                [self.client URLProtocol:self cachedResponseIsValid:cached];
                [self.client URLProtocol:self didReceiveResponse:cached.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                [self.client URLProtocol:self didLoadData:[cached data]];
                [self.client URLProtocolDidFinishLoading:self];// No http body expected
                [self stopLoading];
                return;
            } else {
                ELog(@"No cached response existent");
                [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"org.graetzer.http"
                                                                                   code:304
                                                                               userInfo:@{NSLocalizedDescriptionKey:@"No cached response"}]];
            }
        } else if (statusCode == 401 || statusCode == 407) {
            NSAssert(!self.authChallenge, @"Authentication challenge received while another is in progress");
            
            _authenticationAttempts++;
            self.authChallenge = [[SGHTTPAuthenticationChallenge alloc] initWithResponse:response
                                                                    previousFailureCount:_authenticationAttempts
                                                                         failureResponse:_URLResponse
                                                                                  sender:self];
            
            if (self.authChallenge) {
                // Cancel any further loading and ask the delegate for authentication
                [self stopLoading];
                
                if (_authenticationAttempts == 0 && self.authChallenge.proposedCredential) {
                    [self useCredential:self.authChallenge.proposedCredential forAuthenticationChallenge:self.authChallenge];
                } else {
                    [VariableLock lock];
                    if (AuthDelegate) {
                        [AuthDelegate URLProtocol:self didReceiveAuthenticationChallenge:self.authChallenge];
                        [VariableLock unlock];
                    } else {
                        [VariableLock unlock];
                        [self.client URLProtocol:self didReceiveAuthenticationChallenge:self.authChallenge];
                    }
                }
                return; // Stops the delegate being sent a response received message
            } else {
                ELog(@"Failed to create auth challenge");
                NSError *error = [NSError errorWithDomain:@"org.graetzer.http"
                                                     code:407
                                                 userInfo:@{NSLocalizedDescriptionKey:@"Unable to create authentication challenge"}];
                [self.client URLProtocol:self didFailWithError:error];
            }
        }
        
        NSString *encoding = [_URLResponse.allHeaderFields[@"Content-Encoding"] lowercaseString];
        
        if ([encoding isEqualToString:@"gzip"])
            _compression = SGGzip;
        else if ([encoding isEqualToString:@"deflate"])
            _compression = SGDeflate;
        else
            _compression = SGIdentity;
        
        if (_compression != SGIdentity) {
            long long capacity = _URLResponse.expectedContentLength;
            if (capacity == NSURLResponseUnknownLength || capacity == 0)
                capacity = 1024*1024;//10M buffer
            _buffer = [[NSMutableData alloc] initWithCapacity:capacity];
        }
        
        NSURLCacheStoragePolicy policy = NSURLCacheStorageAllowed;
        if (self.request.cachePolicy == NSURLRequestUseProtocolCachePolicy
            && [self.request.URL.scheme isEqualToString:@"https"]) {
            policy = NSURLCacheStorageNotAllowed;
        }
        [self.client URLProtocol:self didReceiveResponse:_URLResponse cacheStoragePolicy:policy];
    }
}

- (NSUInteger)lengthOfDataSent {
    return [[_HTTPStream propertyForKey:(NSString *)kCFStreamPropertyHTTPRequestBytesWrittenCount] unsignedIntValue];
}

- (CFHTTPMessageRef)newMessageWithURLRequest:(NSURLRequest *)request {
    CFHTTPMessageRef message = CFHTTPMessageCreateRequest(NULL,
                                              (__bridge CFStringRef)[request HTTPMethod],
                                              (__bridge CFURLRef)[request URL],
                                              kCFHTTPVersion1_1);

    NSString *locale = [NSLocale preferredLanguages][0];
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Host"), (__bridge CFStringRef)request.URL.host);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Language"), (__bridge CFStringRef)locale);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Charset"), CFSTR("utf-8;q=1.0, ISO-8859-1;q=0.5"));
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Encoding"), CFSTR("gzip, deflate"));

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
        
    for (NSString *key in request.allHTTPHeaderFields) {
        NSString *val = request.allHTTPHeaderFields[key];
        CFHTTPMessageSetHeaderFieldValue(message,
                                         (__bridge CFStringRef)key,
                                         (__bridge CFStringRef)val);
    }
    for (NSString *key in HTTPHeaderFields) {
        NSString *val = HTTPHeaderFields[key];
        CFHTTPMessageSetHeaderFieldValue(message,
                                         (__bridge CFStringRef)key,
                                         (__bridge CFStringRef)val);
    }
    
    if (request.HTTPBody)
        CFHTTPMessageSetBody(message, (__bridge CFDataRef)request.HTTPBody);
    
    return message;
}

- (void)handleCookiesWithURLResponse:(NSHTTPURLResponse *)response {
//    NSString *cookieString = (response.allHeaderFields)[@"Set-Cookie"];
//    if (cookieString) {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields
                                                                  forURL:response.URL];
        [cookieStorage setCookies:cookies
                           forURL:response.URL
                  mainDocumentURL:self.request.mainDocumentURL];
    //}
}

#pragma mark - NSURLAuthenticationChallengeSender

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSParameterAssert(challenge == [self authChallenge]);
    self.authChallenge = nil;
    [self stopLoading];
    
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
    [self.client URLProtocol:self didFailWithError:challenge.error];
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




