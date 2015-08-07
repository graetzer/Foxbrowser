//
//  FillrSDK.m
//  FillrSDK
//
//  Created by Alex Bin Zhao on 28/04/2015.
//  Copyright (c) 2015 Pop Tech Pty. Ltd. All rights reserved.
//

#import "Fillr.h"
#import "FillrAlertView.h"
#import "FillrAutofillInputAccessoryView.h"
#import "NSData+Base64Fillr.h"
#import "FillrToolbarPopup.h"

#define SYSTEM_VERSION_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define kShouldHideAutofillBar (@"HideAutofillBar")
#define kFillrSDKVersion (@"1.2")

@interface Fillr () {
    BOOL shouldHideAutofillBar;
    CGRect keyboardFrame;
    FillrAutofillInputAccessoryView *accessoryView;
    UIView *webView;
    NSString *devKey;
    NSString *urlSchema;
    
    // UI Elements
    UIImageView *fillrIconView;
    UIButton *autofillButton;
    UIButton *dismissButton;
    UIView *breakLine;
    UIButton *whatsthisButton;
}

@end

@implementation Fillr

static Fillr *sharedInstance;
+ (Fillr *)sharedInstance {
    if (!sharedInstance) {
        if (!sharedInstance) {
            sharedInstance = [[Fillr alloc] init];
            sharedInstance.overlayInputAccessoryView = NO;
        }
    }
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        [self addObservers];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        shouldHideAutofillBar = [defaults boolForKey:kShouldHideAutofillBar];
        
        if (!accessoryView) {
            accessoryView = [[FillrAutofillInputAccessoryView alloc] initWithFrame:CGRectMake(0.0f, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width, 44.0f)];
            accessoryView.backgroundColor = [UIColor colorWithRed:0.94f green:0.95f blue:0.95f alpha:1.0f];
            accessoryView.clipsToBounds = YES;
            
            NSBundle *bundle = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"FillrSDKBundle" withExtension:@"bundle"]];
            UIImage *fillrIconImage = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"fillr_sdk_icon" ofType:@"png"]];
            fillrIconView = [[UIImageView alloc] initWithFrame:CGRectMake(10.0f, (accessoryView.bounds.size.height - fillrIconImage.size.height) / 2, fillrIconImage.size.width, fillrIconImage.size.height)];
            fillrIconView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
            fillrIconView.backgroundColor = [UIColor clearColor];
            fillrIconView.contentMode = UIViewContentModeCenter;
            fillrIconView.image = fillrIconImage;
            [accessoryView addSubview:fillrIconView];
            
            CGFloat leftMargin = fillrIconView.frame.origin.x + fillrIconView.frame.size.width;
            autofillButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [autofillButton addTarget:self action:@selector(autofillTouchDown:) forControlEvents:UIControlEventTouchDown];
            [autofillButton addTarget:self action:@selector(autofillTapped:) forControlEvents:UIControlEventTouchUpInside];
            autofillButton.frame = CGRectMake(leftMargin, (accessoryView.frame.size.height - 24.0f) / 2, 138.0f, 24.0f);
            autofillButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
            [autofillButton setBackgroundColor:[UIColor clearColor]];
            [autofillButton setTitle:@"Use Secure Autofill" forState:UIControlStateNormal];
            [autofillButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [autofillButton setTitleColor:[UIColor colorWithWhite:0.6f alpha:1.0f] forState:UIControlStateHighlighted];
            autofillButton.titleLabel.font = [UIFont systemFontOfSize:14.0f];
            autofillButton.titleLabel.textAlignment = NSTextAlignmentLeft;
            [autofillButton.titleLabel sizeToFit];
            [accessoryView addSubview:autofillButton];
            
            UIImage *dismissIconImage = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"fillr_sdk_keyboard_arrow_down" ofType:@"png"]];
            dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [dismissButton addTarget:self action:@selector(dismissTapped:) forControlEvents:UIControlEventTouchUpInside];
            dismissButton.frame = CGRectMake(accessoryView.frame.size.width - 42.0f, 0.0f, 42.0f, accessoryView.bounds.size.height);
            dismissButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
            dismissButton.contentMode = UIViewContentModeCenter;
            [dismissButton setImage:dismissIconImage forState:UIControlStateNormal];
            [accessoryView addSubview:dismissButton];
            
            breakLine = [[UIView alloc] initWithFrame:CGRectMake(accessoryView.frame.size.width - 43.0f, 8.0f, 1.0f, accessoryView.frame.size.height - 16.0f)];
            breakLine.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
            breakLine.backgroundColor = [UIColor colorWithWhite:0.8f alpha:1.0f];
            [accessoryView addSubview:breakLine];
            
            whatsthisButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [whatsthisButton addTarget:self action:@selector(whatsthisTapped:) forControlEvents:UIControlEventTouchUpInside];
            whatsthisButton.frame = CGRectMake(accessoryView.frame.size.width - 140.0f, (accessoryView.frame.size.height - 24.0f) / 2, 90.0f, 24.0f);
            whatsthisButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
            [whatsthisButton setTitle:@"What's this" forState:UIControlStateNormal];
            [whatsthisButton setTitleColor:[UIColor colorWithWhite:0.5f alpha:1.0f] forState:UIControlStateNormal];
            whatsthisButton.titleLabel.font = [UIFont systemFontOfSize:14.0f];
            [accessoryView addSubview:whatsthisButton];
        }
    }
    return self;
}

