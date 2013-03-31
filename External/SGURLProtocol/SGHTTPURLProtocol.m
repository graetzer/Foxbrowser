//
//  SGURLProtocol.m
//  SGProtocol
//
//  Created by Simon Grätzer on 25.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGHTTPURLProtocol.h"
#import "NSData+Compress.h"
#import "CanonicalRequest.h"

typedef enum {
        SGIdentity = 0,
        SGGzip = 1,
        SGDeflate = 2
    } SGCompression;

@implementation SGHTTPURLProtocol {
    NSThread *_clientThread;
    
    NSInputStream *_HTTPStream;
    CFHTTPMessageRef _HTTPMessage;
    
    NSInteger _authenticationAttempts;
    BOOL _validatesSecureCertificate;
    
    NSMutableData *_buffer;
    SGCompression _compression;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request{
    NSString *scheme = [request.URL.scheme lowercaseString];
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
    //return [scheme isEqualToString:@"https"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return CanonicalRequestForRequest(request);
}

- (id)initWithRequest:(NSURLRequest *)request
       cachedResponse:(NSCachedURLResponse *)cachedResponse
               client:(id<NSURLProtocolClient>)client {
    if (self = [super initWithRequest:request
                cachedResponse:cachedResponse
                        client:client]) {
        _compression = SGIdentity;
        _authenticationAttempts = -1;
        _validatesSecureCertificate = ValidatesSecureCertificate;
    }
    return self;
}

#ifdef DEBUG
- (void)dealloc {
    NSAssert(!_HTTPMessage, @"Deallocating HTTP message while it still exists");
    NSAssert(!_HTTPStream, @"Deallocating HTTP connection while stream still exists");
    NSAssert(!_URLResponse, @"Deallocating HTTP response while it still exists");
    NSAssert(!_authChallenge, @"HTTP connection deallocated mid-authentication");
    NSAssert(!_buffer, @"Buffer should be nil by now");
}
#endif

- (void)startLoading {
    NSAssert(_URLResponse == nil, @"URLResponse is not nil, connection still ongoing");
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
    
    if ([NSThread isMainThread]) {// Happens on some pages, when a UIWebView is removed
        DLog(@"Main thread: %@", self.request.URL);
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
        return; // Ignore these for now
    }
    
    _clientThread = [NSThread currentThread];
    
    NSThread *thread = [SGHTTPURLProtocol threadForURLProtocol:self];
    [self performSelector:@selector(openHttpStream) onThread:thread withObject:nil waitUntilDone:NO];
}

- (void)stopLoading {
    NSThread *thread = [SGHTTPURLProtocol threadForURLProtocol:self];
    [self performSelector:@selector(closeHttpStream) onThread:thread withObject:nil waitUntilDone:NO];
}

#pragma mark - HTTP handling

- (void)openHttpStream {
    _HTTPMessage = [self newMessageWithURLRequest:self.request];
    
    NSInputStream *bodyStream = self.request.HTTPBodyStream;
    CFReadStreamRef stream;
    if (bodyStream)
        stream = CFReadStreamCreateForStreamedHTTPRequest(NULL, _HTTPMessage, (__bridge CFReadStreamRef)bodyStream);
    else
        stream = CFReadStreamCreateForHTTPRequest(NULL, _HTTPMessage);
    
    if (stream == NULL) {
        NSString *desc = @"Could not create HTTP stream";
        ELog(desc);
        
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"org.graetzer.http"
                                                                           code:SGURLProtocolErrorStreamCreation
                                                                       userInfo:@{NSLocalizedDescriptionKey:desc}]];
        return;
    }
    
    // We have to manage redirects for ourselves
    CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanFalse);
    
    if ([self.request respondsToSelector:@selector(allowsCellularAccess)]) {// Not present on iOS 5 and OSX < 10.8
        if (!self.request.allowsCellularAccess)
            CFReadStreamSetProperty(stream, kCFStreamPropertyNoCellular, kCFBooleanTrue);
    }
    
    // Important HTTP pipelining
    if (self.request.HTTPShouldUsePipelining)
        CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanTrue);
    else
        CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanFalse);
    
    if (self.request.networkServiceType != NSURLNetworkServiceTypeDefault) {
        CFStringRef serviceType = NULL;
        switch (self.request.networkServiceType) {
            case NSURLNetworkServiceTypeVoIP:
                serviceType = kCFStreamNetworkServiceTypeVoIP;
                break;
                //case 8:// UIWebView calls with networkServiceType == 8
            case NSURLNetworkServiceTypeVideo:
                serviceType = kCFStreamNetworkServiceTypeVideo;
                break;
            case NSURLNetworkServiceTypeVoice:
                serviceType = kCFStreamNetworkServiceTypeVoice;
                break;
            case NSURLNetworkServiceTypeBackground:
                serviceType = kCFStreamNetworkServiceTypeBackground;
                break;
        }
        if (serviceType != NULL) {
            CFReadStreamSetProperty(stream, kCFStreamNetworkServiceType, serviceType);
        }
    }
    
    // Handle SSL manually, to allow us to ask the user about it
    if([[self.request.URL.scheme lowercaseString] isEqualToString:@"https"]) {
        CFReadStreamSetProperty(stream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);
        //https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/OverridingSSLChainValidationCorrectly.html
        CFMutableDictionaryRef pDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 4,
                                                                 &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(pDict, kCFStreamSSLValidatesCertificateChain, kCFBooleanFalse);
        CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings, pDict);
        CFRelease(pDict);
    } else {
        // Ignore in case of http
        _validatesSecureCertificate = NO;
    }
    
    _HTTPStream = (NSInputStream *)CFBridgingRelease(stream);
    [_HTTPStream setDelegate:self];
    [_HTTPStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_HTTPStream open];

}

