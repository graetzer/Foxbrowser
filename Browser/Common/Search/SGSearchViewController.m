//
//  SGURLBarRecentsController.m
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import "SGSearchViewController.h"
#import "FXSyncStore.h"
#import "FXSyncStock.h"

#import "GAI.h"
#import "SGAppDelegate.h"


@implementation SGSearchViewController {
    NSString *_lastQuery;
    NSArray *_localResults;
    NSArray *_remoteResults;
}

static NSThread* gRefreshThread = nil;
static NSArray* gFreshSearchHits = nil;

- (void)viewDidLoad {
    [super viewDidLoad];
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        self.preferredContentSize = CGSizeMake(500., 280.);
    } else {
        self.contentSizeForViewInPopover = CGSizeMake(500., 280.);
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [gRefreshThread cancel];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    _localResults = gFreshSearchHits;
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([_lastQuery length]) {
        if (section == 0) {
            if (!_localResults && !_remoteResults) {
                return 1;
            } else {
                return [_localResults count];
            }
        } else if (section == 1) {
            return MIN([_remoteResults count], 5);
        } else if (section == 2) {
            return 1;//Search on page
        }
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1 && [_remoteResults count] > 0) {
        return NSLocalizedString(@"Search Suggestions", @"Remote search suggestions");
    }
    return nil;
}

// Display the strings in displayedRecentSearches.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2 && _lastQuery != nil) {
        static NSString *CellIdentifier = @"PAGE_SEARCH_CELL";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [UIColor blueColor];
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.imageView.image = [UIImage imageNamed:@"goto"];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.textLabel.text = [NSString stringWithFormat:@"%@: %@",
                               NSLocalizedString(@"Find in Page", @"Search something in the webpage"),
                               _lastQuery];
        return cell;
    } else {
        static NSString *CellIdentifier = @"URL_CELL";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
        }
        
        if (indexPath.section == 0) {
            if (!_localResults && !_remoteResults) {//no lists at all, means searching
                cell.textLabel.textColor = [UIColor grayColor];
                cell.textLabel.text = NSLocalizedString(@"Searching...", @"searching for matching items");
                cell.detailTextLabel.text = nil;
                cell.imageView.image = nil;
            } else {
                
                FXSyncItem* matchItem = _localResults[indexPath.row];
                NSString *uri = [matchItem urlString];
                
                cell.textLabel.textColor = [UIColor blackColor];
                // Set up the cell...
                if ([[matchItem title] length]) {
                    cell.textLabel.text = [matchItem title];
                    cell.detailTextLabel.text = uri;
                } else {
                    cell.textLabel.text = uri;
                    cell.detailTextLabel.text = nil;
                }
                //the item tells us which icon to use
                if ([matchItem.collection isEqualToString:kFXHistoryCollectionKey]) {
                    cell.imageView.image = [UIImage imageNamed:@"history"];
                } else {
                    // In any other case the bookmark has a type field
                    // We should have a corresponding image for that
                    cell.imageView.image = [UIImage imageNamed:[matchItem type]];
                }
            }
        } else {//section == 1
            NSString* matchItem = _remoteResults[indexPath.row];
            cell.textLabel.text = matchItem;
            cell.detailTextLabel.text = nil;
            cell.imageView.image = nil;
        }
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (gRefreshThread != nil) {
		[gRefreshThread cancel];
		gRefreshThread = nil;
	}
        
    if (indexPath.section == 0) {
        if ([_localResults count] > 0 && _lastQuery.length != 0) {
            FXSyncItem* matchItem = _localResults[[indexPath row]];
            NSString *uri = [matchItem urlString];
            [self.delegate finishSearch:uri title:[matchItem title]];
        }
    } else if (indexPath.section == 1) {
        if (!([_remoteResults count] == 0 && _lastQuery.length == 0)) {
            NSString* matchItem = _remoteResults[indexPath.row];
            [self.delegate finishSearch:matchItem title:matchItem];
        }
    } else if (indexPath.section == 2) {
        [self.delegate finishPageSearch:_lastQuery];
    }
    
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([self.delegate respondsToSelector:@selector(userScrolledSuggestions)])
     [self.delegate performSelector:@selector(userScrolledSuggestions)];
}

#pragma mark - Heavy search tasks, copied from Weave
- (void)filterResultsUsingString:(NSString*)query {
    //if there is a thread running, we need to stop it. it will autorelease
    if (gRefreshThread != nil) {
        [gRefreshThread cancel];
        gRefreshThread = nil;
    }
    
    if (!query || query.length == 0) {
        _lastQuery = nil;
        _localResults = nil;
        _remoteResults = nil;
        [self.tableView reloadData];
    } else {
        _lastQuery = query;
        //now fire up a new search thread
        gRefreshThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadRefreshHits:) object:query];
        [gRefreshThread start];
        [self _loadRemoteResults:query];
    }
}

