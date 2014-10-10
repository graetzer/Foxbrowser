//
//  SGScreenshotManager.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 27.12.12.
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class SGWebViewController, FXSyncItem;
@interface SGFavouritesManager : NSObject
+ (SGFavouritesManager *)sharedManager;

// Array of NSDictionarys
- (NSArray *)favourites;

// Returns the replacement
- (FXSyncItem *)blockItem:(FXSyncItem *)item;

- (UIImage *)imageWithURL:(NSURL *)url;

- (void)resetFavourites;
- (CGSize)imageSize;
- (NSUInteger)maxFavs;

//- (void)setFavouriteWithURL:(NSURL *)url title:(NSString *)title atIndex:(NSUInteger)index;

// Call this after each webView call
- (void)webViewDidFinishLoad:(SGWebViewController *)webController;
@end