- (void)closeHttpStream {
    if (_HTTPStream && _HTTPStream.streamStatus != NSStreamStatusClosed) {
        _HTTPStream.delegate = nil;
        // This method has to be called on the same thread as startLoading
        [_HTTPStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_HTTPStream close];
    }
    
    if (_HTTPMessage)
        CFRelease(_HTTPMessage);
    
    _HTTPMessage = NULL;
    _HTTPStream = nil;
    _URLResponse = nil;
    _buffer = nil;
}

- (void)stream:(NSInputStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    NSAssert(theStream == _HTTPStream, @"Not my stream!");

    if (!_URLResponse)// Handle the response as soon as it's available
        [self parseStreamHttpHeader:theStream];
    
    switch (streamEvent) {
            
        case NSStreamEventHasBytesAvailable: {
            
            if (_validatesSecureCertificate) {// Should be == NO in case of http
                SecTrustRef trust = (__bridge SecTrustRef)[theStream propertyForKey:(__bridge NSString *)kCFStreamPropertySSLPeerTrust];

                if (trust != NULL && ![self evaluateTrust:trust]) {// connection is untrusted
                    [self closeHttpStream];
                    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateUntrusted userInfo:@{
                                    NSLocalizedDescriptionKey:NSLocalizedString(@"Cannot Verify Server Identity", @"Untrusted certificate")
                                      }];
                    [self.client URLProtocol:self didFailWithError:error];
                    return;
                }
            }
            
            while ([theStream hasBytesAvailable]) {
                uint8_t buf[1024];
                NSInteger len = [theStream read:buf maxLength:1024];
                if (len > 0) {
                    // If there is no buffer, there is no compression specified. Therefore we can just send the data
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
            [self closeHttpStream];

            NSError *error = theStream.streamError;
            
            if (_authChallenge) {
                [self.client URLProtocol:self didCancelAuthenticationChallenge:_authChallenge];
                _authChallenge = nil;
            }
            
            
            DLog(@"A stream error occured,\n URL: %@\n Error domain: %@  code: %d", self.request.URL, error.domain,error.code);
            [self.client URLProtocol:self didFailWithError:error];
            
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Helper methods

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
                                                                               code:SGURLProtocolErrorInvalidResponse
                                                                           userInfo:@{NSLocalizedDescriptionKey:@"Invalid HTTP response"}]];
            [self closeHttpStream];
            return;
        }
        
        if ([self.request HTTPShouldHandleCookies])
            [self handleCookiesWithURLResponse:_URLResponse];
        
        NSString *location = _URLResponse.allHeaderFields[@"Location"];
        
        // If the response was an authentication failure, try to request fresh credentials.
        if (location && ((statusCode >= 301 && statusCode <= 303) || statusCode == 307 || statusCode == 308)) {
            
            NSURL *nextURL = [[NSURL URLWithString:location relativeToURL:URL] absoluteURL];            
            if (nextURL) {
                NSMutableURLRequest *nextRequest;
                if (statusCode == 307 || statusCode == 308) {
                    nextRequest = [self.request mutableCopy];
                    nextRequest.URL = nextURL;
                } else {
                    nextRequest = [NSMutableURLRequest requestWithURL:nextURL
                                                          cachePolicy:self.request.cachePolicy
                                                      timeoutInterval:self.request.timeoutInterval];
                    [nextRequest setValue:[self.request valueForHTTPHeaderField:@"Accept"] forHTTPHeaderField:@"Accept"];
                    [nextRequest setValue:[self.request valueForHTTPHeaderField:@"User-Agent"] forHTTPHeaderField:@"User-Agent"];
                }
                
                NSString *referer = [self.request valueForHTTPHeaderField:@"Referer"];
                if (!referer)
                    referer = self.request.URL.absoluteString;
                [nextRequest setValue:referer forHTTPHeaderField:@"Referer"];
                [self.client URLProtocol:self wasRedirectedToRequest:nextRequest redirectResponse:_URLResponse];
                
                [self closeHttpStream];
                [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
                return;
            }
        } else if (statusCode == 304) { // Handle cached stuff
            
            NSCachedURLResponse *cached = [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request];
            if (cached) {
                [self.client URLProtocol:self cachedResponseIsValid:cached];
                [self.client URLProtocol:self didReceiveResponse:cached.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                [self.client URLProtocol:self didLoadData:[cached data]];
                [self.client URLProtocolDidFinishLoading:self];// No http body expected
                [self closeHttpStream];
                return;
            } else {
                DLog(@"No cached response existent for %@", self.request.URL);
                [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"org.graetzer.http"
                                                                                   code:SGURLProtocolErrorNoCachedResponse
                                                                               userInfo:@{NSLocalizedDescriptionKey:@"No cached response"}]];
            }
        } else if (statusCode == 401 || statusCode == 407) {
            NSAssert(!self.authChallenge, @"Authentication challenge received while another one is in progress");
            
            _authenticationAttempts++;
            _authChallenge = [[SGHTTPAuthenticationChallenge alloc] initWithResponse:response
                                                                previousFailureCount:_authenticationAttempts
                                                                     failureResponse:_URLResponse
                                                                              sender:self];
            
            if (self.authChallenge) {
                // Cancel any further loading and ask the delegate for authentication
                [self closeHttpStream];
                
                if (_authenticationAttempts == 0 && self.authChallenge.proposedCredential) {
                    [self useCredential:self.authChallenge.proposedCredential forAuthenticationChallenge:self.authChallenge];
                } else {
                    [self.client URLProtocol:self didReceiveAuthenticationChallenge:self.authChallenge];
                    
                    [VariableLock lock];
                    if (ProtocolDelegate && [ProtocolDelegate respondsToSelector:@selector(URLProtocol:didReceiveAuthenticationChallenge:)]) {
                        [ProtocolDelegate URLProtocol:self didReceiveAuthenticationChallenge:self.authChallenge];
                    }
                    [VariableLock unlock];
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
        
        NSString *cEncoding = [_URLResponse.allHeaderFields[@"Content-Encoding"] lowercaseString];
        if (cEncoding.length > 0) {
            cEncoding = [cEncoding stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
            if ([cEncoding isEqualToString:@"gzip"]) {
                _compression = SGGzip;
            } else if ([cEncoding isEqualToString:@"deflate"]) {
                _compression = SGDeflate;
            }
        } else _compression = SGIdentity;
        
        if (_compression != SGIdentity) {
            long long capacity = _URLResponse.expectedContentLength;
            if (capacity == NSURLResponseUnknownLength || capacity == 0)
                capacity = 1024*512;//5M buffer capacity
            _buffer = [[NSMutableData alloc] initWithCapacity:capacity];
        }
        
        NSURLCacheStoragePolicy policy = [self cachePolicyForRequest:self.request response:_URLResponse];
        [self.client URLProtocol:self didReceiveResponse:_URLResponse cacheStoragePolicy:policy];
    }
}

- (NSUInteger)lengthOfDataSent {
    return [[_HTTPStream propertyForKey:(NSString *)kCFStreamPropertyHTTPRequestBytesWrittenCount] unsignedIntValue];
}

- (CFHTTPMessageRef)newMessageWithURLRequest:(NSURLRequest *)request {
    CFHTTPMessageRef message = CFHTTPMessageCreateRequest(kCFAllocatorDefault,
                                              (__bridge CFStringRef)[request HTTPMethod],
                                              (__bridge CFURLRef)[request URL],
                                              kCFHTTPVersion1_1);

    NSString *locale = [[[NSLocale preferredLanguages] subarrayWithRange:NSMakeRange(0, 3)] componentsJoinedByString:@","];
    
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Host"), (__bridge CFStringRef)request.URL.host);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Language"), (__bridge CFStringRef)locale);
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Charset"), CFSTR("ISO-8859-1,utf-8;q=0.7,*;q=0.3"));
    CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Accept-Encoding"), CFSTR("gzip,deflate"));

    if (request.HTTPShouldHandleCookies) {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray *cookies = [cookieStorage cookiesForURL:request.URL];
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
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields
                                                              forURL:response.URL];
    [cookieStorage setCookies:cookies
                       forURL:response.URL
              mainDocumentURL:self.request.mainDocumentURL];
}

- (NSURLCacheStoragePolicy)cachePolicyForRequest:(NSURLRequest *)request response:(NSHTTPURLResponse *)response {
    BOOL cacheable = NO;
    NSURLCacheStoragePolicy result = NSURLCacheStorageNotAllowed;
    
    switch (response.statusCode) {
        case 200:
        case 203:
        case 206:
        case 301:
        case 304:
        case 404:
        case 410:
            cacheable = YES;
    }
    
    // If the response might be cacheable, look at the "Cache-Control" header in
    // the response.
    if (cacheable) {
        NSString *responseHeader = [[[response allHeaderFields] objectForKey:@"Cache-Control"] lowercaseString];
        if ( (responseHeader != nil) && [responseHeader rangeOfString:@"no-store"].location != NSNotFound) {
            cacheable = NO;
        }
    }
    
    // If we still think it might be cacheable, look at the "Cache-Control" header in
    // the request.
    if (cacheable) {
        NSString *requestHeader = [[[request allHTTPHeaderFields] objectForKey:@"Cache-Control"] lowercaseString];
        if ( (requestHeader != nil)
            && ([requestHeader rangeOfString:@"no-store"].location != NSNotFound)
            && ([requestHeader rangeOfString:@"no-cache"].location != NSNotFound) ) {
            cacheable = NO;
        }
    }
    if (cacheable) {
        if ([[request.URL.scheme lowercaseString] isEqual:@"https"]) result = NSURLCacheStorageAllowedInMemoryOnly;
        else result = NSURLCacheStorageAllowed;
    }
    
    return result;
}

- (BOOL)evaluateTrust:(SecTrustRef)trust {
    if (trust == NULL)  return NO;
    
    SecTrustResultType res = kSecTrustResultInvalid;
    if (SecTrustEvaluate(trust, &res)) {
        DLog(@"The trust evaluation failed for some reason");
        return NO;
    }
        
    if (res != kSecTrustResultProceed && res != kSecTrustResultUnspecified) {// If NO we shouldn't trust
        [VariableLock lock];
        // Ask the delegate if we should proceed anyway
        if ([ProtocolDelegate respondsToSelector:@selector(URLProtocol:canIgnoreUntrustedHost:)]) {
            BOOL ignore = [ProtocolDelegate URLProtocol:self canIgnoreUntrustedHost:trust];
            if (ignore) _validatesSecureCertificate = NO;
        }
        [VariableLock unlock];
    } else {
        // Validation succeded, ignore from now on
        _validatesSecureCertificate = NO;
    }
    
    return !_validatesSecureCertificate;
}

#pragma mark - NSURLAuthenticationChallengeSender

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSParameterAssert(challenge == [self authChallenge]);
    _authChallenge = nil;
    [self stopLoading];
    
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
    [self.client URLProtocol:self didFailWithError:challenge.error];
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self cancelAuthenticationChallenge:challenge];
}

- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSParameterAssert(challenge == [self authChallenge]);
    _authChallenge = nil;
    
    DLog(@"Try to use user: %@", credential.user);
    // Retry the request, this time with authenticatio
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

#pragma mark - Threading

// In the default implementation, all requests run in a single background thread
// Advanced users only: Override this method in a subclass for a different threading behaviour
// Eg: return [NSThread mainThread] to run all requests in the main thread
// Alternatively, you can create a thread on demand, or manage a pool of threads
// Threads returned by this method will need to run the runloop in default mode (eg CFRunLoopRun())
// Requests will stop the runloop when they complete
// If you have multiple requests sharing the thread or you want to re-use the thread, you'll need to restart the runloop
static NSThread *NetworkThread = nil;
+ (NSThread *)threadForURLProtocol:(NSURLProtocol *)protocol {
	if (NetworkThread == nil) {
		@synchronized(self) {
			if (NetworkThread == nil) {
                // Let the thread run indefinetly
				NetworkThread = [[NSThread alloc] initWithTarget:self selector:@selector(runRequests) object:nil];
                [NetworkThread setName:@"SGHTTPURLProtocol net thread"];
				[NetworkThread start];
			}
		}
	}
	return NetworkThread;
}

+ (void)runRequests {
	// Should keep the runloop from exiting
	CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
	CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    
    BOOL runAlways = YES; // Introduced to cheat Static Analyzer
	while (runAlways) {
		@autoreleasepool {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0e10, true);
        }
	}
    
	// Should never be called, but anyway
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
	CFRelease(source);
}

