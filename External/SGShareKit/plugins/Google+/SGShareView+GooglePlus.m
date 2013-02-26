//
//  SGShareView+GooglePlus.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 26.02.13.
//  Copyright (c) 2013 Simon Peter Grätzer. All rights reserved.
//

#import "SGShareView+GooglePlus.h"
#import "GPPShare.h"

static NSString * const kClientId = @"1012733718205.apps.googleusercontent.com";
static GPPShare *GPPSharer_ = nil;

@implementation SGShareView (GooglePlus)

+ (void)load {
    [SGShareView addService:@"Google+"
                      image:[UIImage imageNamed:@"google-plus"]
                    handler:^(SGShareView *shareView){
                        GPPShare *share = [SGShareView gppShare];
                        id<GPPShareBuilder> builder = [share shareDialog];
                        if (shareView.initialText)
                            [builder setPrefillText:shareView.initialText];
                        
                        if (shareView->urls.count > 0)
                            [builder setURLToShare:shareView->urls[0]];
                        
                        [builder open];
                    }];
    
    SGShareViewLaunchURLHandler launchBlock = ^(NSURL *url, NSString *sourceApplication, id annotation){
        return [[SGShareView gppShare] handleURL:url
                                 sourceApplication:sourceApplication
                                      annotation:annotation];
    };
    [SGShareView addLaunchURLHandler:launchBlock];
}

+ (GPPShare *)gppShare {
    if (!GPPSharer_)
        GPPSharer_ = [[GPPShare alloc] initWithClientID:kClientId];
    
    return GPPSharer_;
}

@end
