//
//  SGActivity.m
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

#import "SGActivity.h"

NSString *const SGActivityTypePostToFacebook = @"com.apple.UIKit.activity.PostToFacebook";
NSString *const SGActivityTypePostToTwitter = @"com.apple.UIKit.activity.PostToTwitter";
NSString *const SGActivityTypePostToWeibo = @"com.apple.UIKit.activity.PostToWeibo";
NSString *const SGActivityTypeMessage = @"todo";
NSString *const SGActivityTypeMail = @"com.apple.UIKit.activity.Mail";
NSString *const SGActivityTypePrint = @"todo2";

@implementation SGActivity
- (UIImage *)activityImage {
    return nil;
}

- (NSString *)activityTitle {
    return nil;
}

- (NSString *)activityType {
    return nil;
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    
}

- (UIViewController *)activityViewController {
    return nil;
}

- (void)performActivity {
    
}

- (void)activityDidFinish:(BOOL)completed {
    if (_completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _completionHandler([self activityType], completed);
        });
    }
}

@end
