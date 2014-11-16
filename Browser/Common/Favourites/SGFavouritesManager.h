//
//  SGScreenshotManager.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 27.12.12.
//
//
//  Copyright (c) 2012-2014 Simon Peter Grätzer
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
- (NSUInteger)maxFavs;

//- (void)setFavouriteWithURL:(NSURL *)url title:(NSString *)title atIndex:(NSUInteger)index;

// Call this after each webView call
- (void)webViewDidFinishLoad:(SGWebViewController *)webController;
@end
