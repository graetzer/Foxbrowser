/***** BEGIN LICENSE BLOCK *****
 Version: MPL 1.1/GPL 2.0/LGPL 2.1
 
 The contents of this file are subject to the Mozilla Public License Version 
 1.1 (the "License"); you may not use this file except in compliance with 
 the License. You may obtain a copy of the License at 
 http://www.mozilla.org/MPL/
 
 Software distributed under the License is distributed on an "AS IS" basis,
 WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 for the specific language governing rights and limitations under the
 License.
 
 The Original Code is weave-iphone.
 
 The Initial Developer of the Original Code is Mozilla Labs.
 Portions created by the Initial Developer are Copyright (C) 2009
 the Initial Developer. All Rights Reserved.
 
 Contributor(s):
	Anant Narayanan <anant@kix.in>
	Dan Walkowski <dwalkowski@mozilla.com>

 Alternatively, the contents of this file may be used under the terms of either
 the GNU General Public License Version 2 or later (the "GPL"), or the GNU
 Lesser General Public License Version 2.1 or later (the "LGPL"), in which case
 the provisions of the GPL or the LGPL are applicable instead of those above.
 If you wish to allow use of your version of this file only under the terms of
 either the GPL or the LGPL, and not to allow others to use your version of
 this file under the terms of the MPL, indicate your decision by deleting the
 provisions above and replace them with the notice and other provisions
 required by the GPL or the LGPL. If you do not delete the provisions above, a
 recipient may use your version of this file under the terms of any one of the
 MPL, the GPL or the LGPL.
 
 ***** END LICENSE BLOCK *****/

#import "Stockboy.h"
#import "Store.h"
#import "Fetcher.h"
#import "Reachability.h"
#import "Utility.h"
#import "WeaveService.h"
#import "CryptoUtils.h"
#import "RegexKitLite.h"
#import "NSString+Decoding.h"
#import "NSString+SBJSON.h"

#import "GAI.h"

//we will completely refresh the top MAX_HISTORY_ITEMS only once a day.  In the interim, we tack on anything that has changed,
// regardless of frecency rating
#define HISTORY_FULL_REFRESH_INTERVAL (60 /*seconds*/   *   60 /*minutes*/   *  24  /*hours*/)

@interface Stockboy (PRIVATE)

- (NSData *) extractBulkKeyFrom:(NSData*)bulkKeyData withURL:(NSString*)keyURL;

// called by the restock method on the gStockboy to start the thread
- (void) start;
// instance method, to hide the actual thread
- (void) cancel;

//returns the isCancelled flag of the stockboy thread.
// called as often as possible, so we can exit gracefully
- (BOOL) isCancelled;

// these should probably return something useful
- (void) updateTabs;
- (void) checkCryptoKeys;
- (void) updateBookmarks;
- (void) updateHistory;

-(Stockboy *) initWithCryptoManager:(CryptoUtils*)cryptoManager;

//these are cutoffs, preventing memory exhaustion.
//we won't download or process any more than these numbers
- (int) maxHistoryItemCount;
- (int) maxBookmarkCount; //not actually doing anything

@end

@implementation Stockboy

// Boolean indicating whether a thread is syncing now.  protected by the condition below.
static BOOL _gSyncInProgress;

// Condition used to manage access to _gSyncInProgress
static NSCondition *_gSyncLock;

// The singleton instance, if it exists
static Stockboy *_gStockboy = nil;

// public resource, needed by more than one class
static NSDictionary *_gNetworkPaths = nil;

// CLASS METHODS

//call this ONCE, immediately at startup
+ (void) prepare
{
  _gSyncLock = [[NSCondition alloc] init];
  _gSyncInProgress = NO;
}

+ (NSCondition*) syncLock { return _gSyncLock;}
+ (BOOL)syncInProgress { return _gSyncInProgress;}
+ (void)setSyncInProgress:(BOOL)newVal {_gSyncInProgress = newVal;}