- (void)_loadRemoteResults:(NSString *)query {
    if ([appDelegate canConnectToInternet]) {
        NSString *urlS = [NSString stringWithFormat:@"http://api.bing.com/osjson.aspx?query=%@",
                          [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:urlS]];
        [NSURLConnection sendAsynchronousRequest:req
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error){
                                   if (error == nil) {
                                       id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                       if ([json isKindOfClass:[NSArray class]] && [json count] > 1) {
                                           _remoteResults = json[1];
                                       } else {
                                           _remoteResults = nil;
                                       }
                                       
                                       [self.tableView reloadData];
                                   }
                                   ELog(error);
                               }];
    }
    
}

- (void) threadRefreshHits:(NSString*)searchText {
    @autoreleasepool {
        @try {
            [self refreshHits:searchText];
            if ([[NSThread currentThread] isCancelled]) {//we might be cancelled, because a better search came along, so don't display our results
                DLog(@"search thread was cancelled and replaced");
            } else {
                if (self.tableView) {// View might as well be gone
                    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                }
            }
        }
        @catch (NSException *e) {
            DLog(@"Failed to update search results: %@", e);
            NSString * desc = [NSString stringWithFormat:@"%@/%@", [e description], [e callStackSymbols]];
            id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
            [tracker send:[[GAIDictionaryBuilder
                            createExceptionWithDescription:desc
                            withFatal:@NO] build]];
        }
    }
}

#define MAXPERLIST 4

//This method works by side-effect.  It's complicated and rather ugly, but it was important not to have to
// duplicate it for each of the three lists

//This search function iterates a sorted list of WBO dictionaries, checking the title and url of the objects.

//it first checks to see if the title or the url of an item contain all the search terms as substrings.
// if it does, then it is at least a substring match
//it then checks to see if it matches them all at the beginnings of 'words', using a regex inside an NSPredicate,
// which qualifies it as a high-quality match, and goes at the top of the list.

- (void) searchWeaveObjects:(NSArray*)items 
            withSearchTerms:(NSArray*)terms
              andPredicates:(NSArray*)predicateList 
             wordHitResults:(NSMutableDictionary*)wordHits 
           substringResults:(NSMutableDictionary*)substrHits
            returningAtMost:(NSInteger)maxHits

{
    int wordHitCount = 0;
    int substrHitCount = 0;
    
    for (FXSyncItem* item in items)
    {
        BOOL skip = NO;
        
        NSString *title = [item title];
        NSString *uri = [item urlString];
        NSString *description = [item description];
        
        // Workaround to avoid folders and other unexpected stuff
        if (![uri length]) continue;
        
        //rangeOfString is incredibly fast, so we use it to prefilter. if an item doesn't even contain all the search terms as substrings,
        // it obviously can't have them as the start of words
        for (NSString* term in terms) {
            
            NSRange titleRange = [title rangeOfString:term options:NSCaseInsensitiveSearch];
            NSRange urlRange = [uri rangeOfString:term options:NSCaseInsensitiveSearch];
            NSRange descRange = [description rangeOfString:term options:NSCaseInsensitiveSearch];
            if ((!title || titleRange.location == NSNotFound)
                && (!uri || urlRange.location == NSNotFound)
                && (!description || descRange.location == NSNotFound))
            {
                skip = YES;
                break;
            }
        }
        if (skip) continue;  //we didn't find all the search terms as substrings, so go on to the next item
        
        //at this point, we know we have at least a substring hit!
        // but now we check to see if the terms are all at the beginnings of words,
        // which makes it a SUPER DELUXE SPARKLE HIT!!
        
        BOOL isSuperDeluxeSparkleHit = YES;  //flips to NO if all the predicates don't match
        
        for (NSPredicate* pred in predicateList) {
            @try  {
                isSuperDeluxeSparkleHit = isSuperDeluxeSparkleHit && ([pred evaluateWithObject:title]
                                                                      || [pred evaluateWithObject:uri]
                                                                      || [pred evaluateWithObject:description]);
            } @catch (NSException * e)  {
                isSuperDeluxeSparkleHit = NO;
                break; //just get out
            }
            
            if (!isSuperDeluxeSparkleHit) break;  //don't check any more predicates
        }
        
        if (isSuperDeluxeSparkleHit) {
            wordHitCount++;
            wordHits[uri] = item;
        } else if (substrHitCount < maxHits) {
            substrHitCount++;
            substrHits[uri] = item;
        }
        
        //now bail if we already have enough word hits.  if we have a fulllist of word hits, we don't care how many substr hits we have
        if (wordHitCount >= maxHits) break;
    }
}


