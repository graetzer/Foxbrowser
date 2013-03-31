//
//  SGSinaWeiboActivity.m
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

#import "SGSinaWeiboActivity.h"

@implementation SGSinaWeiboActivity

- (UIImage *)activityImage {
    return [UIImage imageNamed:@"sina_weibo-icon"];
}

- (NSString *)activityTitle {
    return @"Sina Weibo";
}

- (NSString *)activityType {
    //DLog(@"%@",UIActivityTypePostToWeibo);
    return SGActivityTypePostToWeibo;
}

- (NSString *)serviceType {
    return SLServiceTypeSinaWeibo;
}

@end
