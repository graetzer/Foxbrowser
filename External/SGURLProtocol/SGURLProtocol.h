//
//  SGURLHttpProtocol.h
//  SGURLProtocol
//
//  Created by Simon Grätzer on 28.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#ifndef SGURLProtocol_SGURLHttpProtocol_h
#define SGURLProtocol_SGURLHttpProtocol_h

#ifdef DEBUG
#   define DLog(fmt, ...) {NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);}
#   define ELog(err) {if(err) DLog(@"%@", err)}
#else
#   define DLog(...)
#   define ELog(err)
#endif

#import "SGHTTPURLProtocol.h"
#import "SGHTTPAuthenticationChallenge.h"
#import "NSData+Compress.h"

#endif
