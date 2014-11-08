//
//  FXSyncStore.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 14.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import <sqlite3.h>

#import "FXSyncStore.h"
#import "FXSyncEngine.h"
#import "FXSyncItem.h"

NSString *const kFXSyncStoreFile = @"fxstore.db";
NSString *const kFXSyncStoreException = @"org.graetzer.fxsync.db";

@implementation FXSyncStore {
    sqlite3 *_db;
    dispatch_queue_t _queue;// ARC released
}

+ (instancetype)sharedInstance {
    static FXSyncStore *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FXSyncStore alloc] init];
    });
    return instance;
}

- (id)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("FXStore", DISPATCH_QUEUE_SERIAL);
        [self _openDB];
    }
    return self;
}

- (void)dealloc {
    dispatch_sync(_queue, ^{
        sqlite3_close(_db);
        _db = NULL;
    });
    _queue = NULL;
}

- (void)_openDB {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                  NSUserDomainMask,
                                                                  YES) lastObject];
    NSString *databasePath = [documentsDir stringByAppendingPathComponent:kFXSyncStoreFile];
    
    /* DB already exists */
    BOOL exists = [fm fileExistsAtPath:databasePath];
    if (sqlite3_open([databasePath UTF8String], &_db) == SQLITE_OK) {
        if (!exists) {
            DLog(@"Creating DB at %@", databasePath);
            [self _createTables];
        } else {
            DLog(@"Existing DB found, using %@", databasePath);
        }
    } else {
        DLog(@"Could not open database!");
        @throw [NSException exceptionWithName:kFXSyncStoreException
                                       reason:@"Could not open database!"
                                     userInfo:nil];
    }
}

- (void)loadCollection:(NSString *)cName
                 limit:(NSUInteger)limit
              callback:(void(^)(NSMutableArray *))block {
    NSParameterAssert(cName && block);
    
    dispatch_async(_queue, ^{
        // TODO allow a flexible limit
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE modified != %ld ORDER BY sortindex DESC",
                         cName, (long)kFXSyncItemDeleted];
        if (limit > 0) {
            sql = [sql stringByAppendingFormat:@" LIMIT %lud", (unsigned long)limit];
        }
        
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmnt, NULL) == SQLITE_OK) {
            NSMutableArray *arr = [self _readSyncItems:stmnt collection:cName];
            block(arr);
        } else {
            [self _throwDBError];
        }
    });
}

- (void)loadSyncId:(NSString *)syncId
    fromCollection:(NSString *)cName
          callback:(void (^)(FXSyncItem *))block {
    NSParameterAssert(syncId && cName && block);
    
    dispatch_async(_queue, ^{
        // TODO allow a flexible limit
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE syncId = ?", cName];
        
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmnt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmnt, 1, [syncId UTF8String],
                              (int)syncId.length, SQLITE_TRANSIENT);
            NSArray *arr = [self _readSyncItems:stmnt collection:cName];
            block([arr lastObject]);
        } else {
            [self _throwDBError];
        }
    });

}

- (void)saveItem:(FXSyncItem *)item {
    NSParameterAssert(item.collection && item.syncId);
    dispatch_async(_queue, ^{
        
        NSString *sql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (syncId, modified, sortindex, payload)"
                         " VALUES (?, ?, ?, ?)", item.collection];
        
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmnt, NULL) == SQLITE_OK) {
            
            sqlite3_bind_text(stmnt, 1, [item.syncId UTF8String],
                              (int)item.syncId.length, SQLITE_TRANSIENT);
            sqlite3_bind_double(stmnt, 2, item.modified);
            sqlite3_bind_int(stmnt, 3, (int)item.sortindex);
            sqlite3_bind_text(stmnt, 4, [item.payload bytes],
                              (int)[item.payload length], SQLITE_TRANSIENT);
            sqlite3_step(stmnt);
        }
        if (sqlite3_finalize(stmnt) != SQLITE_OK) {
            [self _throwDBError];
        }
    });
}

- (void)deleteItem:(FXSyncItem *)item {
    dispatch_async(_queue, ^{
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE syncId = ?", item.collection];

        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmnt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmnt, 1, [item.syncId UTF8String],
                              (int)item.syncId.length, SQLITE_TRANSIENT);
            sqlite3_step(stmnt);
        }
        if (sqlite3_finalize(stmnt) != SQLITE_OK) {
            [self _throwDBError];
        }
    });
}

#pragma mark - Clearing data

- (void)clearMetadata; {
    dispatch_async(_queue, ^{
        sqlite3_exec(_db, "DELETE FROM syncinfo", NULL, NULL, NULL);
    });
}