#pragma mark - Stuff

__strong static NSLock* VariableLock;
static BOOL ValidatesSecureCertificate = YES;
__weak static id<SGHTTPURLProtocolDelegate> ProtocolDelegate;
__strong static NSMutableDictionary *HTTPHeaderFields;

+ (void)initialize {
    VariableLock = [NSLock new];
    HTTPHeaderFields = [[NSMutableDictionary alloc] initWithCapacity:10];
}

+ (void)registerProtocol {
    [NSURLProtocol registerClass:[self class]];
}

+ (void)unregisterProtocol {
    [NSURLProtocol unregisterClass:[self class]];
}

+ (void)setProtocolDelegate:(id<SGHTTPURLProtocolDelegate>)delegate {
    [VariableLock lock];
    ProtocolDelegate = delegate;
	[VariableLock unlock];
}

+ (id<SGHTTPURLProtocolDelegate>)protocolDelegate {
    id<SGHTTPURLProtocolDelegate> delegate;
    [VariableLock lock];
    delegate = ProtocolDelegate;
	[VariableLock unlock];
    return delegate;
}

+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [VariableLock lock];
    HTTPHeaderFields[field] = value;
	[VariableLock unlock];
}

+ (BOOL)validatesSecureCertificate {
    return ValidatesSecureCertificate;
}

+ (void)setValidatesSecureCertificate:(BOOL)validate; {
    [VariableLock lock];
    ValidatesSecureCertificate = validate;
	[VariableLock unlock];
}

@end
