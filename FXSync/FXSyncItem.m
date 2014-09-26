//
//  FXSyncItem.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 20.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSyncItem.h"
#import "FXSyncStore.h"

@implementation FXSyncItem
@synthesize jsonPayload = _jsonPayload;

- (void)setPayload:(NSData *)payload {
    if (payload != _payload) {
        _jsonPayload = nil;
        _payload = payload;
    }
}

- (NSDictionary *)jsonPayload {
    if (_jsonPayload == nil) {
        NSError *error = nil;
        _jsonPayload = [NSJSONSerialization JSONObjectWithData:_payload
                                                       options:NSJSONReadingMutableContainers
                                                         error:&error];
        ELog(error);
        if (![_jsonPayload[@"id"] isEqual:_syncId]) {
            @throw [NSException exceptionWithName:@"org.graetzer.fxsync.engine"
                                           reason:@"Record id mismatch"
                                         userInfo:_jsonPayload];
        }
    }
    return _jsonPayload;
}

- (void)save {
    if (_jsonPayload != nil) {
        _modified = -1;//[[NSDate date] timeIntervalSince1970];
        
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:_jsonPayload
                                                       options:0
                                                         error:&error];
        if (error != nil) {
            _payload = data;
            [[FXSyncStore sharedInstance] saveItem:self];
        }
    }
}

@end
