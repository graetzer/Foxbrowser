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

@protocol SGShareViewDelegate;
@class SGShareView;
typedef void (^SGShareViewCallback)(SGShareView*);

@interface SGShareView : UIView <UITableViewDataSource, UITableViewDelegate> {
@protected
    NSMutableArray *urls;
    NSMutableArray *images;
}

@property (weak, nonatomic) UITableView *tableView;
@property (weak, nonatomic) id<SGShareViewDelegate> delegate;

@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *initialText;

+ (void)addService:(NSString *)name image:(UIImage *)image handler:(SGShareViewCallback)handler;

+ (SGShareView *)shareView;
- (void)show;
- (void)hide;

- (void)addURL:(NSURL *)url;
- (void)addImage:(UIImage *)image;
@end


@protocol SGShareViewDelegate <NSObject>
@optional
- (void)shareView:(SGShareView *)shareView didSelectService:(NSString*)name;
- (void)shareViewDidCancel:(SGShareView *)shareView;

@end