- (void)layoutToolbarElements {
    float leftMargin = 10.0f;
    // Position elements in middle if overlayInputAccessoryView
    if (self.overlayInputAccessoryView) {
        leftMargin = (accessoryView.bounds.size.width - fillrIconView.frame.size.width - 3.0f - 138.0f) / 2;
    }
    
    fillrIconView.frame = CGRectMake(leftMargin, fillrIconView.frame.origin.y, fillrIconView.frame.size.width, fillrIconView.frame.size.height);
    
    leftMargin = fillrIconView.frame.origin.x + fillrIconView.frame.size.width + 3.0f;
    autofillButton.frame = CGRectMake(leftMargin, (accessoryView.frame.size.height - 24.0f) / 2, 138.0f, 24.0f);
    
    if ([self hasFillrInstalled]) {
        whatsthisButton.hidden = YES;
    } else {
        if (self.overlayInputAccessoryView) {
            whatsthisButton.hidden = YES;
        } else {
            whatsthisButton.hidden = NO;
        }
    }
    
    if (self.overlayInputAccessoryView) {
        dismissButton.hidden = YES;
        breakLine.hidden = YES;
    } else {
        dismissButton.hidden = NO;
        breakLine.hidden = NO;
    }
}

- (BOOL)hasFillrInstalled {
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"fillr://"]];
}

- (void)autofillTouchDown:(id)sender {
    fillrIconView.alpha = 0.6f;
}

- (void)autofillTapped:(id)sender {
    fillrIconView.alpha = 1.0f;
    // Download latest widget
    // Send a synchronous request
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        @autoreleasepool {
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://d2o8n2jotd2j7i.cloudfront.net/widget/ios/sdk/MobileWidget.js"]];
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                NSString *localWidgetFileName = [documentsDirectory stringByAppendingPathComponent:@"UnwrappedMobileWidget"];
                
                NSString *widgetStringValue;
                if (error == nil) {
                    widgetStringValue = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    
                    [widgetStringValue writeToFile:localWidgetFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
                } else {
                    if ([[NSFileManager defaultManager] fileExistsAtPath:localWidgetFileName]) {
                        widgetStringValue = [NSString stringWithContentsOfFile:localWidgetFileName encoding:NSUTF8StringEncoding error: NULL];
                    } else {
                        NSBundle *bundle = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"FillrSDKBundle" withExtension:@"bundle"]];
                        NSString *widgetPath = [bundle pathForResource:@"UnwrappedMobileWidget" ofType:@"js"];
                        widgetStringValue = [NSString stringWithContentsOfFile:widgetPath encoding:NSUTF8StringEncoding error: NULL];
                    }
                }
                
                // Inject javascript then launch fillr
                [self evaluateJavaScript:widgetStringValue];
                NSString *resultString = [self evaluateJavaScript:@"window.PopWidgetInterface.getFields()"];
                BOOL hasResult = false;
                if (resultString && [resultString isKindOfClass:[NSString class]]) {
                    NSData *objectData = [resultString dataUsingEncoding:NSUTF8StringEncoding];
                    NSMutableDictionary *result = [[NSJSONSerialization JSONObjectWithData:objectData
                                                                                   options:NSJSONReadingMutableContainers
                                                                                     error:nil] mutableCopy];
                    if ([result isKindOfClass:[NSDictionary class]]) {
                        [result setObject:urlSchema ? urlSchema : @"fillrbrowser" forKey:@"returnAppDomain"];
                        
                        // Pass through sdkversion and dev key so these can be used in analytics Trello #339
                        [result setObject:kFillrSDKVersion forKey:@"sdkversion"];
                        [result setObject:devKey forKey:@"devkey"];
                        
                        NSError *error;
                        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result
                                                                           options:NSJSONWritingPrettyPrinted
                                                                             error:&error];
                        
                        if ([self hasFillrInstalled]) {
                            if (self.delegate) {
                                [self.delegate fillrStateChanged:FillrStateOpenApp currentWebView:webView];
                            }
                            
                            NSString *result64 = [jsonData base64EncodedUrlString];
                            NSString *urlString = [NSString stringWithFormat:@"fillr://mapping?metadata=%@&sdkversion=%@&devkey=%@", result64, kFillrSDKVersion, devKey];
                            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                        } else {
                            UIPasteboard *appPasteBoard = [UIPasteboard generalPasteboard];
                            appPasteBoard.persistent = YES;
                            [appPasteBoard setData:jsonData forPasteboardType:@"com.fillr.browsersdk.metadata"];
                            hasResult = true;
                        }
                    }
                }
                
                if (![self hasFillrInstalled]) {
                    // Redirect to app store
                    FillrAlertView *anAlert = [[FillrAlertView alloc] initWithTitle:@"Secure Autofill by Fillr"
                                                                            message:@"Fillr is the most secure & accurate autofill in the world and it’s free. Setup takes under a minute and you’ll be returned to this page."
                                                                           delegate:nil
                                                                  cancelButtonTitle:@"Install Fillr"
                                                                  otherButtonTitles:@"Not now", nil];
                    anAlert.clickedButtonBlock = ^(NSInteger buttonIndex){
                        if (buttonIndex == 0) {
                            if (!hasResult) {
                                // Paste reture url
                                UIPasteboard *appPasteBoard = [UIPasteboard generalPasteboard];
                                appPasteBoard.persistent = YES;
                                [appPasteBoard setData:[urlSchema dataUsingEncoding:NSUTF8StringEncoding] forPasteboardType:@"com.fillr.browsersdk.returndomain"];
                            }
                            
                            [self installFillr];
                        }
                    };
                    [anAlert show];
                }
            });
        }
    });
}

