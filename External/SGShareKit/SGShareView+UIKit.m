//
//  SGShareView+UIKit.m
//  SGShareKit
//
//  Created by Simon Grätzer on 25.02.13.
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

#import "SGShareView+UIKit.h"
#import <objc/runtime.h>
#import <objc/message.h>

static void dismissMailVC(id self, SEL _cmd, MFMailComposeViewController *mailC, MFMailComposeResult result, NSError *error) {
    [mailC dismissViewControllerAnimated:YES completion:NULL];
}

@implementation SGShareView (UIKit)

+ (void)load {
    @autoreleasepool {
        if (NSClassFromString(@"SLComposeViewController")) {
            if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
                [self addService:@"Facebook"
                           image:[UIImage imageNamed:@"facebook"]
                         handler:^(SGShareView* shareVC){
                             SLComposeViewController *composeVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
                             
                             if (shareVC.initialText)
                                 [composeVC setInitialText:shareVC.initialText];
                             
                             for (NSURL* url in shareVC->urls)
                                 [composeVC addURL:url];
                             
                             for (UIImage *img in shareVC->images)
                                 [composeVC addImage:img];
                             
                             UIViewController *vC = [[UIApplication sharedApplication].windows[0] rootViewController];
                             [vC presentViewController:composeVC animated:YES completion:NULL];
                         }];
            }
            
            if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo]) {
                [self addService:@"Sina Weibo"
                           image:[UIImage imageNamed:@"sina_weibo"]
                         handler:^(SGShareView* shareVC){
                             SLComposeViewController *composeVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
                             
                             if (shareVC.initialText)
                                 [composeVC setInitialText:shareVC.initialText];
                             
                             for (NSURL* url in shareVC->urls)
                                 [composeVC addURL:url];
                             
                             for (UIImage *img in shareVC->images)
                                 [composeVC addImage:img];
                             
                             UIViewController *vC = [[UIApplication sharedApplication].windows[0] rootViewController];
                             [vC presentViewController:composeVC animated:YES completion:NULL];
                         }];
            }
            
            if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
                [self addService:@"Twitter"
                           image:[UIImage imageNamed:@"twitter"]
                         handler:^(SGShareView* shareVC){
                             SLComposeViewController *composeVC = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
                             
                             if (shareVC.initialText)
                                 [composeVC setInitialText:shareVC.initialText];
                             
                             for (NSURL* url in shareVC->urls)
                                 [composeVC addURL:url];
                             
                             for (UIImage *img in shareVC->images)
                                 [composeVC addImage:img];
                             
                             UIViewController *vC = [[UIApplication sharedApplication].windows[0] rootViewController];
                             [vC presentViewController:composeVC animated:YES completion:NULL];
                         }];
            }
            
        } else {
            [self addService:@"Twitter"
                       image:[UIImage imageNamed:@"twitter"]
                     handler:^(SGShareView* shareVC){
                         TWTweetComposeViewController *tw = [TWTweetComposeViewController new];
                         
                         if (shareVC.initialText)
                             [tw setInitialText:shareVC.initialText];
                         
                         for (NSURL* url in shareVC->urls)
                             [tw addURL:url];
                         
                         for (UIImage *img in shareVC->images)
                             [tw addImage:img];
                         
                         UIViewController *vC = [[UIApplication sharedApplication].windows[0] rootViewController];
                         [vC presentViewController:tw animated:YES completion:NULL];
                     }];
        }
        
        if ([MFMailComposeViewController canSendMail]) {
            [self addService:@"Mail"
                       image:[UIImage imageNamed:@"mail"]
                     handler:^(SGShareView* shareVC){
                         MFMailComposeViewController *mail = [MFMailComposeViewController new];
                         [mail setSubject:NSLocalizedString(@"Sending you a link", nil)];
                         
                         NSMutableString *bodyText = [NSMutableString stringWithCapacity:100];
                         if (shareVC.initialText)
                             [bodyText appendFormat:@"%@\n   ", shareVC.initialText];
                         
                         if (shareVC->urls.count > 0) {
                             NSString *urls = [shareVC->urls componentsJoinedByString:@"\n   "];
                             [bodyText appendString:urls];
                         }
                         [mail setMessageBody:bodyText isHTML:NO];
                         
                         for (UIImage *img in shareVC->images)
                             [mail addAttachmentData:UIImagePNGRepresentation(img)
                                            mimeType:@"image/png" fileName:@"Image.png"];
                         
                         UIViewController *vC = [[UIApplication sharedApplication].windows[0] rootViewController];
                         mail.mailComposeDelegate = (id<MFMailComposeViewControllerDelegate>)mail;
                         [vC presentViewController:mail animated:YES completion:NULL];
                     }];
            
            // shareVC is released after execution
            class_addMethod([MFMailComposeViewController class], @selector(mailComposeController:didFinishWithResult:error:),
                            (IMP)(dismissMailVC), "v@:@I@");
        }
    }

}

@end

