//
//  SGURLBarRecentsController.m
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//
//
//  Copyright (c) 2012 Simon Peter Grätzer
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SGSearchViewController.h"
#import "Store.h"
#import "Stockboy.h"
#import "WeaveService.h"


@interface SGSearchViewController ()

@end

@implementation SGSearchViewController {
    NSString* gLastSearchString;
}
@synthesize delegate;
@synthesize searchHits;

static NSThread* gRefreshThread = nil;
static NSArray* gFreshSearchHits = nil;

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.contentSizeForViewInPopover = CGSizeMake(500., 280.);
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
    searchHits = gFreshSearchHits;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //first section is normal sync results, the final section has magic "goto" behavior
    if (section == 0)
    {
        if (self.delegate.text.length != 0 && [searchHits count])
        {
            return [searchHits count];
        }
        return 0;
    }
    else return 1;
}

// Display the strings in displayedRecentSearches.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && gLastSearchString != nil) {//special goto cell, which goes to a website directly, independent of your synced items
        static NSString *CellIdentifier = @"GOTO_CELL";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) 
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor blueColor];
        cell.textLabel.textAlignment = UITextAlignmentLeft;
        cell.textLabel.text = [NSString stringWithFormat:@"%@", gLastSearchString];
        cell.imageView.image = [UIImage imageNamed:@"goto"];
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    } else { //regular title/url cell
        //NOTE: I'm now sharing the table cell cache between all my tables to save memory
        static NSString *CellIdentifier = @"URL_CELL";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        @try 
        {
            if (searchHits)
            {
                if ([searchHits count])
                {
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.textAlignment = UITextAlignmentLeft;
                    
                    NSDictionary* matchItem = searchHits[[indexPath row]];
                    // Set up the cell...
                    cell.textLabel.text = matchItem[@"title"];
                    cell.detailTextLabel.text = matchItem[@"url"];
                    //the item tells us which icon to use
                    cell.imageView.image = [UIImage imageNamed:matchItem[@"icon"]];
                }
                else //empty list, means no matches
                {
                    cell.textLabel.textColor = [UIColor grayColor];
                    cell.textLabel.text = NSLocalizedString(@"No Matches", @"no matching items found");
                    cell.detailTextLabel.text = nil;
                    cell.imageView.image = nil;
                }
                
            }
            else //no list at all, means searching
            {
                cell.textLabel.textColor = [UIColor grayColor];
                cell.textLabel.text = NSLocalizedString(@"Searching...", @"searching for matching items");
                cell.detailTextLabel.text = nil;
                cell.imageView.image = nil;
            }
            
        }
        @catch (NSException * e) {
            DLog(@"item to display missing from searchhits");
            cell.textLabel.textColor = [UIColor blackColor];
            cell.textLabel.text = nil;
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
    
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    
	if (!([searchHits count] == 0 && gLastSearchString.length == 0)) {
		NSString* destination = nil;        
		if (indexPath.section == 1) {
            destination = [[WeaveOperations sharedOperations] queryURLForTerm:gLastSearchString];
		} else  {
			destination = cell.detailTextLabel.text;
		}
		[self.delegate finishSearch:destination title:cell.textLabel.text];
	}
    
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([self.delegate respondsToSelector:@selector(userScrolledSuggestions)])
     [self.delegate performSelector:@selector(userScrolledSuggestions)];
}

#pragma mark - Heavy search tasks, copied from Weave
- (void)filterResultsUsingString:(NSString*)query
{
    //if there is a thread running, we need to stop it. it will autorelease
    if (gRefreshThread != nil) {
        [gRefreshThread cancel];
        gRefreshThread = nil;
    }
    
    if (!query || query.length == 0) {
        gFreshSearchHits = nil;
        gLastSearchString = nil;
        [self.tableView reloadData];
    } else {
        //now fire up a new search thread
        gRefreshThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadRefreshHits:) object:query];
        if (gRefreshThread != nil) {//Seems to be nessesary sometimes
            [gRefreshThread start];
        }
    }
}

