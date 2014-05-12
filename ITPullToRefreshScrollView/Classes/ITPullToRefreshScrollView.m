//
//  ITPullToRefreshScrollView.m
//  ITPullToRefreshScrollView
//
//  Created by Ilija Tovilo on 9/25/13.
//  Copyright (c) 2013 Ilija Tovilo. All rights reserved.
//

#import "ITPullToRefreshScrollView.h"
#import <QuartzCore/QuartzCore.h>
#import "ITPullToRefreshEdgeView.h"
#import "ITPullToRefreshClipView.h"
#import "DuxScrollViewAnimation.h"

void dispatch_sync_on_main(dispatch_block_t block);
void dispatch_sync_on_main(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}


@interface ITPullToRefreshScrollView () {
    BOOL _isLocked;
    NSUInteger _edgesToBeRemoved;
    NSMutableDictionary *_edgeViews;
}
@end


@implementation ITPullToRefreshScrollView

#pragma mark - Init

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self initialSetup];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initialSetup];
    }
    return self;
}

- (void)initialSetup {
    _edgeViews = [NSMutableDictionary dictionary];
    [self installCustomClipView];
    
    self.contentView.postsBoundsChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boundsDidChange:) name:NSViewBoundsDidChangeNotification object:self.contentView];
}

- (IBAction)boundsDidChange:(NSNotification *)notification {
    [self scrollingChangedWithEvent:nil];
}

- (void)installCustomClipView {
    if ([self.contentView isKindOfClass:[ITPullToRefreshClipView class]])
        return;
    
    ITPullToRefreshClipView *newClipView = [[ITPullToRefreshClipView alloc] initWithFrame:NSZeroRect];
    
    newClipView.documentView = self.contentView.documentView;
    self.contentView = newClipView;
    
    newClipView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                          @"H:|[view]|" options:0 metrics:nil views:@{@"view": newClipView}]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                          @"V:|[view]|" options:0 metrics:nil views:@{@"view": newClipView}]];
}


#pragma mark - NSResponder

- (void)scrollingChangedWithEvent:(NSEvent *)theEvent {
    if (_isLocked) return;
    
    void (^scrollBlock)(ITPullToRefreshEdge edge, CGFloat (^progressBlock)(void)) =
    ^(ITPullToRefreshEdge edge, CGFloat (^progressBlock)()) {
        if (!(_refreshingEdges & edge)) {
            ITPullToRefreshEdgeView *edgeView = [self edgeViewForEdge:edge];
            CGFloat progress = progressBlock();
            
            if ((edge & self.refreshableEdges) && progress > 0) {
                [edgeView pullToRefreshScrollView:self didScrollWithProgress:progress];
                
                if (progress >= 1.0) {
                    if (!(self.triggeredEdges & edge)) {
                        [edgeView pullToRefreshScrollViewDidTriggerRefresh:self];
                    }
                    
                    _triggeredEdges |= edge;
                } else {
                    if (self.triggeredEdges & edge) {
                        [edgeView pullToRefreshScrollViewDidUntriggerRefresh:self];
                    }
                    
                    _triggeredEdges &= ~edge;
                }
            }
        }
    };
    
    // Update edges
    if ((ITPullToRefreshEdgeTop & self.refreshableEdges)) {
        scrollBlock(ITPullToRefreshEdgeTop, ^{
            ITPullToRefreshEdgeView *edgeView = [self edgeViewForEdge:ITPullToRefreshEdgeTop];
            return (1.0 /
                    edgeView.frame.size.height *
                    -self.contentView.bounds.origin.y);
        });
    }
    if ((ITPullToRefreshEdgeBottom & self.refreshableEdges)) {
        scrollBlock(ITPullToRefreshEdgeBottom, ^{
            ITPullToRefreshEdgeView *edgeView = [self edgeViewForEdge:ITPullToRefreshEdgeBottom];
            
            return (1.0 /
                    edgeView.bounds.size.height *
                    -(edgeView.frame.origin.y - (self.contentView.bounds.origin.y + self.contentView.bounds.size.height)));
        });
    }
}

- (void)scrollingEndedWithEvent:(NSEvent *)theEvent {
    if (_isLocked) return;
    
    [self enumerateThroughEdges:^(ITPullToRefreshEdge edge) {
        if (_triggeredEdges & edge) {
            _triggeredEdges &= ~edge;
            _refreshingEdges |= edge;
            
            [[self edgeViewForEdge:edge] pullToRefreshScrollViewDidStartRefreshing:self];
            
            if ([self.delegate respondsToSelector:@selector(pullToRefreshView:didStartRefreshingEdge:)]) {
                [self.delegate pullToRefreshView:self didStartRefreshingEdge:edge];
            }
        }
    }];
}

static CGFloat const kScrollerKnobVerticalSpacing = 2.0f;