+ (void) restock {
  //if there is already one running, then do nothing
  
  [_gSyncLock lock];
  if (!_gSyncInProgress) {
    [weaveService performSelectorOnMainThread:@selector(startProgressSpinnersWithMessage:)
                                   withObject:NSLocalizedString(@"connecting", @"connecting")
                                waitUntilDone:NO];
    
    _gStockboy = [[Stockboy alloc] init];
    _gSyncInProgress = YES;
    [_gStockboy start];
  }
  
  [_gSyncLock signal];
  [_gSyncLock unlock];
}


// cancel the thread!
+ (void) cancel
{
  if (_gStockboy != nil)
    [_gStockboy cancel];
}

//returns the isCancelled flag of the stockboy thread.
// called as often as possible, so we can exit gracefully
+ (BOOL) isCancelled
{
  if (_gStockboy != nil) 
    return [_gStockboy isCancelled];
  
  return YES;
}



//class utility functions

+(NSString*) getURIForKey:(NSString*)name
{
	if (_gNetworkPaths == nil) {
		NSString *error = nil;
		NSPropertyListFormat format;
		NSString *pathtoPaths = [[NSBundle mainBundle] pathForResource:@"NetworkPaths" ofType:@"plist"];
		NSData *pathsXML = [[NSFileManager defaultManager] contentsAtPath:pathtoPaths];
		NSDictionary *thePaths = (NSDictionary *)[NSPropertyListSerialization
                                              propertyListFromData:pathsXML
                                              mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                              format:&format errorDescription:&error];
    
		if (!thePaths) {
			NSLog(@"%@", error);
			[error release];
			_gNetworkPaths = nil;
			return nil;
		} else {
			_gNetworkPaths = [thePaths retain];
		}
	}
	return _gNetworkPaths[name];
}


////INSTANCE METHODS//

- (Stockboy *) init 
{
	if (self = [super init]) {
        _stockboyThread = [[NSThread alloc] initWithTarget:self selector:@selector(restockEverything) object:nil];
	}
	return self;
}

- (void)dealloc
{
  [super dealloc];
}

// called by the restock method on the gStockboy to start the thread
- (void) start;
{
  if (_stockboyThread) [_stockboyThread start];
}

// instance method, to hide the actual thread
- (void) cancel
{
  if (_stockboyThread) [_stockboyThread cancel];
}

//returns the isCancelled flag of the stockboy thread.
// called as often as possible, so we can exit gracefully
- (BOOL) isCancelled
{
  if (_stockboyThread)
    return [_stockboyThread isCancelled];
  else return YES;
}