- (void) threadRefreshHits:(NSString*)searchText
{
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
            DLog(@"Failed to update search results");
        }
    }
}

#define MAXPERLIST 15

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
    
    for (NSDictionary* item in items)
    {
        NSRange titleRange;
        NSRange urlRange;
        BOOL skip = NO;
        //rangeOfString is incredibly fast, so we use it to prefilter. if an item doesn't even contain all the search terms as substrings,
        // it obviously can't have them as the start of words
        for (NSString* term in terms) 
        {
            titleRange = [item[@"title"] rangeOfString:term options:NSCaseInsensitiveSearch];
            urlRange = [item[@"url"] rangeOfString:term options:NSCaseInsensitiveSearch];
            if (titleRange.location == NSNotFound && urlRange.location == NSNotFound)
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
                isSuperDeluxeSparkleHit = isSuperDeluxeSparkleHit && ([pred evaluateWithObject:item[@"title"]] || [pred evaluateWithObject:item[@"url"]]);
            } @catch (NSException * e)  {
                isSuperDeluxeSparkleHit = NO;
                break; //just get out
            }
            
            if (!isSuperDeluxeSparkleHit) break;  //don't check any more predicates
        }
        
        if (isSuperDeluxeSparkleHit) {
            wordHitCount++;
            wordHits[item[@"url"]] = item;
        } else if (substrHitCount < maxHits) {
            substrHitCount++;
            substrHits[item[@"url"]] = item;
            //[substrHits setObject:item forKey:[item objectForKey:@"url"]];
        }
        
        //now bail if we already have enough word hits.  if we have a fulllist of word hits, we don't care how many substr hits we have
        if (wordHitCount >= maxHits) break;
    }
}


//OK, this has gotten a lot easier.  the lists of tabs, bookmarks, and history are already sorted by frecency,
// so I can start at the beginning and stop when I get MAXPERLIST hits from each 

- (void)refreshHits:(NSString*)searchString
{
    //empty string means no hits
    if (searchString == nil || [searchString length] == 0)
    {
        gFreshSearchHits = nil;
        gLastSearchString = nil;
        return;
    }
    
    gLastSearchString = searchString;
    
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
    
    NSArray*  history = [[Store getStore] getHistory];
    [self searchWeaveObjects:history
             withSearchTerms:searchTokens
               andPredicates:predicates 
              wordHitResults:newWordHits 
            substringResults:newSubstringHits 
             returningAtMost:MAXPERLIST];    
    
    NSArray* bookmarks = [[Store getStore] getBookmarks];
    [self searchWeaveObjects:bookmarks
             withSearchTerms:searchTokens
               andPredicates:predicates 
              wordHitResults:newWordHits 
            substringResults:newSubstringHits 
             returningAtMost:MAXPERLIST];
    
    
    NSArray* tabs = [[Store getStore] getTabs];
    for (NSDictionary* client in tabs)
    {
        [self searchWeaveObjects:client[@"tabs"] 
                 withSearchTerms:searchTokens
                   andPredicates:predicates 
                  wordHitResults:newWordHits 
                substringResults:newSubstringHits 
                 returningAtMost:MAXPERLIST];
    }
    
    
    //sort them by sortIndex (frecency)
    NSMutableArray* WORD_matches = [NSMutableArray arrayWithArray:[newWordHits allValues]];  
    [WORD_matches sortUsingFunction:compareSearchResults context:NULL];  
    
    //OK!!  Now we have at least 0 and at most N * MAXPERLIST, sorted by frecency
    //but wait, if we don't have at least MAXPERLIST, then let's try doing a plain old substring match
    if ([WORD_matches count] < MAXPERLIST)
    {
        //we will tack the substring matches, themselves sorted, onto the end of the list, to make MAXPERLIST
        NSMutableArray* SUBSTRING_matches = [NSMutableArray arrayWithArray:[newSubstringHits allValues]];   
        [SUBSTRING_matches sortUsingFunction:compareSearchResults context:NULL];
        
        int needed = MAXPERLIST - [WORD_matches count];
        
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
