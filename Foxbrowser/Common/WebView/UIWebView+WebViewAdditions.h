//
//  UIWebView+WebViewAdditions.h
//  Foxbrowser
//
//  Created by simon on 03.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface UIWebView (WebViewAdditions)
+ (NSArray *)fileTypes;

- (CGSize)windowSize;
- (CGPoint)scrollOffset;

- (NSString *)title;
- (NSString *)location;
- (void)setLocationHash:(NSString *)location;

- (void)loadJSTools;
- (void)disableContextMenu;
- (void)modifyLinkTargets;
- (void)modifyOpen;
- (void)clearContent;
- (void)enableDoNotTrack;

- (UIImage *)screenshot;
- (void)saveScreenTo:(NSString *)path;
+ (NSString *)screenshotPath;
+ (NSString *)pathForURL:(NSURL *)url;

- (NSDictionary *)tagsForPosition:(CGPoint)pt;

@end