- (void)installFillr {
    if (self.delegate) {
        [self.delegate fillrStateChanged:FillrStateDownloadingApp currentWebView:webView];
    }
    
    // Redirect to app store
    NSString *iTunesLink = @"https://itunes.apple.com/us/app/apple-store/id971588428?mt=8";
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink]];
}

- (void)whatsthisTapped:(id)sender {
    UIWindow *theWindow = [[UIApplication sharedApplication] keyWindow];
    [theWindow endEditing:YES];
    
    FillrToolbarPopup *popup = [[FillrToolbarPopup alloc] initWithFrame:CGRectMake(0.0f, 0.0f, theWindow.bounds.size.width, theWindow.bounds.size.height)];
    [theWindow addSubview:popup];
}

- (void)dismissTapped:(id)sender {
    // Dismiss the bar
    accessoryView.hidden = YES;
    shouldHideAutofillBar = YES;
}

- (NSString *)evaluateJavaScript:(NSString *)javaScriptString {
    if ([webView isKindOfClass:[WKWebView class]]) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block NSString *evaluateResult = nil;
        [(WKWebView *)webView evaluateJavaScript:javaScriptString completionHandler:^(id result, NSError *error) {
            if (!error) {
                evaluateResult = (NSString *)result;
            }
            dispatch_semaphore_signal(semaphore);
        }];
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
        }
        //dispatch_release(semaphore);
        return evaluateResult;
    } else if ([webView isKindOfClass:[UIWebView class]]) {
        return [(UIWebView *)webView stringByEvaluatingJavaScriptFromString:javaScriptString];
    } else {
        return nil;
    }
}

- (void)initialiseWithDevKey:(NSString *)devKeyToSet andUrlSchema:(NSString *)urlSchemaToSet {
    devKey = devKeyToSet;
    urlSchema = urlSchemaToSet;
}

- (BOOL)canHandleOpenURL:(NSURL *)url {
    return [[url absoluteString] hasPrefix:urlSchema ? urlSchema : @"fillrbrowser"];
}

- (void)handleOpenURL:(NSURL *)url {
    if ([[url absoluteString] rangeOfString:@"fillform"].location != NSNotFound) {
        NSDictionary *parameters = [self parserQueryStringsForURL:[url absoluteString]];
        if ([parameters objectForKey:@"fields"] && [parameters objectForKey:@"payload"]) {
            NSString *fields64 = [parameters objectForKey:@"fields"];
            NSString *fields = [[NSString alloc] initWithData:[NSData dataFromBase64UrlString:fields64] encoding:NSUTF8StringEncoding];
            
            NSString *payload64 = [parameters objectForKey:@"payload"];
            NSString *payload = [[NSString alloc] initWithData:[NSData dataFromBase64UrlString:payload64] encoding:NSUTF8StringEncoding];
            
            [[Fillr sharedInstance] fillFormWithFields:fields andPayload:payload];
            [webView endEditing:YES];
        }
    }
}

