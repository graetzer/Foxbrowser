//
//  SGShareView.m
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

#import "SGActivityView.h"
#import "SGActivity.h"
#import "SGFacebookActivity.h"
#import "SGSinaWeiboActivity.h"
#import "SGTwitterActivity.h"
#import "SGMailActivity.h"

#if !__has_feature(objc_arc)
#error SGShareView must be built with ARC.
// You can partially turn on ARC by adding -fobjc-arc to the build phase for each file.
#endif

#define POPLISTVIEW_HEADER_HEIGHT 50.
#define RADIUS 5.

@interface SGActivityViewController : UIViewController
@end

static NSMutableArray *LaunchURLHandler;
static NSArray *PreconfiguredActivities;

CGFloat UIInterfaceOrientationAngleOfOrientation(UIInterfaceOrientation orientation);

@implementation SGActivityView {
    CGRect _bgRect;
    UIColor *_bgColor;
    
    NSArray *_activityItems;
    NSMutableArray *_applicationActivities;
    
    UIWindow *_myWindow;
    __weak UIWindow *_originalWindow;
}

+ (void)initialize {
    if (NSClassFromString(@"SLComposeViewController")) {// iOS 6+
        PreconfiguredActivities = @[[SGFacebookActivity new], [SGSinaWeiboActivity new],
                                    [SGTwitterActivity new], [SGMailActivity new]];
    } else {
        PreconfiguredActivities = @[[SGTwitterActivity new], [SGMailActivity new]];
    }
}

- (id)initWithActivityItems:(NSArray *)activityItems applicationActivities:(NSArray *)applicationActivities {
    NSParameterAssert(activityItems.count > 0);
    
    CGRect frame = [UIScreen mainScreen].bounds;
    if (self = [super initWithFrame:frame]) {
        _bgColor = [UIColor colorWithWhite:0 alpha:.75];
        _activityItems = activityItems;
        _applicationActivities = [NSMutableArray arrayWithCapacity:PreconfiguredActivities.count];
        [_applicationActivities addObjectsFromArray:applicationActivities];
        [_applicationActivities addObjectsFromArray:PreconfiguredActivities];
        
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.contentMode = UIViewContentModeRedraw;
        
        __strong UITableView *tableView = [[UITableView alloc] initWithFrame:frame];
        tableView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        tableView.separatorColor = [UIColor colorWithWhite:0 alpha:.2];
        tableView.backgroundColor = [UIColor clearColor];
        tableView.dataSource = self;
        tableView.delegate = self;
        tableView.rowHeight = 50;
        [self addSubview:tableView];
        _tableView = tableView;
    }
    return self;
}

- (void)show {
    [self validateApplicationActivities];
    
    _originalWindow = [UIApplication sharedApplication].keyWindow;
    _myWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _myWindow.windowLevel = UIWindowLevelAlert;
    _myWindow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.20];
    _myWindow.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
    UIViewController *vC = [SGActivityViewController new];
    vC.view.frame = [UIScreen mainScreen].bounds;
    [vC.view addSubview:self];
    _myWindow.rootViewController = vC;
    [_myWindow makeKeyAndVisible];

    if (!_title) {
        if (_activityItems.count == 1) {
            if ([_activityItems[0] isKindOfClass:[UIImage class]]) {
                _title  = NSLocalizedString(@"Share Picture", @"Share picture title");
            } else if ([_activityItems[0] isKindOfClass:[NSURL class]]) {
                _title  = NSLocalizedString(@"Share Page", @"Share url of page");
            } else {
                _title = NSLocalizedString(@"Share", @"Share title");
            }
        } else {
            _title = NSLocalizedString(@"Share", @"Share title"); 
        }
    }
    
    self.transform = CGAffineTransformConcat(self.transform, CGAffineTransformMakeScale(1.3, 1.3));
    _myWindow.alpha = 0;
    [UIView animateWithDuration:.35 animations:^{
        _myWindow.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    }];
}

- (void)hide {
    [UIView animateWithDuration:.35 animations:^{
        self.transform = CGAffineTransformIdentity;
        _myWindow.alpha = 0;
    } completion:^(BOOL finished){
        [self removeFromSuperview];
        _myWindow.hidden = YES;
        _myWindow.rootViewController = nil;
        _myWindow = nil;
        [_originalWindow makeKeyAndVisible];
    }];
}

#pragma mark - Private

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = [UIScreen mainScreen].bounds;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        _bgRect = CGRectInset(bounds, bounds.size.width*0.10, bounds.size.height*0.21);
    } else {
        _bgRect = CGRectInset(bounds, bounds.size.width/3.3, bounds.size.height/3.3);
    }
    
    bounds = self.bounds;
    if (_bgRect.size.height > bounds.size.height)
        _bgRect.size.height = bounds.size.height*0.85;
    
    _bgRect.origin = CGPointMake((bounds.size.width - _bgRect.size.width)/2,
                                 (bounds.size.height - _bgRect.size.height)/2);
    
    CGRect tableRect = _bgRect;
    tableRect.origin.x += 5;
    tableRect.origin.y += POPLISTVIEW_HEADER_HEIGHT;
    tableRect.size.height -= POPLISTVIEW_HEADER_HEIGHT + RADIUS;
    tableRect.size.width -= 5;
    self.tableView.frame = tableRect;
}