// this is the task list for a sync.  get the cluster, then sync the tabs, bookmarks, history, and favicons
// we do this one thing at a time, with synchronous network calls, because we are doing it all in a dedicated thread.
// we check between tasks, (and during, for long ones), if our thread has been cancelled, so that we can exit promptly
-(void) restockEverything
{
  //need a scoped, autoreleased memory pool
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  

  //set the flag to "A-ok boss!"
  syncCompletedSuccessfully = YES;
  
  [weaveService performSelectorOnMainThread:@selector(changeProgressSpinnersMessage:)
                                 withObject:NSLocalizedString(@"Authorizing", @"Authorizing")
                              waitUntilDone:NO];
  
  if ([weaveService canConnectToInternet]) 
  {   
    //display the info we've got to start with
    [weaveService performSelectorOnMainThread:@selector(refreshViews) withObject:nil waitUntilDone:NO];

    @try
    {
      [CryptoUtils createManager];  //if one already exists, this does nothing.
              
      //update the cluster, in case it has moved
      if ([CryptoUtils getManager] == nil || ![[CryptoUtils getManager] updateCluster])
      {
        [self cancel];
      }
      
	  // Check if the storage version has changed. This is true if the storage version that updateCluster
	  // just got is 5 and we have the old style private key in the keychain.
	  
		if ([[CryptoUtils getManager] storageVersion] == 5 && [[CryptoUtils getManager] privateKey] != NULL)
		{
			syncCompletedSuccessfully = NO;
			[self cancel];

			//ask the user what to do.  try again?  go to login screen?
			NSDictionary* errInfo = @{@"title": NSLocalizedString(@"Cannot Sync", @"Cannot Sync"), 
			@"message": NSLocalizedString(@"Due to a recent update, you need to log in to Foxbrowser again.",
				"Due to a recent update, you need to log in to Foxbrowser again.")};

			[weaveService performSelectorOnMainThread:@selector(reportAuthErrorWithMessage:) withObject:errInfo waitUntilDone:NO];
		}
		else
		{		
		  if (![self isCancelled])
		  {
			[weaveService performSelectorOnMainThread:@selector(changeProgressSpinnersMessage:)
                                           withObject:NSLocalizedString(@"tabs", @"tabs")
                                        waitUntilDone:NO];
			if ([[CryptoUtils getManager] storageVersion] >= 5) {
				[self checkCryptoKeys];
			}
			[self updateTabs];
			[weaveService performSelectorOnMainThread:@selector(refreshViews) withObject:nil waitUntilDone:NO];
		  }
		  
		  if (![self isCancelled])
		  {
			[weaveService performSelectorOnMainThread:@selector(changeProgressSpinnersMessage:)
                                           withObject:NSLocalizedString(@"Bookmarks", @"Bookmarks")
                                        waitUntilDone:NO];
			[self updateBookmarks];
			[weaveService performSelectorOnMainThread:@selector(refreshViews) withObject:nil waitUntilDone:NO];
		  }
		  
		  if (![self isCancelled])
		  {
			[weaveService performSelectorOnMainThread:@selector(changeProgressSpinnersMessage:)
                                           withObject:NSLocalizedString(@"history", @"history")
                                        waitUntilDone:NO];
			[self updateHistory];
			[weaveService performSelectorOnMainThread:@selector(refreshViews) withObject:nil waitUntilDone:NO];
		  }
		}
	} @catch (NSException * e)  {
      //only report auth and passphrase exceptions, ignore others, and just cancel the sync
      syncCompletedSuccessfully = NO;
      [self cancel];

        NSDictionary* errInfo = nil;
        
      if ([e.name isEqualToString:AUTH_EXCEPTION_STRING]) {
        //ask the user what to do.  try again?  go to login screen?
        errInfo = @{@"title": NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), 
                                 @"message": NSLocalizedString(@"Incorrect Password", "incorrect password")};
        
        [weaveService performSelectorOnMainThread:@selector(reportAuthErrorWithMessage:) withObject:errInfo waitUntilDone:NO];
      } else if ([e.name isEqualToString:PASSPHRASE_EXCEPTION_STRING]) {
        //ask the user what to do.  try again?  go to login screen?
        errInfo = @{@"title": NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), 
                                 @"message": NSLocalizedString(@"Incorrect Secret Phrase", "incorrect secret phrase")};
        
        [weaveService performSelectorOnMainThread:@selector(reportAuthErrorWithMessage:) withObject:errInfo waitUntilDone:NO];
      } else  {
        //some non-crypto related exception, like server unreachable, etc.
        //just alert the user to the problem, and tell them to try again later
        NSString *message = NSLocalizedString(@"Unable to contact server", "server unavailable");
        if ([e reason]) message = [e reason];
        errInfo = @{@"title": NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), 
                                 @"message": message};
        
        [weaveService performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];
      }
        
        //[[GAI sharedInstance].defaultTracker sendException:NO withDescription:@"Stockboy: %@ - %@", errInfo[@"title"], errInfo[@"message"]];
        [appDelegate.tracker send:[[GAIDictionaryBuilder createExceptionWithDescription:
                                    [NSString stringWithFormat:@"Stockboy: %@ - %@", errInfo[@"title"], errInfo[@"message"]]
                                                                              withFatal:@NO] build]];
    }
  } else {
    //no connectivity, put up alert
    NSDictionary* errInfo = @{@"title": NSLocalizedString(@"Cannot Sync", @"unable to refresh data"), 
                             @"message": NSLocalizedString(@"No internet connection available", "no internet connection")};
    [weaveService performSelectorOnMainThread:@selector(reportErrorWithInfo:) withObject:errInfo waitUntilDone:NO];
  }
  

  [weaveService performSelectorOnMainThread:@selector(stopProgressSpinners) withObject:nil waitUntilDone:NO];

  [pool drain];
  [self release];  //refcount = 0
  _gStockboy = nil;
  
  [_gSyncLock lock];
  _gSyncInProgress = NO;
  [_gSyncLock signal];
  [_gSyncLock unlock];
}

