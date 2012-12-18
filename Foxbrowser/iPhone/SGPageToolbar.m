//
//  SGPageToolbar.m
//  Foxbrowser
//
//  Created by Simon Grätzer on 17.12.12.
//  Copyright (c) 2012 Simon Peter Grätzer. All rights reserved.
//

#import "SGPageToolbar.h"
#import "SGTabDefines.h"
#import "SGSearchField.h"

@implementation SGPageToolbar {
    UIColor *_bottomColor;
    BOOL _searchBarVisible;
}

- (id)initWithFrame:(CGRect)frame browser:(SGBrowserViewController *)browser;
{
    self = [super initWithFrame:frame];
    if (self) {
        _bottomColor = kTabColor;
        
        _searchField = [[SGSearchField alloc] initWithDelegate:self];
        [self addSubview:_searchField];
        
        _searchController = [SGSearchController new];
        _searchController.delegate = self;
        
        _browser = browser;
    }
    return self;
}

- (void)layoutSubviews {
    CGSize size = self.bounds.size;
    
    CGSize searchSize = _searchField.bounds.size;
    _searchField.frame = CGRectMake(30., (size.height - searchSize.height)/2, size.width - 30., searchSize.height);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint topCenter = CGPointMake(CGRectGetMidX(self.bounds), 0.0f);
    CGPoint bottomCenter = CGPointMake(CGRectGetMidX(self.bounds), self.bounds.size.height);
    CGFloat locations[2] = { 0.00, 1.0};
    
    CGFloat redEnd, greenEnd, blueEnd, alphaEnd;
    [_bottomColor getRed:&redEnd green:&greenEnd blue:&blueEnd alpha:&alphaEnd];
    //Two colour components, the start and end colour both set to opaque. Red Green Blue Alpha
    CGFloat components[8] = { 244./255., 245./255., 247./255., 1.0, redEnd, greenEnd, blueEnd, 1.0};
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, topCenter, bottomCenter, 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorspace);
}

- (void)updateChrome {
    if (![self.searchField isFirstResponder]) {
        self.searchField.text = [self.browser URL].absoluteString;
    }
}

#pragma mark - UITextFieldDelegate
//- (void)textFieldDidBeginEditing:(UITextField *)textField {
//    [self presentSearchController];
//}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *searchText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (searchText.length > 0 && !_searchBarVisible) {
        [self presentSearchController];
    } else if (searchText.length == 0 && _searchBarVisible) {
        [self dismissSearchController];
    }
    
    // When the search string changes, filter the recents list accordingly.
    if (_searchBarVisible) // TODO
        [self.searchController filterResultsUsingString:searchText];
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    // If the user finishes editing text in the search bar by, for example:
    // tapping away rather than selecting from the recents list, then just dismiss the popover
    [self dismissSearchController];
    
    if ([self.browser respondsToSelector:@selector(URL)]) {
        self.searchField.text = [self.browser URL].absoluteString;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // When the search button is tapped, add the search term to recents and conduct the search.
    NSString *searchString = [textField text];
    [self finishSearch:searchString title:nil];
    return YES;
}

#pragma mark - SGSearchController

- (void)presentSearchController {
    _searchBarVisible = YES;
}

- (void)dismissSearchController {
    _searchBarVisible = NO;
}

#pragma mark - SGSearchControllerDelegate

- (NSString *)text {
    return self.searchField.text;
}

- (void)finishSearch:(NSString *)searchString title:(NSString *)title {
    [self.browser handleURLInput:searchString title:title];
    
    // Conduct the search. In this case, simply report the search term used.
    [self dismissSearchController];
    [self.searchField resignFirstResponder];
}

@end
