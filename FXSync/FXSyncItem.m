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

//- (NSDictionary *)jsonPayload {
//    if (_jsonPayload == nil) {
//        NSError *error = nil;
//        _jsonPayload = [NSJSONSerialization JSONObjectWithData:_payload options:0 error:&error];
//        ELog(error);
//    }
//    return _jsonPayload;
//}

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
