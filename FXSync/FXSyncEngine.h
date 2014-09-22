//
//  FXSyncEngine.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 21.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FXUserAuth, Reachability;
/*! Supposed to do the actual sync process. 
 * I call it Thomas the little sync engine
 */
@interface FXSyncEngine : NSObject

+ (instancetype)sharedInstance;
+ (NSArray *)collectionNames;

@property (nonatomic, copy) NSNumber *localTimeOffsetSec;
@property (strong, nonatomic, readonly) FXUserAuth *userAuth;
@property (strong, nonatomic, readonly) NSDictionary *syncInfo;
@property (strong, nonatomic, readonly) Reachability *reachability;

@property (readonly) BOOL syncRunning;
- (void)startSync;
- (void)cancelSync;

@end

FOUNDATION_EXPORT NSString *const kFXTabsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXBookmarksCollectionKey;
FOUNDATION_EXPORT NSString *const kFXHistoryCollectionKey;
FOUNDATION_EXPORT NSString *const kFXPasswordsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXPrefsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXFormsCollectionKey;

