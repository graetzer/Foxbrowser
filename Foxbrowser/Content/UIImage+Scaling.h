//
//  UIImage+Scaling.h
//  Foxbrowser
//
//  Created by Simon Grätzer on 31.07.12.
//  Copyright (c) 2012 Cybercon GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Scaling)
- (UIImage *) scaleToSize: (CGSize)size;
- (UIImage *) scaleProportionalToSize: (CGSize)size;
- (UIImage *) cutImageToSize: (CGSize)size;
@end