- (void)validateApplicationActivities {
    NSUInteger i = 0;
    while (i < _applicationActivities.count) {
        SGActivity *activity = _applicationActivities[i];
        
        if ([self.excludedActivityTypes containsObject:[activity activityType]]
            || ![activity canPerformWithActivityItems:_activityItems]) {
            
            [_applicationActivities removeObjectAtIndex:i];
            continue;
        }
        i++;
    }
}

#pragma mark - Tableview datasource & delegates

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _applicationActivities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentity = @"Default";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentity];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentity];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16.];
        cell.imageView.contentMode = UIViewContentModeCenter;
    }
    
    SGActivity *activity = _applicationActivities[indexPath.row];
    cell.imageView.image = activity.activityImage;
    cell.textLabel.text = activity.activityTitle;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SGActivity *activity = _applicationActivities[indexPath.row];
    activity.completionHandler = _completionHandler;
    
    // Dismiss 
    [UIView animateWithDuration:.35 animations:^{
        self.transform = CGAffineTransformConcat(self.transform, CGAffineTransformMakeScale(1./1.3, 1/1.3));
        _myWindow.alpha = 0;
    } completion:^(BOOL finished){
        _myWindow.hidden = YES;
        [_originalWindow makeKeyAndVisible];
        
        double delayInSeconds = 0.2;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [activity prepareWithActivityItems:_activityItems];
            
            UIViewController *viewController = [activity activityViewController];
            if (viewController) {
                UIViewController *parent = _originalWindow.rootViewController;
                viewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
                [parent presentViewController:viewController animated:YES completion:NULL];
            } else {
                [activity performActivity];
            }
            [self removeFromSuperview];
            _myWindow.rootViewController = nil;
            _myWindow = nil;
        });
    }];
}

#pragma mark - Detect outside touches
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // tell the delegate the cancellation
    if (_completionHandler) {
        _completionHandler(nil, NO);
    }
    
    // dismiss self
    [self hide];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGRect titleRect = CGRectMake(_bgRect.origin.x + 10, _bgRect.origin.y + 10 + 5,
                                  _bgRect.size.width - 2*10, 30);
    CGRect separatorRect = CGRectMake(_bgRect.origin.x, _bgRect.origin.y + POPLISTVIEW_HEADER_HEIGHT - 2,
                                      _bgRect.size.width, 2);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // Draw the background with shadow
    CGContextSetShadowWithColor(ctx, CGSizeZero, 6., _bgColor.CGColor);
    [_bgColor setFill];
    
    float x = _bgRect.origin.x;
    float y = _bgRect.origin.y;
    float width = _bgRect.size.width;
    float height = _bgRect.size.height;
    CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, NULL, x, y + RADIUS);
	CGPathAddArcToPoint(path, NULL, x, y, x + RADIUS, y, RADIUS);
	CGPathAddArcToPoint(path, NULL, x + width, y, x + width, y + RADIUS, RADIUS);
	CGPathAddArcToPoint(path, NULL, x + width, y + height, x + width - RADIUS, y + height, RADIUS);
	CGPathAddArcToPoint(path, NULL, x, y + height, x, y + height - RADIUS, RADIUS);
	CGPathCloseSubpath(path);
	CGContextAddPath(ctx, path);
    CGContextFillPath(ctx);
    CGPathRelease(path);
    
    // Draw the title and the separator with shadow
    UIColor *titleColor = [UIColor colorWithRed:0.020 green:0.549 blue:0.961 alpha:1.];
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 0.5f, [UIColor blackColor].CGColor);
    [titleColor setFill];
    CGContextFillRect(ctx, separatorRect);
    
    UIFont *textFont = [UIFont systemFontOfSize:16.];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    [_title drawInRect:titleRect withFont:textFont];

    [@"x" drawInRect:titleRect
            withFont:textFont
       lineBreakMode:NSLineBreakByCharWrapping
           alignment:NSTextAlignmentRight];
#else
    [_title drawInRect:titleRect withAttributes:@{NSFontAttributeName:textFont,
                                                  NSForegroundColorAttributeName:titleColor}];
    
    NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
    para.alignment = NSTextAlignmentRight;
    [@"x" drawInRect:titleRect withAttributes:@{
                                                NSFontAttributeName:textFont,
                                                NSForegroundColorAttributeName:titleColor,
                                                NSParagraphStyleAttributeName:para}];
#endif
}

+ (void)addLaunchURLHandler:(SGShareViewLaunchURLHandler)handler {
    if (!LaunchURLHandler)
        LaunchURLHandler = [[NSMutableArray alloc] initWithCapacity:5];
    [LaunchURLHandler addObject:[handler copy]];
}

+ (BOOL)handleURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    for (SGShareViewLaunchURLHandler handler in LaunchURLHandler)
        if (handler(url, sourceApplication, annotation))
            return YES;
    
    return NO;
}

@end

@implementation SGActivityViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end
