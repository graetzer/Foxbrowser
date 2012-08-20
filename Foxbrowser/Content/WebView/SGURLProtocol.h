//
//  DEURLProtocol.h
//  DE Mail
//
//  Created by Simon Grätzer on 20.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SGURLProtocol : NSURLProtocol <NSURLConnectionDataDelegate> {
    @private
    NSLock *DialogLock;
    NSInteger DialogResult;
    NSURLCredentialPersistence CredentialsPresistance;
}
+ (void) registerProtocol;
+ (void) unregisterProtocol;

@property (strong, nonatomic) NSURLConnection *URLConnection;
@property (strong, nonatomic) NSMutableURLRequest *URLRequest;
@end
