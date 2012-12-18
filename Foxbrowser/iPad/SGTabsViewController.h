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

#import "SGBrowserViewController.h"

@class SGTabsToolbar, SGTabsView;

@interface SGTabsViewController : SGBrowserViewController

/// The frame in wihich content is shown
@property (nonatomic, readonly) CGRect contentFrame;

/// Primarily intended for internal use
- (void)showIndex:(NSUInteger)index;

/// Tells the view controller to update it's chrome
- (void)updateChrome;

@end
