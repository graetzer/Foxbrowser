//
//  FXSyncStock.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 24.09.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSyncStock.h"
#import "FXUserAuth.h"
#import "FXSyncEngine.h"

@implementation FXSyncStock

+ (instancetype)sharedInstance {
    static FXSyncStock *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FXSyncStock alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _syncEngine = [FXSyncEngine new];
        _syncEngine.userAuth = [[FXUserAuth alloc] initEmail:@"simon@graetzer.org"
                                                    password:@"foochic923"];
    }
    return self;
}

- (void)restock {
    [_syncEngine startSync];
}

@end
