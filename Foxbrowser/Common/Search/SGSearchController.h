//
//  SGURLBarRecentsController.h
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SGTabsToolbar.h"

@protocol SGSearchDelegate <NSObject>

- (void)finishSearch:(NSString *)searchString title:(NSString *)title;
- (NSString *)text;

@end

@interface SGSearchController : UITableViewController 

@property (nonatomic, weak) id<SGSearchDelegate> delegate;
@property (nonatomic, retain) NSArray *searchHits;

- (void)filterResultsUsingString:(NSString *)filterString;
@end