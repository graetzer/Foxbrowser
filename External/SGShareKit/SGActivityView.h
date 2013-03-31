//
//  SGShareView.h
//  SGShareKit
//
//  Created by Simon Grätzer on 24.02.13.
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

#import <UIKit/UIKit.h>

typedef BOOL (^SGShareViewLaunchURLHandler)(NSURL*, NSString *, id);
typedef void (^SGActivityViewCompletionHandler)(NSString *activityType, BOOL completed);


@interface SGActivityView : UIView <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) UITableView *tableView;
@property (copy, nonatomic) NSString *title;

// UIActivityView API
@property(nonatomic,copy) NSArray *excludedActivityTypes;
@property (copy, nonatomic) SGActivityViewCompletionHandler completionHandler;
- (id)initWithActivityItems:(NSArray *)activityItems applicationActivities:(NSArray *)applicationActivities;

- (void)show;
- (void)hide;

+ (void)addLaunchURLHandler:(SGShareViewLaunchURLHandler)handler;
+ (BOOL)handleURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;
@end