//MIGHT THROW password or passphrase exception
-(void) updateTabs
{  
	// Don't need to check timestamp.
	// We always get all the tabs, regardless of any timestamp. 
	// synchronous request.  we are running in a separate thread, so it's ok to block.
  
  NSData* tabs = [Fetcher getWeaveBasicObject:[Stockboy getURIForKey:@"Tabs Path"] authenticatingWith:[CryptoUtils getManager]];

  if (tabs == nil || [tabs length] == 0) 
    return; //better error handling
  
  if ([self isCancelled]) return;
  
	// this will hold all the resultant decrypted tabs
	NSMutableDictionary *userTabSets = [NSMutableDictionary dictionary];
  
	// This bit of primitive parsing relies on the data coming as a dictionary of dictionaries.
	// beware of 'does not understand' exceptions
	NSString *tabsString = [[[NSString alloc] initWithData:tabs encoding:NSUTF8StringEncoding] autorelease];
	NSDictionary *tabsDict = [tabsString JSONValue];
  
  //if JSON parsing failed, we need to exit
  if (tabsDict == nil || [tabsDict count] == 0) return; 

	NSEnumerator *tabIterator = [tabsDict objectEnumerator];
  
	NSDictionary *tabBundle;
	while (tabBundle = [tabIterator nextObject]) 
  {
    if (tabBundle == nil)
    {
      NSLog(@"nil tab bundle");
      continue;
    }

    //check to see if thread is cancelled, before each potential network request
    if ([self isCancelled]) return;

    // a tab set is a dictionary of tabs for a client.  each tab is also a dictionary
    NSDictionary* tabSet = [[CryptoUtils getManager] decryptDataObject:tabBundle mustVerify:YES];

    if (tabSet)
    {
      userTabSets[tabSet[@"id"]] = tabSet;
    }
    else
    {
      NSLog(@"tabset was nil");
      return;
    }
	}
	
	// Ok, now we have all the tabs, decrypted, so tell the Store to install them and flush the cache
  [[Store getStore] installTabSetDictionary:userTabSets];
  
}

// Grab the keys. This is part of a workaround for 628338 - Ignore records that do not decrypt correctly. Since we
// ignore bad records we don't find out about sync key changes anymore. This is why we do this check. If it fails
// then we assume that that the sync key has changed and that the user needs to login again.

- (void) checkCryptoKeys
{
	KeychainItemWrapper* passphraseItemWrapper = [[[KeychainItemWrapper alloc] initWithIdentifier: @"Passphrase" accessGroup:nil] autorelease];
	if (passphraseItemWrapper != nil)
	{
		NSString* passphrase = [NSString stringWithString: [passphraseItemWrapper objectForKey: (id) kSecValueData]];
		NSData* passphraseData = nil;
		
		if ([passphrase length] == 26) {
			passphraseData = [passphrase userfriendlyBase32Decoding];
		} else if ([passphrase isMatchedByRegex: @"^(?i)[A-Z2-9]{1}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}$"]) {
			passphrase = [passphrase stringByReplacingOccurrencesOfString: @"-" withString: @""];
			passphraseData = [passphrase userfriendlyBase32Decoding];
		}
		
		if (passphraseData != nil)
		{
			NSDictionary* keys = [[CryptoUtils getManager] downloadKeysWithUsername: [[CryptoUtils getManager] accountName] passphraseData: passphraseData];
			if (keys == nil) {
				NSException *e = [NSException exceptionWithName:PASSPHRASE_EXCEPTION_STRING
					reason:NSLocalizedString(@"Incorrect Secret Phrase", @"incorrect secret phrase") userInfo:nil];
				@throw e;
			}
		}
	}
}