//OK, this has gotten a lot easier.  the lists of tabs, bookmarks, and history are already sorted by frecency,
// so I can start at the beginning and stop when I get MAXPERLIST hits from each
- (void)refreshHits:(NSString*)searchString {
    
    //make the list of strict predicates to match.  usually only 1, but if the user separates strings with spaces, we must match them all,
    // on different word boundaries, to be a hit
    NSMutableArray* predicates = [NSMutableArray array];
    
    //break up the search string by spaces
    NSArray *rawTokens = [searchString componentsSeparatedByString:@" "];
    //now strip out the empty strings, duh
    NSMutableArray* searchTokens = [NSMutableArray array];
    for (NSString* token in rawTokens)
    {
        if ([token length]) [searchTokens addObject:token];
    }
    
    //for each token, make a match predicate
    for (NSString* token in searchTokens)
    {
        NSString *regex = [NSString stringWithFormat:@".*\\b(?i)%@.*", token];
        //put the predicates in a list
        [predicates addObject:[NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex]];
    }
    
    
    
    //see above, at the function definition of searchWeaveObjects, for an explanation of its complexities
    
    NSMutableDictionary* newWordHits = [NSMutableDictionary dictionary];
    NSMutableDictionary* newSubstringHits = [NSMutableDictionary dictionary];
    
    // PLEASE NOTE: I AM SEARCHING THE DATA IN THIS ORDER (history, bookmarks, tabs) ON PURPOSE!
    // DO NOT CHANGE THE ORDER.  This works in tandem with keeping them in a dictionary keyed by url
    // to remove duplicates, but prefer tabs over bookmarks, and bookmarks over history
    
    NSArray*  history = [[FXSyncStock sharedInstance] history];
    [self searchWeaveObjects:history
             withSearchTerms:searchTokens
               andPredicates:predicates 
              wordHitResults:newWordHits 
            substringResults:newSubstringHits 
             returningAtMost:MAXPERLIST];    
    
    NSArray* bookmarks = [[FXSyncStock sharedInstance] bookmarks];
    [self searchWeaveObjects:bookmarks
             withSearchTerms:searchTokens
               andPredicates:predicates 
              wordHitResults:newWordHits 
            substringResults:newSubstringHits 
             returningAtMost:MAXPERLIST];
    
    // Can't use tabs, records are not FXSyncItem's, I don't want to deal with this now
//    NSArray* tabs = [[FXSyncStock sharedInstance] clientTabs];
//    for (FXSyncItem* client in tabs)
//    {
//        [self searchWeaveObjects:[client tabs]
//                 withSearchTerms:searchTokens
//                   andPredicates:predicates 
//                  wordHitResults:newWordHits 
//                substringResults:newSubstringHits 
//                 returningAtMost:MAXPERLIST];
//    }
    
    NSComparator cmp = ^(id obj1, id obj2) {
        NSInteger srt1 = [obj1 sortindex];
        NSInteger srt2 = [obj2 sortindex];
        return srt1 > srt2 ? NSOrderedAscending : NSOrderedDescending;
    };
    
    //sort them by sortIndex (frecency)
    NSMutableArray* WORD_matches = [NSMutableArray arrayWithArray:[newWordHits allValues]];
    [WORD_matches sortUsingComparator:cmp];
    
    //OK!!  Now we have at least 0 and at most N * MAXPERLIST, sorted by frecency
    //but wait, if we don't have at least MAXPERLIST, then let's try doing a plain old substring match
    if ([WORD_matches count] < MAXPERLIST) {
        //we will tack the substring matches, themselves sorted, onto the end of the list, to make MAXPERLIST
        NSMutableArray* SUBSTRING_matches = [NSMutableArray arrayWithArray:[newSubstringHits allValues]];
        [SUBSTRING_matches sortUsingComparator:cmp];
        
        NSInteger needed = MAXPERLIST - [WORD_matches count];
        
        //we need more than we have, so add them all
        if (needed > [newSubstringHits count])
        {
            [WORD_matches addObjectsFromArray:SUBSTRING_matches];
        }
        else //we have more than we need, so just add the right amount to reach MAXPERLIST
        {
            NSRange addHits;
            addHits.location = 0;
            addHits.length = needed;
            [WORD_matches addObjectsFromArray:[SUBSTRING_matches subarrayWithRange:addHits]];
        }
        gFreshSearchHits = WORD_matches;
    }
    else if ([newWordHits count] > MAXPERLIST) //otherwise if we have too many, then trim
    {
        NSRange maxHitCount;
        maxHitCount.location = 0;
        maxHitCount.length = MAXPERLIST;
        
        NSArray* temp = [WORD_matches subarrayWithRange:maxHitCount];
        gFreshSearchHits = temp;
    }
    else 
    {
        gFreshSearchHits = WORD_matches; 
    }
}


@end
