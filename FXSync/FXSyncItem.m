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

- (NSMutableDictionary *)jsonPayload {
    if (_jsonPayload == nil && _payload != nil) {
        NSError *error = nil;
        _jsonPayload = [NSJSONSerialization JSONObjectWithData:_payload
                                                       options:NSJSONReadingMutableContainers
                                                         error:&error];
        ELog(error);
    }
    return _jsonPayload;
}

- (void)save {
    _modified = -1;//[[NSDate date] timeIntervalSince1970];
    if (_jsonPayload != nil) {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:_jsonPayload
                                                       options:0
                                                         error:&error];
        if (error == nil) {
            _payload = data;
            [[FXSyncStore sharedInstance] saveItem:self];
        } else {
            ELog(error);
        }
    } else {
        [[FXSyncStore sharedInstance] saveItem:self];
    }
}

- (void)deleteItem {
    if (_jsonPayload) {
        _jsonPayload[@"deleted"] = @YES;
        [self save];
    }
}

@end

@implementation FXSyncItem (CommonFormat)

/*! (For tabs) title string: title of the current page */
- (NSString *)title {
    id val = self.jsonPayload[@"title"];
    return val == [NSNull null] ? nil : val;
}
- (void)setTitle:(NSString *)title; {
    self.jsonPayload[@"title"] = title;
}

- (NSString *)urlString {
    // We rely on the assumption that these are
    // only present on different object types
    NSString *urlS = [self bmkUri];// bookmark
    if ([urlS length] == 0) urlS = [self histUri];// history entry
    if ([urlS length] == 0) urlS = [self siteUri];// livemark
    
    return urlS;
}

- (BOOL)deleted; {
    return [self.jsonPayload[@"deleted"] boolValue];
}

@end

@implementation FXSyncItem (TabFormat)

/*! tabs array of objects: each object describes a tab */
- (NSArray *)tabs; {
    return self.jsonPayload[@"tabs"];
}
/*! clientName string: name of the client providing these tabs */
- (NSString *)clientName; {
    id val = self.jsonPayload[@"clientName"];
    return val == [NSNull null] ? nil : val;
}

@end

@implementation FXSyncItem (BookmarkFormat)

// ===== Bookmarks =====

/*! bmkUri string uri of the page to load */
- (NSString *)bmkUri; {
    id val = self.jsonPayload[@"bmkUri"];
    return val == [NSNull null] ? nil : val;
}
- (void)setBmkUri:(NSString *)bmkUri; {
    self.jsonPayload[@"bmkUri"] = bmkUri;
}
/*! description string: extra description if provided */
- (NSString *)description; {
    id val = self.jsonPayload[@"description"];
    return val == [NSNull null] ? nil : val;
}
/*! tags array of strings: tags for the bookmark */
- (NSString *)tags; {
    id val = self.jsonPayload[@"tags"];
    return val == [NSNull null] ? nil : val;
}
/*! parentid string: GUID of the containing folder */
- (NSString *)parentid; {
    id val = self.jsonPayload[@"parentid"];
    return val == [NSNull null] ? nil : val;
}
- (void)setParentid:(NSString *)parentid {
    self.jsonPayload[@"parentid"] = parentid;
}
/*! string: name of the containing folder */
- (NSString *)parentName; {
    id val = self.jsonPayload[@"parentName"];
    return val == [NSNull null] ? nil : val;
}
- (void)setParentName:(NSString *)parentName; {
    self.jsonPayload[@"parentName"] = parentName;
}
/*! bookmark */
- (NSString *)type; {
    id val = self.jsonPayload[@"type"];
    return val == [NSNull null] ? nil : val;
}
- (void)setType:(NSString *)type; {
    self.jsonPayload[@"type"] = type;
}

/*! siteUri string: site associated with the livemark */
- (NSString *)siteUri; {
    id val = self.jsonPayload[@"siteUri"];
    return val == [NSNull null] ? nil : val;
}
- (void)setSiteUri:(NSString *)siteUri; {
    self.jsonPayload[@"siteUri"] = siteUri;
}
/*! feedUri string: feed to get items for the livemark */
- (NSString *)feedUri; {
    id val = self.jsonPayload[@"feedUri"];
    return val == [NSNull null] ? nil : val;
}
- (void)setFeedUri:(NSString *)feedUri; {
    self.jsonPayload[@"feedUri"] = feedUri;
}

@end

@implementation FXSyncItem (FolderFormat)

- (NSArray *)children; {
    id val = self.jsonPayload[@"children"];
    return val == [NSNull null] ? nil : val;
}
- (void)addChild:(NSString *)syncId; {
    if (self.jsonPayload[@"children"]
        && self.jsonPayload[@"children"] != [NSNull null]) {
        [self.jsonPayload[@"children"] addObject:syncId];
    } else {
        self.jsonPayload[@"children"] = @[syncId];
    }
}

@end

@implementation FXSyncItem (HistoryFormat)

// ====== History ====
/*! string: uri of the page */
- (NSString *)histUri; {
    id val = self.jsonPayload[@"histUri"];
    return val == [NSNull null] ? nil : val;
}

@end