//This method consists almost entirely of unwrapping the nested JSON objects and getting out
// the bookmark/folder entries and putting them into two piles: add/update and delete, and then
// sending them off to the Store to be added and removed frmo the database

//MIGHT THROW password or passphrase exception
-(void) updateBookmarks
{
	NSString *bmarksURL = [NSString stringWithFormat:[Stockboy getURIForKey:@"Bookmarks Update Path"], [[Store getStore] getTimestamp:@"bookmarks"]];
  NSData* receivedUTF8Bytes = nil;
  
  receivedUTF8Bytes = [Fetcher getWeaveBasicObject:bmarksURL authenticatingWith:[CryptoUtils getManager]];
  
  //if for some other reason we didn't get any bytes, we're going to jsut fail out of here quietly
	if (receivedUTF8Bytes == nil || [receivedUTF8Bytes length] == 0) return; //better error handling
  
  //check to see if thread is cancelled, before each potential network request
  if ([self isCancelled]) return;

	// This will hold all the resultant decrypted bookmarks that need to be added
	NSMutableArray *bookmarksToBeAdded = [NSMutableArray array];

	// This will hold all the resultant decrypted bookmarks that need to be deleted
	NSMutableArray *bookmarksToBeDeleted = [NSMutableArray array];

	// Unpack the bookmarks
	NSString *receivedBytesAsString = [[[NSString alloc] initWithData:receivedUTF8Bytes encoding:NSUTF8StringEncoding] autorelease];
	NSDictionary *listOfBookmarkEntries = [receivedBytesAsString JSONValue];
  //if the JSON parser had trouble, we want to get out of here and not do anything
  if (listOfBookmarkEntries == nil || [listOfBookmarkEntries count] == 0) return; 
  
	NSEnumerator *bookmarkEntryIterator = [listOfBookmarkEntries objectEnumerator];

	NSDictionary* bookmarkEntry;
	while (bookmarkEntry = [bookmarkEntryIterator nextObject]) 
  {
    //check to see if thread is cancelled, before each potential network request
    if ([self isCancelled]) return;
    
    NSMutableDictionary* bookmarkObject = [[CryptoUtils getManager] decryptDataObject:bookmarkEntry mustVerify:YES];

    if (bookmarkObject)
    {
      if ([bookmarkObject[@"deleted"] boolValue] == YES)
      {
        [bookmarksToBeDeleted addObject:bookmarkObject];
      }
      else 
      {
        //now we just need to copy the few fields we need from the metadata
        bookmarkObject[@"modified"] = bookmarkEntry[@"modified"];
        if (bookmarkEntry[@"sortindex"])
        {
          bookmarkObject[@"sortindex"] = bookmarkEntry[@"sortindex"];
        }
        else 
        {
          bookmarkObject[@"sortindex"] = @0;
        }

        
        [bookmarksToBeAdded addObject:bookmarkObject];
      }
    }
    else 
    {
      NSLog(@"failed to decrypt bookmark, but private key appears to be ok, continuing");
    }

	}
  
  //check to see if thread is cancelled, before we open the database transaction and commit everything
  if ([self isCancelled]) return;
  
  [[Store getStore] updateBookmarksAdding: bookmarksToBeAdded andRemoving: bookmarksToBeDeleted];
}


//I've changed the meaning somewhat of history and the items involved.
// It no longer tries to update the entries in-place, since they might not be 
// in the most frecent list.  I'm now making the server always return me <=5000 of
// the top ranked hits, and always overwriting the db with what I get back.
// So there doesn't seem to be any need for deleting items, so I'll comment it out for now.

