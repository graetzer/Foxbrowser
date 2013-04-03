//
//  SGMailActivity.m
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

#import "SGMailActivity.h"

@implementation SGMailActivity {
    UIViewController *_viewController;
}

- (UIImage *)activityImage {
    return [UIImage imageNamed:@"mail-icon"];
}

- (NSString *)activityTitle {
    return @"Mail";
}

- (NSString *)activityType {
    //NSLog(@"%@",UIActivityTypeMail);
    return SGActivityTypeMail;
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    BOOL can = NO;
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSURL class]]) return YES;
        if ([item isKindOfClass:[NSString class]]) return YES;
        if ([item isKindOfClass:[UIImage class]]) return YES;
    }
    return can;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    MFMailComposeViewController *mail = [MFMailComposeViewController new];
    
    NSMutableString *bodyText = [NSMutableString stringWithCapacity:100];
    NSMutableArray *senders = [NSMutableArray arrayWithCapacity:10];
    
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSString class]]) {
            [bodyText appendFormat:@"%@\n", item];
        } else if ([item isKindOfClass:[UIImage class]]) {
            [mail addAttachmentData:UIImagePNGRepresentation(item)
                           mimeType:@"image/png" fileName:@"Image.png"];
        } else if ([item isKindOfClass:[NSURL class]]) {
            NSURL *url = item;
            if ([url.scheme isEqualToString:@"mailto"]) {
                [senders addObject:url.resourceSpecifier];
            } else if ([url isFileURL]) {
                CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                                        (__bridge CFStringRef)[url pathExtension], NULL);
                CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
                CFRelease(UTI);
                if (!MIMEType) MIMEType = CFSTR("application/octet-stream");
                
                NSData *data = [NSData dataWithContentsOfURL:url];
                [mail addAttachmentData:data
                               mimeType:CFBridgingRelease(MIMEType)
                               fileName:[url lastPathComponent]];
            } else {
                [bodyText appendFormat:@"%@\n", url.absoluteString];
            }
        }
    }
    
    [mail setSubject:NSLocalizedString(@"Sending you a link", nil)];
    [mail setToRecipients:senders];
    [mail setMessageBody:bodyText isHTML:NO];
    mail.mailComposeDelegate = self;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        mail.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    _viewController = mail;
}

- (UIViewController *)activityViewController {
    return _viewController;
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    
    [controller dismissViewControllerAnimated:YES completion:^{
        [self activityDidFinish:error == nil];
    }];
}

@end
