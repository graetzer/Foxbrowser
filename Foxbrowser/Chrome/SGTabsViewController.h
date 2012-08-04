//
//  SGTabsViewController.h
//  SGTabs
//
//  Created by simon on 07.06.12.
//
//
//  Copyright (c) 2012 Simon Grätzer
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

#import <UIKit/UIKit.h>
#import "SGToolbar.h"

@protocol SGTabsViewControllerDelegate <NSObject>

@optional
- (void)willShowTab:(UIViewController *)viewController;
- (void)willRemoveTab:(UIViewController *)viewController;
- (BOOL)canRemoveTab:(UIViewController *)viewController;

@end

@class SGToolbar, SGTabsView;

@interface SGTabsViewController : UIViewController <SGToolbarDelegate, SGTabsViewControllerDelegate> {
    CGRect _contentFrame;
}

/// Is an optional delegate
@property (nonatomic, weak) id<SGTabsViewControllerDelegate> delegate;

/// Currently visible view controller
@property (nonatomic, readonly, weak) UIViewController *currentViewController;
/// For internal use
@property (nonatomic, readonly, strong) NSMutableArray *tabContents;
/// The frame in wihich content is shown
@property (nonatomic, readonly) CGRect contentFrame;


- (void)addTab;

/// Adds a tab, don't add the same instance twice!
- (void)addTab:(UIViewController *)viewController;
- (void)addTabWithURL:(NSURL *)url withTitle:(NSString *)title;

/// Bring a tab to the frontpage
- (void)showViewController:(UIViewController *)viewController;
/// Primarily intended for internal use
- (void)showIndex:(NSUInteger)index;

- (void)removeViewController:(UIViewController *)viewController;
/// Primarily intended for internal use
- (void)removeIndex:(NSUInteger)index;

- (NSUInteger)count;
- (NSUInteger)maxCount;

/// Tells the view controller to update it's chrome
- (void)updateChrome;
- (void)saveCurrentURLs;

@end