- (NSDictionary *)parserQueryStringsForURL:(NSString *)urlString {
    NSString *queryString = @"";
    if ([urlString rangeOfString:@"?"].location != NSNotFound) {
        queryString = [[urlString componentsSeparatedByString:@"?"] objectAtIndex:1];
    }/* else if ([urlString rangeOfString:@"//"].location != NSNotFound) {
      queryString = [[urlString componentsSeparatedByString:@"//"] objectAtIndex:1];
      }*/
    NSArray *components = [queryString componentsSeparatedByString:@"&"];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    for (NSString *component in components) {
        if ([component rangeOfString:@"="].location != NSNotFound) {
            NSArray *subcomponents = [component componentsSeparatedByString:@"="];
            [parameters setObject:[[subcomponents objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                           forKey:[[[subcomponents objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lowercaseString]];
        }
    }
    return parameters;
}

- (void)trackWebview:(UIView *)webViewToTrack {
    webView = webViewToTrack;
}

- (void)setEnabled:(BOOL)enabled {
    shouldHideAutofillBar = !enabled;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:shouldHideAutofillBar forKey:kShouldHideAutofillBar];
    [defaults synchronize];
}

- (void)fillFormWithFields:(NSString *)fields andPayload:(NSString *)payload {
    NSString *fillrFunctionWithParameters = [NSString stringWithFormat:@"window.PopWidgetInterface.populateWithMappings(JSON.parse('%@'), JSON.parse('%@'));", [self escapeJavascriptString:fields], [self escapeJavascriptString:payload]];
    [self evaluateJavaScript:fillrFunctionWithParameters];
    
    if (self.delegate) {
        [self.delegate fillrStateChanged:FillrStateFormFilled currentWebView:webView];
    }
}

- (NSString *)escapeJavascriptString:(NSString *)javascriptString {
    javascriptString = [javascriptString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    javascriptString = [javascriptString stringByReplacingOccurrencesOfString:@"\\t" withString:@" "];
    javascriptString = [javascriptString stringByReplacingOccurrencesOfString:@"\\r" withString:@" "];
    javascriptString = [javascriptString stringByReplacingOccurrencesOfString:@"\\n" withString:@" "];
    return javascriptString;
}

- (void)addObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    // If user turned toolbar off by tapping dismiss button
    if (shouldHideAutofillBar) {
        return;
    }
    
    // If device OS lower then iOS 8
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        return;
    }
    
    if (webView) {
        if (![self hasFocus:webView]) {
            accessoryView.hidden = YES;
            return;
        }
        
        NSDictionary *info = [notification userInfo];
        [[info objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];
        
        UIView *keyboardAccessoryView;
        if (self.overlayInputAccessoryView) {
            keyboardAccessoryView = [self keyboardAccessoryView];
        }
        if (self.overlayInputAccessoryView && keyboardAccessoryView) {
            accessoryView.frame = CGRectMake(keyboardAccessoryView.bounds.size.width / 4, 0.0f, keyboardAccessoryView.bounds.size.width / 2, keyboardAccessoryView.bounds.size.height);
            accessoryView.backgroundColor = [UIColor clearColor];
            [keyboardAccessoryView addSubview:accessoryView];
        } else {
            UIWindow *theWindow = [[UIApplication sharedApplication] keyWindow];
            accessoryView.frame = CGRectMake(0.0f, theWindow.bounds.size.height - keyboardFrame.size.height - accessoryView.frame.size.height, theWindow.bounds.size.width, accessoryView.frame.size.height);
            [theWindow addSubview:accessoryView];
        }
        accessoryView.hidden = NO;
        [self layoutToolbarElements];
    }
}

- (BOOL)hasFocus:(UIView *)view {
    if ([view isFirstResponder]) return YES;
    
    for (UIView *subView in [view subviews]) {
        if ([self hasFocus:subView]) {
            return YES;
        }
    }
    
    return NO;
}

- (UIView *)keyboardAccessoryView {
    UIWindow *keyboardWindow = nil;
    for (UIWindow *testWindow in [[UIApplication sharedApplication] windows]) {
        if (![[testWindow class] isEqual : [UIWindow class]]) {
            keyboardWindow = testWindow;
            break;
        }
    }
    // Locate UIWebFormView.
    for (UIView *possibleFormView in [keyboardWindow subviews]) {
        if ([[possibleFormView description] hasPrefix:@"<UIPeripheralHostView"] || [[possibleFormView description] hasPrefix : @"<UIInputSetContainerView"]) {
            for (UIView* peripheralView in possibleFormView.subviews) {
                for (UIView* peripheralView_sub in peripheralView.subviews) {
                    // the accessory bar
                    if ([[peripheralView_sub description] hasPrefix : @"<UIWebFormAccessory"]) {
                        return peripheralView_sub;
                    }
                }
            }
        }
    }
    return nil;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    //accessoryView.frame = CGRectMake(0.0f, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width, accessoryView.frame.size.height);
    accessoryView.hidden = YES;
}

- (void)dealloc {
    [self removeObservers];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

@end
