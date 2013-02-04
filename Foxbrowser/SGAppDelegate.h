//
//  SGAppDelegate.h
//  Foxbrowser
//
//  Created by simon on 27.06.12.
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
#import "WeaveService.h"

@class SGBrowserViewController;
@protocol GAITracker;

@interface SGAppDelegate : UIResponder <UIApplicationDelegate, WeaveService>

@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) SGBrowserViewController *browserViewController;

@property (strong, nonatomic) id<GAITracker> tracker;

@end

extern SGAppDelegate *appDelegate;