//
//  SGActivity.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 29.03.13.
//
//
//  Copyright 2013 Simon Peter Grätzer
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SGActivityView.h"

@interface SGActivity : NSObject
@property (copy, nonatomic) SGActivityViewCompletionHandler completionHandler;

- (NSString *)activityType;// default returns nil. subclass may override to return custom activity type that is reported to completion handler
- (NSString *)activityTitle;// default returns nil. subclass must override and must return non-nil value
- (UIImage *)activityImage;// default returns nil. subclass must override and must return non-nil value

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems;// override this to return availability of activity based on items. default returns NO
- (void)prepareWithActivityItems:(NSArray *)activityItems;// override to extract items and set up your HI. default does nothing

- (UIViewController *)activityViewController;// return non-nil to have vC presented modally. call activityDidFinish at end. default returns nil
- (void)performActivity;// if no view controller, this method is called. call activityDidFinish when done. default calls [self activityDidFinish:NO]

// state method
- (void)activityDidFinish:(BOOL)completed;   // activity must call this when activity is finished. can be called on any thread
@end

UIKIT_EXTERN NSString *const SGActivityTypePostToFacebook   NS_AVAILABLE_IOS(5_0); // text, images, URLs
UIKIT_EXTERN NSString *const SGActivityTypePostToTwitter    NS_AVAILABLE_IOS(5_0); // text, images, URLs
UIKIT_EXTERN NSString *const SGActivityTypePostToWeibo      NS_AVAILABLE_IOS(5_0); // text, images, URLs
UIKIT_EXTERN NSString *const SGActivityTypeMessage          NS_AVAILABLE_IOS(5_0); // text
UIKIT_EXTERN NSString *const SGActivityTypeMail             NS_AVAILABLE_IOS(5_0); // text, image, file:// URLs
UIKIT_EXTERN NSString *const SGActivityTypePrint            NS_AVAILABLE_IOS(5_0); // image, NSData, file:// URL, UIPrintPageRenderer,