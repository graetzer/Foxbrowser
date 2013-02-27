//
//  SGShareView+GooglePlus.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 26.02.13.
//  Copyright (c) 2013 Simon Peter Grätzer. All rights reserved.
//

#import "SGShareView+GooglePlus.h"
#import "GPPSignIn.h"
#import "GPPShare.h"
#import "GPPURLHandler.h"

static NSString * const kClientId = @"1012733718205.apps.googleusercontent.com";

@implementation SGShareView (GooglePlus)

+ (void)load {
    [GPPSignIn sharedInstance].clientID = kClientId;
    
    [SGShareView addService:@"Google+"
                      imageName:@"googleplus-icon"
                    handler:^(SGShareView *shareView){
                        id<GPPShareBuilder> shareBuilder = [[GPPShare sharedInstance] shareDialog];
                        if (shareView.initialText)
                            [shareBuilder setPrefillText:shareView.initialText];
                        
                        if (shareView->urls.count > 0)
                            [shareBuilder setURLToShare:shareView->urls[0]];
                        
                        [shareBuilder open];
                    }];
    
    SGShareViewLaunchURLHandler launchBlock = ^(NSURL *url, NSString *sourceApplication, id annotation){
        return [GPPURLHandler handleURL:url
                      sourceApplication:sourceApplication
                             annotation:annotation];

    };
    [SGShareView addLaunchURLHandler:launchBlock];
}

@end
