//
//  SGPlusActivity.m
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

#import "SGPlusActivity.h"
#import "GPPSignIn.h"
#import "GPPShare.h"
#import "GPPURLHandler.h"

@implementation SGPlusActivity {
    id<GPPShareBuilder> _shareBuilder;
}

+ (void)initialize {
    SGShareViewLaunchURLHandler launchBlock = ^(NSURL *url, NSString *sourceApplication, id annotation){
        return [GPPURLHandler handleURL:url
                      sourceApplication:sourceApplication
                             annotation:annotation];
        
    };
    [SGActivityView addLaunchURLHandler:launchBlock];
}

- (UIImage *)activityImage {
    return [UIImage imageNamed:@"googleplus-icon"];
}

- (NSString *)activityTitle {
    return @"Google+";
}

- (NSString *)activityType {
    return @"UIActivityTypePostToGooglePlus";
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    BOOL can = NO;
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSURL class]]) return YES;
        if ([item isKindOfClass:[NSString class]]) return YES;
        //if ([item isKindOfClass:[UIImage class]]) return YES;
    }
    return can;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    _shareBuilder = [[GPPShare sharedInstance] shareDialog];
    NSMutableString *text = [NSMutableString stringWithCapacity:20];
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSURL class]]) {
            [_shareBuilder setURLToShare:item];
        } else if ([item isKindOfClass:[NSString class]]) {
            [text appendFormat:@"%@\n", item];
        }
    }
    [_shareBuilder setPrefillText:text];
}

- (void)performActivity {
    [_shareBuilder open];
}

@end
