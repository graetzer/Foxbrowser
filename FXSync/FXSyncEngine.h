//
//  FXSyncEngine.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 21.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FXSyncEngine;

FOUNDATION_EXPORT NSString *const kFXSyncEngineErrorDomain;
typedef NS_ENUM(NSUInteger, kFXSyncEngineError) {
    kFXSyncEngineErrorUnsupportedStorageVersion,
    kFXSyncEngineErrorEncryption,
    kFXSyncEngineErrorEndOfLife,
    kFXSyncEngineErrorMaintenance
};

@protocol FXSyncEngineDelegate <NSObject>
@required
- (void)syncEngine:(FXSyncEngine *)engine didLoadCollection:(NSString *)cName;
- (void)syncEngine:(FXSyncEngine *)engine didFailWithError:(NSError *)error;
- (void)syncEngine:(FXSyncEngine *)engine alertWithString:(NSString *)alert;
@end

@class FXUserAuth, Reachability;
/*! Supposed to do the actual sync process. 
 *
 * https://docs.services.mozilla.com/sync/storageformat5.html
 * https://docs.services.mozilla.com/storage/apis-1.5.html
 */
@interface FXSyncEngine : NSObject

/*! Map collections to sync sizes*/
+ (NSDictionary *)collectionNames;

@property (strong, nonatomic) FXUserAuth *userAuth;
@property (strong, nonatomic, readonly) Reachability *reachability;

@property (weak, nonatomic) id<FXSyncEngineDelegate> delegate;

@property (readonly, getter=isSyncRunning) BOOL syncRunning;
/*! Uses the iOS vendor identifier */
@property (nonatomic, readonly) NSString *clientID;
@property (nonatomic, readonly) NSString *clientName;

- (void)startSync;

@end

FOUNDATION_EXPORT NSString *const kFXTabsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXBookmarksCollectionKey;
FOUNDATION_EXPORT NSString *const kFXHistoryCollectionKey;
FOUNDATION_EXPORT NSString *const kFXPasswordsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXPrefsCollectionKey;
FOUNDATION_EXPORT NSString *const kFXFormsCollectionKey;

