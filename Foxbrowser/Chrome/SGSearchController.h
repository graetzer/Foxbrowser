//
//  SGURLBarRecentsController.h
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SGToolbar.h"

@protocol SGURLBarDelegate <NSObject>

- (void)finishSearchWithString:(NSString *)searchString;
@property (nonatomic, strong) UISearchBar *searchBar;

@end

@interface SGURLBarController : UITableViewController {
    NSString* gLastSearchString;
}

@property (nonatomic, weak) id<SGURLBarDelegate> delegate;
@property (nonatomic, retain) NSArray *searchHits;

- (void)filterResultsUsingString:(NSString *)filterString;
@end