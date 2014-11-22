//
//  SGLatestViewController.m
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012-2014 Simon Peter Grätzer. All rights reserved.
//

#import "SGBlankController.h"

#import "NSStringPunycodeAdditions.h"
#import "SGBottomView.h"
#import "SGBrowserViewController.h"

#import "FXTabsViewController.h"
#import "FXSyncStock.h"

@implementation SGBlankController

#pragma mark - State Preservation and Restoration

+ (UIViewController *) viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder {
    SGBlankController *vc = [SGBlankController new];
    vc.restorationIdentifier = [identifierComponents lastObject];
    vc.restorationClass = [SGBlankController class];
    return vc;
}

#pragma mark - State Preservation and Restoration

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (UIView *)rotatingFooterView {
    return self.bottomView;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width + SG_TAB_WIDTH, self.scrollView.bounds.size.height);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.restorationIdentifier = NSStringFromClass([self class]);
    self.restorationClass = [self class];
    
    self.title = NSLocalizedString(@"New Tab", @"New Tab page");//NSLocalizedString(@"Untitled", @"Untitled tab");
    self.view.backgroundColor = [UIColor whiteColor];
    
    NSArray *titles = @[NSLocalizedString(@"Most popular", @"Most popular websites"),
    NSLocalizedString(@"Other devices", @"Tabs of other devices")];
    NSArray *images = @[[UIImage imageNamed:@"dialpad"], [UIImage imageNamed:@"monitor"]];
    
    SGBottomView *bottomView = [[SGBottomView alloc] initWithTitles:titles images:images];
    CGRect rect = bottomView.frame;
    rect.origin.y = self.view.bounds.size.height - bottomView.frame.size.height;
    rect.size.width = self.view.frame.size.width;
    bottomView.frame = rect;
    bottomView.container = self;
    [self.view addSubview:bottomView];
    _bottomView = bottomView;
    
    CGRect scrollFrame = CGRectMake(0, 0, self.view.bounds.size.width,
                                  self.view.bounds.size.height - bottomView.frame.size.height);
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:scrollFrame];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.backgroundColor = [UIColor clearColor];
    scrollView.scrollsToTop = NO;
    scrollView.bounces = NO;
    scrollView.pagingEnabled = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.delegate = self;
    [self.view insertSubview:scrollView belowSubview:_bottomView];
    _scrollView = scrollView;
    
    SGPreviewPanel *previewPanel = [[SGPreviewPanel alloc] initWithFrame:scrollFrame];
    previewPanel.delegate = self;
    [scrollView addSubview:previewPanel];
    _previewPanel = previewPanel;
    
    FXTabsViewController *tabBrowser = [[FXTabsViewController alloc] initWithStyle:UITableViewStylePlain];
    [self addChildViewController:tabBrowser];
    tabBrowser.view.frame = CGRectMake(_scrollView.bounds.size.width, 0, SG_TAB_WIDTH, _scrollView.bounds.size.height);
    tabBrowser.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
    [self.scrollView addSubview:tabBrowser.view];
    [tabBrowser didMoveToParentViewController:self];
    self.tabsController = tabBrowser;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:kFXDataChangedNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CGRect scrollFrame = CGRectMake(0, 0, self.view.bounds.size.width,
                                    self.view.bounds.size.height - _bottomView.frame.size.height);
    _scrollView.frame = scrollFrame;
    scrollFrame.size.width += SG_TAB_WIDTH;
    _scrollView.contentSize = scrollFrame.size;
    _previewPanel.frame = _scrollView.bounds;
}

- (void)refresh {
    [self.previewPanel refresh];
}

#pragma mark - SGPreviewPanelDelegate
- (void)openNewTab:(FXSyncItem *)item {
    SGBrowserViewController *browser = (SGBrowserViewController *)self.parentViewController;
    NSString *urlS = [item urlString];
    NSURL *url;
    if ([urlS length] && (url = [NSURL URLWithUnicodeString:urlS])) {
        [browser addTabWithURLRequest:[NSMutableURLRequest requestWithURL:url]
                                title:[item title]];
    }
}

- (void)open:(FXSyncItem *)item {
    SGBrowserViewController *browser = (SGBrowserViewController *)self.parentViewController;
    NSString *urlS = [item urlString];
    NSURL *url;
    if ([urlS length] && (url = [NSURL URLWithUnicodeString:urlS])) {
        [browser openURLRequest:[NSMutableURLRequest requestWithURL:url]
                                title:[item title]];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.bottomView.markerPosititon = scrollView.contentOffset.x/SG_TAB_WIDTH;
}

@end
