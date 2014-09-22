//
//  FXSyncStore.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 14.06.14.
//  Copyright (c) 2014 Simon Peter Grätzer. All rights reserved.
//

#import "FXSyncStore.h"
#import "FXSyncEngine.h"
#import "FXSyncItem.h"

NSString *const kFXSyncStoreFile = @"storage.db";
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
        [self _closeDB];
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

- (void)_closeDB {
    dispatch_sync(_queue, ^{
        sqlite3_close(_db);
        _db = NULL;
    });
}

//- (void)_loadData {
//    NSArray *all = [FXSync collectionNames];
//    for (NSString *name in all) {
//        [self _loadCollection:name limit:0];
//    }
//}

- (NSArray *)_loadCollection:(NSString *)cName limit:(int)limit {
    const char sql[] = "SELECT * FROM ? ORDER BY sortindex DESC LIMIT ?;";
    
    sqlite3_stmt *stmnt = nil;
	if (sqlite3_prepare_v2(_db, sql, -1, &stmnt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmnt, 1, [cName UTF8String],
                          (int)cName.length, SQLITE_TRANSIENT);
        sqlite3_bind_int(stmnt, 2, limit);
        
        return [self _readSyncItems:stmnt collection:cName];
	} else {
        [self _throwDBError];
        return nil;
    }
}

- (void)_createTables {
    const char sql[] = "CREATE TABLE ? (syncId TEXT PRIMARY KEY, "
    "modified REAL, sortindex INTEGER, payload TEXT);";
    
    sqlite3_stmt *stmnt = nil;
	if (sqlite3_prepare_v2(_db, sql, -1, &stmnt, NULL) != SQLITE_OK) {
		DLog(@"Could not prepare history item statement");
	} else {
        
        NSArray *all = [FXSyncEngine collectionNames];
        for (NSString *name in all) {
            sqlite3_bind_text(stmnt, 1, [name UTF8String], -1, SQLITE_TRANSIENT);
            
            int res = sqlite3_step(stmnt);
            if (res != SQLITE_ROW || res != SQLITE_DONE) {
                [self _throwDBError];
            }
            sqlite3_reset(stmnt);
        }
        sqlite3_finalize(stmnt);
    }

    const char sql2[] = "CREATE TABLE syncinfo (collection TEXT PRIMARY KEY, modified REAL)";
    sqlite3_exec(_db, sql2, NULL, NULL, NULL);
}

- (void)saveItem:(FXSyncItem *)item {
    dispatch_async(_queue, ^{
        
        const char sql[] = "INSERT OR REPLACE INTO ? (syncId, modified, sortindex, payload)"
        " VALUES (?, ?, ?, ?, ?);";
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql, -1, &stmnt, NULL) == SQLITE_OK) {
            
            sqlite3_bind_text(stmnt, 1, [item.collection UTF8String],
                              (int)[item.collection length], SQLITE_TRANSIENT);
            
            sqlite3_bind_text(stmnt, 2, [item.syncId UTF8String],
                              (int)item.syncId.length, SQLITE_TRANSIENT);
            sqlite3_bind_double(stmnt, 3, item.modified);
            sqlite3_bind_int(stmnt, 4, (int)item.sortindex);
            sqlite3_bind_text(stmnt, 5, [item.payload bytes],
                              (int)[item.payload length], SQLITE_TRANSIENT);
            if (sqlite3_step(stmnt) != SQLITE_DONE) {
                [self _throwDBError];
            }
        }
        if (sqlite3_finalize(stmnt) != SQLITE_OK) {
            [self _throwDBError];
        }
    });
}

- (void)deleteItem:(FXSyncItem *)item {
    dispatch_async(_queue, ^{
        const char sql[] = "DELETE FROM ? WHERE syncId = ?";
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql, -1, &stmnt, NULL) == SQLITE_OK) {
            
            sqlite3_bind_text(stmnt, 1, [item.collection UTF8String],
                              (int)[item.collection length], SQLITE_TRANSIENT);
            sqlite3_bind_text(stmnt, 2, [item.syncId UTF8String],
                              (int)item.syncId.length, SQLITE_TRANSIENT);
            if (sqlite3_step(stmnt) != SQLITE_DONE) {
                [self _throwDBError];
            }
        }
        if (sqlite3_finalize(stmnt) != SQLITE_OK) {
            [self _throwDBError];
        }
    });
}
- (NSArray *)modifiedItems:(NSString *)cName {
    __block NSArray *result;
    dispatch_sync(_queue, ^{
        const char sql[] = "SELECT * FROM ? WHERE modified < 0;";
        
        sqlite3_stmt *stmnt = nil;
        if (sqlite3_prepare_v2(_db, sql, -1, &stmnt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmnt, 1, [cName UTF8String],
                              (int)cName.length, SQLITE_TRANSIENT);
            result = [self _readSyncItems:stmnt collection:cName];
        }
    });
    return result;
}

/*! Load all rows and put them into FXSyncItem objects. Calls sqlite3_finalize(stmnt) */
- (NSArray *)_readSyncItems:(sqlite3_stmt *)stmnt collection:(NSString *)cName {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:100];
    
    while (sqlite3_step(stmnt) == SQLITE_ROW) {
        
        FXSyncItem *item = [FXSyncItem new];
        item.syncId = [[NSString alloc] initWithBytes:sqlite3_column_text(stmnt, 0)
                                               length:sqlite3_column_bytes(stmnt, 0)
                                             encoding:NSUTF8StringEncoding];
        item.modified = sqlite3_column_double(stmnt, 1);
        item.sortindex = sqlite3_column_int(stmnt, 2);
        item.payload = [NSData dataWithBytes:sqlite3_column_text(stmnt, 3)
                                      length:sqlite3_column_bytes(stmnt, 3)];
        item.collection = cName;
        [items addObject:item];
    }
    if (sqlite3_finalize(stmnt) != SQLITE_OK) {
        [self _throwDBError];
    }
    return items;
}

- (NSTimeInterval)lastModifiedForCollection:(NSString *)collection {
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

- (void)setLastModifiedForCollection:(NSString *)collection modified:(NSTimeInterval)modified {
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

- (void)_throwDBError {
    const char *err = sqlite3_errmsg(_db);
    NSString *reason = [NSString stringWithCString:err encoding:NSUTF8StringEncoding];
    @throw [NSException exceptionWithName:kFXSyncStoreException
                                   reason:reason
                                 userInfo:nil];
}

@end

@implementation FXSyncAction


@end