- (void)clearData {
    [self clearMetadata];
    NSArray *all = [FXSyncEngine collectionNames];
    for (NSString *cName in all) {
        [self clearCollection:cName older:time(NULL)];
    }
}

- (void)clearCollection:(NSString *)cName older:(NSTimeInterval)cutoff; {
    dispatch_async(_queue, ^{
        // We use -1 to mark edited stuff
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE modified BETWEEN 0 AND %.2f", cName, cutoff];
        sqlite3_exec(_db, sql.UTF8String, NULL, NULL, NULL);
    });
}


#pragma mark - Handling Metadata

- (NSArray *)changedItemsForCollection:(NSString *)cName {
    __block NSArray *result;
    dispatch_sync(_queue, ^{
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE modified < 0", cName];
        
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmnt, NULL) == SQLITE_OK) {
            result = [self _readSyncItems:stmnt collection:cName];
        }
    });
    return result;
}

- (NSTimeInterval)syncTimeForCollection:(NSString *)collection {
    __block NSTimeInterval result = 0;
    dispatch_sync(_queue, ^{
        const char sql[] = "SELECT * FROM syncinfo WHERE collection = ?";
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql, -1, &stmnt, NULL) == SQLITE_OK) {
            
            sqlite3_bind_text(stmnt, 1, [collection UTF8String],
                              (int)[collection length], SQLITE_TRANSIENT);
            if (sqlite3_step(stmnt) == SQLITE_ROW) {
                result = sqlite3_column_double(stmnt, 1);
            }
            
        }
        if (sqlite3_finalize(stmnt) != SQLITE_OK) {
            [self _throwDBError];
        }
    });
    return result;
}

- (void)setSyncTime:(NSTimeInterval)modified forCollection:(NSString *)collection; {
    dispatch_async(_queue, ^{
        const char sql[] = "INSERT OR REPLACE INTO syncinfo (collection, modified) VALUES (?, ?);";
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql, -1, &stmnt, NULL) == SQLITE_OK) {
            
            sqlite3_bind_text(stmnt, 1, [collection UTF8String],
                              (int)[collection length], SQLITE_TRANSIENT);
            sqlite3_bind_double(stmnt, 2, modified);
            sqlite3_step(stmnt);
        }
        if (sqlite3_finalize(stmnt) != SQLITE_OK) {
            [self _throwDBError];
        }
    });
}

#pragma mark - Internal Helpers

/*! Load all rows and put them into FXSyncItem objects. Calls sqlite3_finalize(stmnt) */
- (NSMutableArray *)_readSyncItems:(sqlite3_stmt *)stmnt collection:(NSString *)cName {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:100];
    
    while (sqlite3_step(stmnt) == SQLITE_ROW) {
        
        FXSyncItem *item = [FXSyncItem new];
        item.collection = cName;
        item.syncId = [[NSString alloc] initWithBytes:sqlite3_column_text(stmnt, 0)
                                               length:sqlite3_column_bytes(stmnt, 0)
                                             encoding:NSUTF8StringEncoding];
        item.modified = sqlite3_column_double(stmnt, 1);
        item.sortindex = sqlite3_column_int(stmnt, 2);
        item.payload = [NSData dataWithBytes:sqlite3_column_text(stmnt, 3)
                                      length:sqlite3_column_bytes(stmnt, 3)];
        [items addObject:item];
    }
    if (sqlite3_finalize(stmnt) != SQLITE_OK) {
        [self _throwDBError];
    }
    return items;
}

- (void)_createTables {
    
    NSArray *all = [FXSyncEngine collectionNames];
    for (NSString *cName in all) {
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE %@ (syncId TEXT PRIMARY KEY, "
                         "modified REAL, sortindex INTEGER, payload TEXT)", cName];
        char *err = NULL;
        sqlite3_exec(_db, sql.UTF8String, NULL, NULL, &err);
        if (err != NULL) {
            ELog([NSString stringWithCString:err encoding:NSUTF8StringEncoding]);
        }
    }
    
    const char sql2[] = "CREATE TABLE syncinfo (collection TEXT PRIMARY KEY, modified REAL)";
    sqlite3_exec(_db, sql2, NULL, NULL, NULL);
}

- (void)_throwDBError {
    const char *err = sqlite3_errmsg(_db);
    NSString *reason = [NSString stringWithCString:err encoding:NSUTF8StringEncoding];
    @throw [NSException exceptionWithName:kFXSyncStoreException
                                   reason:reason
                                 userInfo:nil];
}

@end