//MIGHT THROW password or passphrase exception
-(void) updateHistory
{  
  //For performance reasons, ie: not crashing, I've implemented a system similar to Fennec, in that I am only syncing at most N (currently defined as 2000) history items,
  // ordered by sortIndex, which is approximately frecency.  This way we provide the user with the 'best' N history items.
  //However, since frecency numbers are only infrequently updated on the server, we are only going to proceed with updating, (replacing), the users
  // history every HISTORY_FULL_REFRESH_INTERVAL, since it can be an expensive operation.
  
  double lastSync = [[Store getStore] getTimestamp:@"history"];
  double lastFullSync = [[Store getStore] getTimestamp:@"fullhistory"];
  double now = [[NSDate date] timeIntervalSince1970];

  NSString *historyURL = nil;
  BOOL fullRefresh = NO;

  //too soon, no point in syncing, so just bail
  if (now - lastFullSync < HISTORY_FULL_REFRESH_INTERVAL)
  {
    //we just update with the most recent history items, regardless of frecency
    historyURL = [NSString stringWithFormat:[Stockboy getURIForKey:@"History Incremental Update Path"], lastSync];
  }
  else 
  {
    //it has been a long time since we updated, so we do a full update
    historyURL = [NSString stringWithFormat:[Stockboy getURIForKey:@"History Full Refresh Path"], [self maxHistoryItemCount]];
    fullRefresh = YES;
  }

  	
  NSData* history = nil;

  history = [Fetcher getWeaveBasicObject:historyURL authenticatingWith:[CryptoUtils getManager]];
  
  if (history == nil || [history length] == 0) return; //need better error handling
  
  //check to see if our thread is cancelled
  if ([self isCancelled]) return;
  
	// this will hold all the resultant decrypted history entries that need to be added
	NSMutableArray *historyItemsToBeAdded = [NSMutableArray array];
  
	// this will hold all the resultant decrypted history entries that need to be deleted
	NSMutableArray *historyItemstoBeDeleted = [NSMutableArray array];
	
	// unpack the history entries
	NSString *historyString = [[[NSString alloc] initWithData:history encoding:NSUTF8StringEncoding] autorelease];
	NSDictionary *historyDict = [historyString JSONValue];
    
  //if there was any trouble parsing the JSON, we need to leave
  if (historyDict == nil || [historyDict count] == 0) return; 

	NSEnumerator *historyIterator = [historyDict objectEnumerator];
	
	NSDictionary *historyEntry;
	while (historyEntry = [historyIterator nextObject]) 
  {
    //check to see if thread is cancelled, before each potential network request
    if ([self isCancelled]) return;

    NSMutableDictionary* historyObject = [[CryptoUtils getManager] decryptDataObject:historyEntry mustVerify:YES];
    
    if (historyObject)
    {
      if ([historyObject[@"deleted"] boolValue] == YES)
      {
        [historyItemstoBeDeleted addObject:historyObject];
      }
      else 
      {
        historyObject[@"modified"] = historyEntry[@"modified"];
        if (historyEntry[@"sortindex"])
        {
          historyObject[@"sortindex"] = historyEntry[@"sortindex"];
        }
        else 
        {
          historyObject[@"sortindex"] = @0;
        }
      
        [historyItemsToBeAdded addObject:historyObject];
      }
    }
    else 
    {
      NSLog(@"failed to decrypt history item, but private key appears to be ok, continuing");
    }

    
	}
  
  if ([self isCancelled]) return;

  [[Store getStore] updateHistoryAdding: historyItemsToBeAdded andRemoving: historyItemstoBeDeleted fullRefresh:fullRefresh];
}


- (int) maxHistoryItemCount
{
  NSString* platformString = [Utility platformString];
  
  if ([platformString isEqualToString:@"iPhone 1G"] ||
      [platformString isEqualToString:@"iPhone 3G"] ||
      [platformString isEqualToString:@"iPod Touch 1G"])
  {
    return 2000;  //devices with 128MB RAM
  }
  else
  {
    return 2000;  //devices with 256MB+ RAM
  }
}

- (int) maxBookmarkCount
{
  return 100000;  // basically infinite, for now.  I can't just stop installing them, they hierarchy will be borked.
}


@end

