/*
    File:       CustomHTTPProtocol.h

    Contains:   An NSURLProtocol subclass that overrides the built-in "http" protocol.

    Written by: DTS

    Copyright:  Copyright (c) 2011-2012 Apple Inc. All Rights Reserved.

    Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
                ("Apple") in consideration of your agreement to the following
                terms, and your use, installation, modification or
                redistribution of this Apple software constitutes acceptance of
                these terms.  If you do not agree with these terms, please do
                not use, install, modify or redistribute this Apple software.

                In consideration of your agreement to abide by the following
                terms, and subject to these terms, Apple grants you a personal,
                non-exclusive license, under Apple's copyrights in this
                original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or
                without modifications, in source and/or binary forms; provided
                that if you redistribute the Apple Software in its entirety and
                without modifications, you must retain this notice and the
                following text and disclaimers in all such redistributions of
                the Apple Software. Neither the name, trademarks, service marks
                or logos of Apple Inc. may be used to endorse or promote
                products derived from the Apple Software without specific prior
                written permission from Apple.  Except as expressly stated in
                this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any
                patent rights that may be infringed by your derivative works or
                by other works in which the Apple Software may be incorporated.

                The Apple Software is provided by Apple on an "AS IS" basis. 
                APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
                WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
                MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
                THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.

                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
                INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
                TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
                DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
                OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
                OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
                OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
                SUCH DAMAGE.

*/

#import <Foundation/Foundation.h>

@protocol CustomHTTPProtocolDelegate;

@interface CustomHTTPProtocol : NSURLProtocol

// Subclass specific additions

+ (void)start;
    // Call this to start the module.  Prior to this the module is just dormant, and 
    // all HTTP requests proceed as normal.  After this all HTTP and HTTPS requests 
    // go through this module.
+ (void)stop;

// The delegate is not retained in general, but is retained for the duration of any given 
// call.  Once you set the delegate to nil you can be assured that it won't be called 
// unretained (that is, by the time that -setDelegate: returns, we've already done 
// all possible retains on the delegate).

+ (id<CustomHTTPProtocolDelegate>)delegate;
+ (void)setDelegate:(id<CustomHTTPProtocolDelegate>)newValue;

+ (void)setHeaders:(NSDictionary *)headers;

@property (retain, readonly ) NSURLAuthenticationChallenge *    pendingChallenge;   // main thread only please

- (void)resolveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge withCredential:(NSURLCredential *)credential;
    // must be called on the main thread
    // credential may be nil, to continue the request without a credential

@end

/*
    The delegate handles two different types of callbacks:

    o authentication challenges
    o logging

    The latter is very simple.  The former is quite tricky.  The basic idea is that each CustomHTTPProtocol 
    sends the delegate a serialised stream of authentication challenges, each of which it is expected to 
    resolve.  The sequence is as follows:

    1. It calls -customHTTPProtocol:canAuthenticateAgainstProtectionSpace: to determine if your delegate 
       can handle the challenge.  This can be call on an arbitrary background thread.

    2. If the delegate returns YES, it calls -customHTTPProtocol:didReceiveAuthenticationChallenge: to 
       actually process the challenge.  This is always called on the main thread.  The delegate can resolve 
       the challenge synchronously (that is, before returning from the call) or it can return from the call 
       and then, later on, resolve the challenge.  Resolving the challenge involves calling 
       -[CustomHTTPProtocol resolveAuthenticationChallenge:withCredential:], which also must be called 
       on the main thread.  Between the calls to -customHTTPProtocol:didReceiveAuthenticationChallenge: 
       and -[CustomHTTPProtocol resolveAuthenticationChallenge:withCredential:], the protocol's 
       pendingChallenge property will contain the challenge.
    
    3. While there is a pending challenge, the protocol may call -customHTTPProtocol:didCancelAuthenticationChallenge: 
       to cancel the challenge.  This is always called on the main thread.
*/

@protocol CustomHTTPProtocolDelegate <NSObject>

@optional

- (BOOL)customHTTPProtocol:(CustomHTTPProtocol *)protocol canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace;
    // called on an arbitrary thread
    // protocol will not be nil
    // protectionSpace will not be nil
    
- (void)customHTTPProtocol:(CustomHTTPProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
    // called on the main thread
    // protocol will not be nil
    // challenge will not be nil
    
- (void)customHTTPProtocol:(CustomHTTPProtocol *)protocol didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
    // called on the main thread
    // protocol will not be nil
    // challenge will not be nil

- (void)customHTTPProtocol:(CustomHTTPProtocol *)protocol logWithFormat:(NSString *)format arguments:(va_list)argList;
    // called on an arbitrary thread
    // protocol may be nil, implying a log message from the class itself
    // format will not be nil


@end
