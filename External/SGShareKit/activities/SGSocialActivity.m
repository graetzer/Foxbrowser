//
//  SGSocial.m
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

#import "SGSocialActivity.h"

@implementation SGSocialActivity {
    UIViewController *_viewController;
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    if (![SLComposeViewController isAvailableForServiceType:[self serviceType]]) return NO;
    
    BOOL can = NO;
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSURL class]]) return YES;
        if ([item isKindOfClass:[NSString class]]) return YES;
        if ([item isKindOfClass:[UIImage class]]) return YES;
    }
    return can;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    NSString *service = [self serviceType];
    SLComposeViewController *composeVC = [SLComposeViewController composeViewControllerForServiceType:service];
    
    NSMutableString *initialText = [NSMutableString stringWithCapacity:160];
    
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSURL class]]) {
            [composeVC addURL:item];
        } else if ([item isKindOfClass:[NSString class]]) {
            [initialText appendFormat:@"%@\n", item];
        } else if ([item isKindOfClass:[UIImage class]]) {
            [composeVC addImage:item];
        }
    }
    [composeVC setInitialText:initialText];
    
    composeVC.completionHandler = ^(SLComposeViewControllerResult result) {
        [self activityDidFinish:result == SLComposeViewControllerResultDone];
    };
    
    _viewController = composeVC;
}

- (UIViewController *)activityViewController {
    return _viewController;
}

- (NSString *)serviceType {
    [NSException raise:@"Not implemented Exception" format:@"Method: %s", __FUNCTION__];
    return nil;
}

@end