- (void)scrollingWithEvent:(NSEvent *)theEvent {
    if (_isLocked) return;

    CGFloat top = [self.verticalScroller rectForPart:NSScrollerKnob].origin.y - kScrollerKnobVerticalSpacing;
    if (top == 0 && [theEvent deltaY] > 0) {
        if ([self.delegate respondsToSelector:@selector(pullToRefreshView:didReachRefreshingEdge:)]) {
            [self.delegate pullToRefreshView:self didReachRefreshingEdge:ITPullToRefreshEdgeTop];
        }
        return;
    }
    
    CGFloat bottom = [self.verticalScroller rectForPart:NSScrollerKnob].origin.y + [self.verticalScroller rectForPart:NSScrollerKnob].size.height + kScrollerKnobVerticalSpacing;
    if (bottom == [self.verticalScroller rectForPart:NSScrollerKnobSlot].size.height
        && [theEvent deltaY] < 0) {
        if ([self.delegate respondsToSelector:@selector(pullToRefreshView:didReachRefreshingEdge:)]) {
            [self.delegate pullToRefreshView:self didReachRefreshingEdge:ITPullToRefreshEdgeBottom];
        }
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(pullToRefreshView:didReachRefreshingEdge:)]) {
        [self.delegate pullToRefreshView:self didReachRefreshingEdge:ITPullToRefreshEdgeNone];
    }
}

- (void)scrollWheel:(NSEvent *)theEvent {
    if (_isLocked) return;
    
    const NSEventPhase eventPhase = theEvent.phase;
    
    if (eventPhase & NSEventPhaseChanged) {
        [self scrollingChangedWithEvent:theEvent];
    } else if (eventPhase & NSEventPhaseEnded) {
        [self scrollingEndedWithEvent:theEvent];
    } else if (eventPhase == NSEventPhaseNone) {
        [self scrollingWithEvent:theEvent];
    }
        
    [super scrollWheel:theEvent];
}

- (void)stopRefreshingEdge:(ITPullToRefreshEdge)edge {
    dispatch_sync_on_main(^{
        [[self edgeViewForEdge:edge] pullToRefreshScrollViewDidStopRefreshing:self];
        
        if (_refreshingEdges & edge) {
            _isLocked = YES;
            
            NSPoint scrollPoint = self.contentView.bounds.origin;
            NSRect cvb = self.contentView.bounds;
            NSRect evf = [self edgeViewForEdge:edge].frame;
            
            if (edge == ITPullToRefreshEdgeTop) {
                if (cvb.origin.y < 0) {
                    scrollPoint.y += -cvb.origin.y;
                } else {
                    scrollPoint.y += [self edgeViewForEdge:edge].frame.size.height;
                }
            } else if (edge == ITPullToRefreshEdgeBottom) {
                if (cvb.origin.y + cvb.size.height > evf.origin.y) {
                    scrollPoint.y -= -(evf.origin.y - (cvb.origin.y + cvb.size.height));
                } else {
                    scrollPoint.y -= evf.size.height;
                }
            }
            
            _edgesToBeRemoved |= edge;
            [DuxScrollViewAnimation animatedScrollToPoint:scrollPoint
                                             inScrollView:self
                                                 delegate:self];
        }
    });
}

- (void)animationDidEnd:(NSAnimation *)animation {
    dispatch_sync_on_main(^{
        [self enumerateThroughEdges:^(ITPullToRefreshEdge edge) {
            if (_edgesToBeRemoved & edge) {
                _edgesToBeRemoved &= ~edge;
                _refreshingEdges &= ~edge;
                
                [self imitateScrollingEventForEdge:edge];
                
                [[self edgeViewForEdge:edge] pullToRefreshScrollViewDidStopAnimating:self];
                
                if ([self.delegate respondsToSelector:@selector(pullToRefreshView:didStopRefreshingEdge:)]) {
                    [self.delegate pullToRefreshView:self didStopRefreshingEdge:edge];
                }
            }
        }];
        
        if (!_edgesToBeRemoved) _isLocked = NO;
    });
}

- (void)imitateScrollingEventForEdge:(ITPullToRefreshEdge)edge {
    NSInteger amount = 0;
    
    if (edge == ITPullToRefreshEdgeTop) amount = 1;
    else if (edge == ITPullToRefreshEdgeBottom) amount = -1;
    
    CGEventRef cgEvent   = CGEventCreateScrollWheelEvent(NULL,
                                                         kCGScrollEventUnitLine,
                                                         1,
                                                         (int)amount,
                                                         0);
    
    NSEvent *scrollEvent = [NSEvent eventWithCGEvent:cgEvent];
    [self scrollWheel:scrollEvent];
    CFRelease(cgEvent);
}


#pragma mark - ITPullToRefreshScrollView Methods

+ (Class)edgeViewClassForEdge:(ITPullToRefreshEdge)edge {
    return [ITPullToRefreshEdgeView class];
}


#pragma mark - Properties

- (ITPullToRefreshEdgeView *)edgeViewForEdge:(ITPullToRefreshEdge)edge {
    if (!_edgeViews[@( edge )]) {
        [_edgeViews setObject:[[[[self class] edgeViewClassForEdge:ITPullToRefreshEdgeBottom] alloc] initWithEdge:edge]
                       forKey:@( edge )];
    }
    
    return _edgeViews[@( edge )];
}

- (void)setRefreshableEdges:(NSUInteger)refreshableEdges {
    _refreshableEdges = refreshableEdges;
    
    [self enumerateThroughEdges:^(ITPullToRefreshEdge edge) {
        if (_refreshableEdges & edge)
        {
            ITPullToRefreshEdgeView *edgeView = [self edgeViewForEdge:edge];
            
            [self.contentView addSubview:edgeView];
        }
        else
        {
            [[self edgeViewForEdge:edge] removeFromSuperview];
        }
    }];
}

- (void)enumerateThroughEdges:(void (^)(ITPullToRefreshEdge))block {
    for (ITPullToRefreshEdge edge = ITPullToRefreshEdgeTop; edge <= ITPullToRefreshEdgeBottom; edge++) {
        block(edge);
    }
}

@end
