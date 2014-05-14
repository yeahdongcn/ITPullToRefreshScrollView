//
//  AppDelegate.m
//  ITPullToRefreshScrollView
//
//  Created by Ilija Tovilo on 9/25/13.
//  Copyright (c) 2013 Ilija Tovilo. All rights reserved.
//

#import "AppDelegate.h"
#import "ITPullToRefreshScrollView.h"


@interface AppDelegate ()

@property (nonatomic, strong) NSMutableArray *data;

@property (assign) IBOutlet NSPopover *refreshPopover;
@property (assign) IBOutlet NSButton  *refreshButton;

@property (assign) IBOutlet NSPopover *morePopover;
@property (assign) IBOutlet NSButton *moreButton;

@end


@implementation AppDelegate

- (void)__buttonClicked:(NSButton *)button
{
    if (button == self.refreshButton) {
        [self pullToRefreshView:self.scrollView didStartRefreshingEdge:ITPullToRefreshEdgeTop];
    } else if (button == self.moreButton) {
        [self pullToRefreshView:self.scrollView didStartRefreshingEdge:ITPullToRefreshEdgeBottom];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.data = [@[  ] mutableCopy];
    self.scrollView.refreshableEdges = ITPullToRefreshEdgeTop | ITPullToRefreshEdgeBottom;
    [self.tableView reloadData];
    
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(__buttonClicked:)];
    
    [self.moreButton setTarget:self];
    [self.moreButton setAction:@selector(__buttonClicked:)];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.data.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"default" owner:self];
    cellView.textField.stringValue = self.data[row];
    
    return cellView;
}

- (void)pullToRefreshView:(ITPullToRefreshScrollView *)scrollView didStartRefreshingEdge:(ITPullToRefreshEdge)edge {
    double delayInSeconds = ((arc4random() % 10) / 10.0) * 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void){
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (edge & ITPullToRefreshEdgeTop) {
                [self.data insertObject:@"Test 1" atIndex:0];
                [self.data insertObject:@"Test 2" atIndex:0];
            } else if (edge & ITPullToRefreshEdgeBottom) {
                for (int i = 0; i < 50; i++) {
                    [self.data addObject:[NSString stringWithFormat:@"Test %d", i]];
                }
            }
            
            [scrollView stopRefreshingEdge:edge];
        });
    });
}

- (void)pullToRefreshView:(ITPullToRefreshScrollView *)scrollView didStopRefreshingEdge:(ITPullToRefreshEdge)edge {
    NSRange range;
    
    if (edge & ITPullToRefreshEdgeTop) {
        range = NSMakeRange(0, 2);
    }
    else if (edge & ITPullToRefreshEdgeBottom) range = NSMakeRange(self.data.count - 50, 50);
    
    [self.tableView beginUpdates];
    {
        [self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]
                              withAnimation:NSTableViewAnimationSlideDown];
    }
    [self.tableView endUpdates];
}

- (void)pullToRefreshView:(ITPullToRefreshScrollView *)scrollView didReachRefreshingEdge:(ITPullToRefreshEdge)edge
{
    switch (edge) {
        case ITPullToRefreshEdgeNone:
            if (self.refreshPopover.isShown) {
                [self.refreshPopover close];
            }
            if (self.morePopover.isShown) {
                [self.morePopover close];
            }
            break;
        case ITPullToRefreshEdgeTop:
            if (!self.refreshPopover.isShown) {
                [self.refreshPopover showRelativeToRect:CGRectMake(self.tableView.bounds.size.width - 2, 0, 2, 2)
                                                 ofView:self.tableView
                                          preferredEdge:NSMaxYEdge];
            }
            break;
        case ITPullToRefreshEdgeBottom:
            if (!self.morePopover.isShown) {
                [self.morePopover showRelativeToRect:CGRectMake(self.tableView.bounds.size.width - 2, self.tableView.bounds.size.height - 2, 2, 2)
                                              ofView:self.tableView
                                       preferredEdge:NSMaxYEdge];
            }
            break;
        default:
            break;
    }
}

@end
