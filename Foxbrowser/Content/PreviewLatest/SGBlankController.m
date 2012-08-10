//
//  SGLatestViewController.m
//  Foxbrowser
//
//  Created by simon on 13.07.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGBlankController.h"
#import "SGTabsViewController.h"
#import "UIViewController+TabsController.h"
#import "TabBrowserController.h"
#import "SGBottomView.h"

@implementation SGBlankController
@synthesize tabBrowser = _tabBrowser, previewPanel = _previewPanel, scrollView = _scrollView;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768., 925.)];
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 768., 865.)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.canCancelContentTouches = NO;
    self.scrollView.bounces = NO;
    self.scrollView.backgroundColor = [UIColor whiteColor];
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"New Tab", @"New Tab");
    
    CGRect bottomFrame = CGRectMake(0, self.view.bounds.size.height - 60., self.view.bounds.size.width, 60.);
    self.bottomView = [[SGBottomView alloc] initWithFrame:bottomFrame];
    self.bottomView.container = self;
    [self.view addSubview:self.bottomView];

    self.tabBrowser = [[TabBrowserController alloc] initWithStyle:UITableViewStylePlain];
    [self addChildViewController:self.tabBrowser];
    [self.scrollView addSubview:self.tabBrowser.tableView];
    [self.tabBrowser didMoveToParentViewController:self];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    CGSize scrollSize = self.scrollView.bounds.size;
    CGSize tabSize = CGSizeMake(SG_TAB_WIDTH, scrollSize.height);
    self.tabBrowser.view.frame = CGRectMake(scrollSize.width, 0, tabSize.width, scrollSize.height);
    self.scrollView.contentSize = CGSizeMake(scrollSize.width + tabSize.width, scrollSize.height);
}

- (UIView *)rotatingFooterView {
    return self.bottomView;
}

- (void)viewWillAppear:(BOOL)animated {
    CGSize scrollSize = self.scrollView.bounds.size;
    CGSize tabSize = CGSizeMake(SG_TAB_WIDTH, scrollSize.height);
    self.scrollView.contentSize = CGSizeMake(scrollSize.width + tabSize.width, scrollSize.height);
    self.tabBrowser.view.frame = CGRectMake(scrollSize.width, 0, tabSize.width, scrollSize.height);
    
    self.previewPanel = [SGPreviewPanel instance];
    self.previewPanel.delegate = self;
    self.previewPanel.frame = self.scrollView.bounds;
    //[self.previewPanel refresh];
    [self.scrollView addSubview:self.previewPanel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:kWeaveDataRefreshNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.tabsViewController updateChrome];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    self.previewPanel = nil;
    [self.tabBrowser willMoveToParentViewController:nil];
    [self.tabBrowser removeFromParentViewController];
    self.tabBrowser = nil;
}

- (void)refresh {
    [self.previewPanel refresh];
}

#pragma mark - SGPreviewPanelDelegate
- (void)openNewTab:(SGPreviewTile *)tile {
    NSDictionary *item = tile.info;
    if (item) {
        NSString *url = [item objectForKey:@"url"];
        if (url) {
            SGTabsViewController *tabsC = (SGTabsViewController *)self.parentViewController;
            [tabsC addTabWithURL:[NSURL URLWithString:url] withTitle:tile.label.text];
        }
    }
}

- (void)open:(SGPreviewTile *)tile {
    NSDictionary *item = tile.info;
    if (item) {
        NSString *url = [item objectForKey:@"url"];
        if (url) {
            SGTabsViewController *tabsC = (SGTabsViewController *)self.parentViewController;
            [tabsC handleURLInput:url withTitle:tile.label.text];
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.bottomView.markerPosititon = scrollView.contentOffset.x/SG_TAB_WIDTH;
}

@end
