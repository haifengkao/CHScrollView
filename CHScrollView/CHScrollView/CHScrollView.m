/*
 * Copyright (c) 2011, The Iconfactory. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of The Iconfactory nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE ICONFACTORY BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "CHScroller.h"
#import "CHScrollViewAnimationScroll.h"
#import "CHScrollViewAnimationDeceleration.h"
#import "CHScrollViewAnimationMomentumScrolling.h"
#import <QuartzCore/QuartzCore.h>

static const NSTimeInterval CHScrollViewAnimationDuration = 0.33;
static const NSTimeInterval CHScrollViewQuickAnimationDuration = 0.22;
static const NSUInteger CHScrollViewScrollAnimationFramesPerSecond = 60;

@interface CHScrollView () <CHScrollerDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, assign) CGFloat lastScale;
@property (nonatomic, assign) CGPoint lastZoomPoint;
@property (nonatomic, strong) NSValue* scaledContentOffset;
@property (nonatomic, assign, readwrite) BOOL zoomBouncing;
@property (nonatomic, assign, readwrite) BOOL zooming;
@end

@implementation CHScrollView
- (id)initWithFrame:(CGRect)frame
{
    if ((self=[super initWithFrame:frame])) {
        _contentOffset = CGPointZero;
        _contentSize = CGSizeZero;
        _contentInset = UIEdgeInsetsZero;
        _scrollIndicatorInsets = UIEdgeInsetsZero;
        _showsVerticalScrollIndicator = YES;
        _showsHorizontalScrollIndicator = YES;
        _maximumZoomScale = 1;
        _minimumZoomScale = 1;
        _lastScale = 1.0f;
        _scrollsToTop = YES;
        _indicatorStyle = UIScrollViewIndicatorStyleDefault;
        _delaysContentTouches = YES;
        _canCancelContentTouches = YES;
        _pagingEnabled = NO;
        _bouncesZoom = YES;
        _zooming = NO;
        _alwaysBounceVertical = NO;
        _alwaysBounceHorizontal = NO;
        _bounces = YES;
        _decelerationRate = UIScrollViewDecelerationRateNormal;
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureDidChange:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];

        // Transformation gestures :
        _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGestureUpdated:)];
        _pinchGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_pinchGestureRecognizer];

        _verticalScroller = [[CHScroller alloc] init];
        _verticalScroller.delegate = self;
        [self addSubview:_verticalScroller];

        _horizontalScroller = [[CHScroller alloc] init];
        _horizontalScroller.delegate = self;
        [self addSubview:_horizontalScroller];
        
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)dealloc
{
    
}

- (void)setDelegate:(id<CHScrollViewDelegate>)newDelegate
{
    _delegate = newDelegate;
    _delegateCan.scrollViewDidScroll = [_delegate respondsToSelector:@selector(scrollViewDidScroll:)];
    _delegateCan.scrollViewWillBeginDragging = [_delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)];
    _delegateCan.scrollViewWillEndDragging = [_delegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)];
    _delegateCan.scrollViewDidEndDragging = [_delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)];
    _delegateCan.viewForZoomingInScrollView = [_delegate respondsToSelector:@selector(viewForZoomingInScrollView:)];
    _delegateCan.scrollViewWillBeginZooming = [_delegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)];
    _delegateCan.scrollViewDidEndZooming = [_delegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)];
    _delegateCan.scrollViewDidZoom = [_delegate respondsToSelector:@selector(scrollViewDidZoom:)];
    _delegateCan.scrollViewDidEndScrollingAnimation = [_delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)];
    _delegateCan.scrollViewWillBeginDecelerating = [_delegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)];
    _delegateCan.scrollViewDidEndDecelerating = [_delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)];
}

- (UIView *)_zoomingView
{
    return (_delegateCan.viewForZoomingInScrollView)? [_delegate viewForZoomingInScrollView:self] : nil;
}

- (void)setIndicatorStyle:(UIScrollViewIndicatorStyle)style
{
    _indicatorStyle = style;
    _horizontalScroller.indicatorStyle = style;
    _verticalScroller.indicatorStyle = style;
}

- (void)setShowsHorizontalScrollIndicator:(BOOL)show
{
    _showsHorizontalScrollIndicator = show;
    [self setNeedsLayout];
}

- (void)setShowsVerticalScrollIndicator:(BOOL)show
{
    _showsVerticalScrollIndicator = show;
    [self setNeedsLayout];
}

- (BOOL)_canScrollHorizontal
{
    return self.scrollEnabled && (_contentSize.width > self.bounds.size.width);
}

- (BOOL)_canScrollVertical
{
    return self.scrollEnabled && (_contentSize.height > self.bounds.size.height);
}

- (void)_updateScrollers
{
    _verticalScroller.contentSize = _contentSize.height;
    _verticalScroller.contentOffset = _contentOffset.y;
    _horizontalScroller.contentSize = _contentSize.width;
    _horizontalScroller.contentOffset = _contentOffset.x;
    
    _verticalScroller.hidden = !self._canScrollVertical;
    _horizontalScroller.hidden = !self._canScrollHorizontal;
}

- (void)setScrollEnabled:(BOOL)enabled
{
    self.panGestureRecognizer.enabled = enabled;
    //self.scrollWheelGestureRecognizer.enabled = enabled;
    [self _updateScrollers];
    [self setNeedsLayout];
}

- (BOOL)isScrollEnabled
{
    return self.panGestureRecognizer.enabled; //|| self.scrollWheelGestureRecognizer.enabled;
}

- (void)_cancelScrollAnimation
{
    [_scrollTimer invalidate];
    _scrollTimer = nil;
    
    _scrollAnimation = nil;
    
    if (_delegateCan.scrollViewDidEndScrollingAnimation) {
        [_delegate scrollViewDidEndScrollingAnimation:self];
    }

    if (_decelerating) {
        _horizontalScroller.alwaysVisible = NO;
        _verticalScroller.alwaysVisible = NO;
        _decelerating = NO;
        
        if (_delegateCan.scrollViewDidEndDecelerating) {
            [_delegate scrollViewDidEndDecelerating:self];
        }
    }
}

- (void)_updateScrollAnimation
{
    if ([_scrollAnimation animate]) {
        [self _cancelScrollAnimation];
    }
}

- (void)_setScrollAnimation:(CHScrollViewAnimation *)animation
{
    [self _cancelScrollAnimation];
    _scrollAnimation = animation;

    if (!_scrollTimer) {
        _scrollTimer = [NSTimer scheduledTimerWithTimeInterval:1/(NSTimeInterval)CHScrollViewScrollAnimationFramesPerSecond target:self selector:@selector(_updateScrollAnimation) userInfo:nil repeats:YES];
    }
}

/**
	@param contentOffset the current content offset
	@returns the content offset which does not exceed contentSize
 */
- (CGPoint)_confinedContentOffset:(CGPoint)contentOffset
{
    const CGRect scrollerBounds = UIEdgeInsetsInsetRect(self.bounds, _contentInset);
    
    if ((_contentSize.width-contentOffset.x) < scrollerBounds.size.width) {
        contentOffset.x = (_contentSize.width - scrollerBounds.size.width);
    }
    
    if ((_contentSize.height-contentOffset.y) < scrollerBounds.size.height) {
        contentOffset.y = (_contentSize.height - scrollerBounds.size.height);
    }
    
    contentOffset.x = MAX(contentOffset.x,0);
    contentOffset.y = MAX(contentOffset.y,0);
    
    if (_contentSize.width <= scrollerBounds.size.width) {
        contentOffset.x = 0;
    }
    
    if (_contentSize.height <= scrollerBounds.size.height) {
        contentOffset.y = 0;
    }
    
    return contentOffset;
}

- (void)_setRestrainedContentOffset:(CGPoint)offset
{
    const CGPoint confinedOffset = [self _confinedContentOffset:offset];
    const CGRect scrollerBounds = UIEdgeInsetsInsetRect(self.bounds, _contentInset);
    
    if (!self.zooming // if user is zooming, let him drag the view around
        && !self.alwaysBounceHorizontal
        && (_contentSize.width <= scrollerBounds.size.width)
        )
    {
        offset.x = confinedOffset.x;
    }
    
    if (!self.zooming // if user if zooming, let him drag the view around
        && !self.alwaysBounceVertical
        && (_contentSize.height <= scrollerBounds.size.height)
        )
    {
        offset.y = confinedOffset.y;
    }
    
    self.contentOffset = offset;
}

- (void)_confineContent
{
    self.contentOffset = [self _confinedContentOffset:_contentOffset];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    const CGRect bounds = self.bounds;
    const CGFloat scrollerSize = UIScrollerWidthForBoundsSize(bounds.size);
    
    _verticalScroller.frame = CGRectMake(bounds.origin.x+bounds.size.width-scrollerSize-_scrollIndicatorInsets.right,bounds.origin.y+_scrollIndicatorInsets.top,scrollerSize,bounds.size.height-_scrollIndicatorInsets.top-_scrollIndicatorInsets.bottom);
    _horizontalScroller.frame = CGRectMake(bounds.origin.x+_scrollIndicatorInsets.left,bounds.origin.y+bounds.size.height-scrollerSize-_scrollIndicatorInsets.bottom,bounds.size.width-_scrollIndicatorInsets.left-_scrollIndicatorInsets.right,scrollerSize);
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
}

- (void)_bringScrollersToFront
{
    [super bringSubviewToFront:_horizontalScroller];
    [super bringSubviewToFront:_verticalScroller];
}

- (void)addSubview:(UIView *)subview
{
    [super addSubview:subview];
    [self _bringScrollersToFront];
}

- (void)bringSubviewToFront:(UIView *)subview
{
    [super bringSubviewToFront:subview];
    [self _bringScrollersToFront];
}

- (void)insertSubview:(UIView *)subview atIndex:(NSInteger)index
{
    [super insertSubview:subview atIndex:index];
    [self _bringScrollersToFront];
}

- (void)setContentOffset:(CGPoint)theOffset animated:(BOOL)animated
{
    if (animated) {
        CHScrollViewAnimationScroll *animation = [[CHScrollViewAnimationScroll alloc] initWithScrollView:self
                                                                                       fromContentOffset:self.contentOffset
                                                                                         toContentOffset:theOffset
                                                                                                duration:CHScrollViewAnimationDuration
                                                                                                   curve:CHScrollViewAnimationScrollCurveLinear];
        [self _setScrollAnimation:animation];
    } else {
        _contentOffset.x = roundf(theOffset.x);
        _contentOffset.y = roundf(theOffset.y);

        CGRect bounds = self.bounds;
        bounds.origin.x = _contentOffset.x+_contentInset.left;
        bounds.origin.y = _contentOffset.y+_contentInset.top;
        self.bounds = bounds;
        
        [self _updateScrollers];
        [self setNeedsLayout];

        if (_delegateCan.scrollViewDidScroll) {
            [_delegate scrollViewDidScroll:self];
        }
    }
}

- (void)setContentOffset:(CGPoint)theOffset
{
    [self setContentOffset:theOffset animated:NO];
}

- (void)setContentSize:(CGSize)newSize
{
    if (!CGSizeEqualToSize(newSize, _contentSize)) {
        _contentSize = newSize;
        //[self _confineContent];
    }
}

- (void)flashScrollIndicators
{
    [_horizontalScroller flash];
    [_verticalScroller flash];
}

- (void)_quickFlashScrollIndicators
{
    [_horizontalScroller quickFlash];
    [_verticalScroller quickFlash];
}

- (BOOL)isTracking
{
    return NO;
}

- (void)mouseMoved:(CGPoint)delta withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    const CGPoint point = [touch locationInView:self];
    const CGFloat scrollerSize = UIScrollerWidthForBoundsSize(self.bounds.size);
    const BOOL shouldShowHorizontal = CGRectContainsPoint(CGRectInset(_horizontalScroller.frame, -scrollerSize, -scrollerSize), point);
    const BOOL shouldShowVertical = CGRectContainsPoint(CGRectInset(_verticalScroller.frame, -scrollerSize, -scrollerSize), point);
    const BOOL shouldShowScrollers = (shouldShowVertical || shouldShowHorizontal || _decelerating);
    
    _horizontalScroller.alwaysVisible = shouldShowScrollers;
    _verticalScroller.alwaysVisible = shouldShowScrollers;
    
    //[super mouseMoved:delta withEvent:event];
}

- (CHScrollViewAnimation *)_pageSnapAnimation
{
    const CGSize pageSize = self.bounds.size;
    const CGSize numberOfWholePages = CGSizeMake(floorf(_contentSize.width/pageSize.width), floorf(_contentSize.height/pageSize.height));
    const CGSize currentRawPage = CGSizeMake(_contentOffset.x/pageSize.width, _contentOffset.y/pageSize.height);
    const CGSize currentPage = CGSizeMake(floorf(currentRawPage.width), floorf(currentRawPage.height));
    const CGSize currentPagePercentage = CGSizeMake(1-(currentRawPage.width-currentPage.width), 1-(currentRawPage.height-currentPage.height));
    
    CGPoint finalContentOffset = CGPointZero;
    
    // if currentPagePercentage is less than 50%, then go to the next page (if any), otherwise snap to the current page
    
    if (currentPagePercentage.width < 0.5 && (currentPage.width+1) < numberOfWholePages.width) {
        finalContentOffset.x = pageSize.width * (currentPage.width + 1);
    } else {
        finalContentOffset.x = pageSize.width * currentPage.width;
    }
    
    if (currentPagePercentage.height < 0.5 && (currentPage.height+1) < numberOfWholePages.height) {
        finalContentOffset.y = pageSize.height * (currentPage.height + 1);
    } else {
        finalContentOffset.y = pageSize.height * currentPage.height;
    }
    
    // quickly animate the snap (if necessary)
    if (!CGPointEqualToPoint(finalContentOffset, _contentOffset)) {
        return [[CHScrollViewAnimationScroll alloc] initWithScrollView:self
                                                      fromContentOffset:_contentOffset
                                                        toContentOffset:finalContentOffset
                                                               duration:CHScrollViewQuickAnimationDuration
                                                                  curve:CHScrollViewAnimationScrollCurveQuadraticEaseOut];
    } else {
        return nil;
    }
}

- (CHScrollViewAnimation *)_decelerationAnimationWithVelocity:(CGPoint)velocity
{
    const CGPoint confinedOffset = [self _confinedContentOffset:_contentOffset];
    
    // if we've pulled up the content outside it's bounds, we don't want to register any flick momentum there and instead just
    // have the animation pull the content back into place immediately.
    if (confinedOffset.x != _contentOffset.x) {
        velocity.x = 0;
    }
    if (confinedOffset.y != _contentOffset.y) {
        velocity.y = 0;
    }
    
    if (!CGPointEqualToPoint(velocity, CGPointZero) || !CGPointEqualToPoint(confinedOffset, _contentOffset)) {
        return [[CHScrollViewAnimationMomentumScrolling alloc] initWithScrollView:self
                                                                     velocity:velocity];
    } else {
        return nil;
    }
}

- (void)_beginDragging
{
    if (!_dragging) {
        _dragging = YES;

        _horizontalScroller.alwaysVisible = YES;
        _verticalScroller.alwaysVisible = YES;
        
        [self _cancelScrollAnimation];

        if (_delegateCan.scrollViewWillBeginDragging) {
            [_delegate scrollViewWillBeginDragging:self];
        }
    }
}

- (BOOL)isDragging
{
    return _dragging;
}

- (BOOL)_shouldDecelerate
{
    // check if scale exceeds valid range
    CGFloat scale = MAX(self.minimumZoomScale, MIN(self.maximumZoomScale, self.zoomScale));
    
    return !(self.zooming || (scale != self.zoomScale));
}

- (void)_endDraggingWithDecelerationVelocity:(CGPoint)velocity
{
    if (![self _shouldDecelerate]) {
        return;
    }
    if (_dragging) {
        _dragging = NO;
        
        CHScrollViewAnimation *decelerationAnimation = _pagingEnabled? [self _pageSnapAnimation] : [self _decelerationAnimationWithVelocity:velocity];
        
        if (!_pagingEnabled && _delegateCan.scrollViewWillEndDragging){
            if ([decelerationAnimation isKindOfClass:[CHScrollViewAnimationMomentumScrolling class]]) {
                // let delegate decide where to stop
                CHScrollViewAnimationMomentumScrolling* animation = (CHScrollViewAnimationMomentumScrolling*)decelerationAnimation;
                
                CGPoint targetOffset = [animation targetContentOffset];
                CGPoint originalTargetOffset = targetOffset;
                [_delegate scrollViewWillEndDragging:self withVelocity:velocity targetContentOffset:&targetOffset];
                
                if (!CGPointEqualToPoint(targetOffset, originalTargetOffset)) {
                    CGPoint newVelocity = [animation velocityForTargetContentOffset:targetOffset];
                    
                    // get a new animation
                    decelerationAnimation = [self _decelerationAnimationWithVelocity:newVelocity];
                }
            }
        }

        if (_delegateCan.scrollViewDidEndDragging) {
            [_delegate scrollViewDidEndDragging:self willDecelerate:(decelerationAnimation != nil)];
        }

        if (decelerationAnimation) {
            [self _setScrollAnimation:decelerationAnimation];

            _horizontalScroller.alwaysVisible = YES;
            _verticalScroller.alwaysVisible = YES;
            _decelerating = YES;

            if (_delegateCan.scrollViewWillBeginDecelerating) {
                [_delegate scrollViewWillBeginDecelerating:self];
            }
        } else {
            _horizontalScroller.alwaysVisible = NO;
            _verticalScroller.alwaysVisible = NO;
            self.contentOffset = [self _confinedContentOffset:_contentOffset];
        }
    }
}

- (void)_dragBy:(CGPoint)delta
{
    if (_dragging) {
        _horizontalScroller.alwaysVisible = YES;
        _verticalScroller.alwaysVisible = YES;

        const CGPoint originalOffset = self.contentOffset;
        
        CGPoint proposedOffset = originalOffset;
        proposedOffset.x -= delta.x;
        proposedOffset.y -= delta.y;
        
        const CGPoint confinedOffset = [self _confinedContentOffset:proposedOffset];
        
        if (self.bounces) {
            static const CGFloat damping = 0.5;
            
            BOOL shouldHorizontalBounce = (fabs(proposedOffset.x - confinedOffset.x) > 0);
            BOOL shouldVerticalBounce = (fabs(proposedOffset.y - confinedOffset.y) > 0);
            
            if (shouldHorizontalBounce) {
                proposedOffset.x = originalOffset.x - (damping * delta.x);
            }
            
            if (shouldVerticalBounce) {
                proposedOffset.y = originalOffset.y - (damping * delta.y);
            }
            [self _setRestrainedContentOffset:proposedOffset];
        } else {
            [self setContentOffset:confinedOffset];
        }
    }
}

- (BOOL)isDecelerating
{
    return _decelerating;
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated
{
    const CGRect contentRect = CGRectMake(0,0,_contentSize.width, _contentSize.height);
    const CGRect visibleRect = self.bounds;
    CGRect goalRect = CGRectIntersection(rect, contentRect);

    if (!CGRectIsNull(goalRect) && !CGRectContainsRect(visibleRect, goalRect)) {
        
        // clamp the goal rect to the largest possible size for it given the visible space available
        // this causes it to prefer the top-left of the rect if the rect is too big
        goalRect.size.width = MIN(goalRect.size.width, visibleRect.size.width);
        goalRect.size.height = MIN(goalRect.size.height, visibleRect.size.height);
        
        CGPoint offset = self.contentOffset;
        
        if (CGRectGetMaxY(goalRect) > CGRectGetMaxY(visibleRect)) {
            offset.y += CGRectGetMaxY(goalRect) - CGRectGetMaxY(visibleRect);
        } else if (CGRectGetMinY(goalRect) < CGRectGetMinY(visibleRect)) {
            offset.y += CGRectGetMinY(goalRect) - CGRectGetMinY(visibleRect);
        }
        
        if (CGRectGetMaxX(goalRect) > CGRectGetMaxX(visibleRect)) {
            offset.x += CGRectGetMaxX(goalRect) - CGRectGetMaxX(visibleRect);
        } else if (CGRectGetMinX(goalRect) < CGRectGetMinX(visibleRect)) {
            offset.x += CGRectGetMinX(goalRect) - CGRectGetMinX(visibleRect);
        }
        
        [self setContentOffset:offset animated:animated];
    }
}

- (float)zoomScale
{
    UIView *zoomingView = [self _zoomingView];
    
    // it seems weird to return the "a" component of the transform for this, but after some messing around with the real UIKit, I'm
    // reasonably certain that's how it is doing it.
    return zoomingView? zoomingView.transform.a : 1.f;
}

- (void)setZoomScale:(float)scale animated:(BOOL)animated
{
    UIView *zoomingView = [self _zoomingView];
    scale = MIN(MAX(scale, _minimumZoomScale), _maximumZoomScale);

    if (zoomingView && self.zoomScale != scale) {
        CGPoint zoomPoint = CGPointMake(self.contentOffset.x + self.bounds.size.width * 0.5, self.contentOffset.y + self.bounds.size.height * 0.5);
        [self zoomToPoint:zoomPoint scale:scale/self.zoomScale animated:animated confined:YES  completion:NULL];
    }
}

- (void)setZoomScale:(float)scale
{
    [self setZoomScale:scale animated:NO];
}

- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated
{
    //TODO: not finished
    if (self.zoomScale > 0.0f) {
        [self zoomToPoint:rect.origin scale:self.maximumZoomScale/self.zoomScale animated:animated confined:YES completion:NULL];
    }
}

#pragma mark - NSObject
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; frame = (%.0f %.0f; %.0f %.0f); clipsToBounds = %@; layer = %@; contentOffset = {%.0f, %.0f}>", [self class], self, self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height, (self.clipsToBounds ? @"YES" : @"NO"), self.layer, self.contentOffset.x, self.contentOffset.y];
}

#pragma mark - private methods
/**
 zoom the zoomingView to the specified scale
 @param zoomPoint the anchor point for zooming
 @param scale the relative zooming scale (the changes from current zoomScale)
 @param animated YES if you want animation
 */
- (void)zoomToPoint:(CGPoint)zoomPoint
              scale:(float)scale
           animated:(BOOL)animated
           confined:(BOOL)confined
         completion:(void (^)(BOOL finished))completion

{
    UIView *zoomingView = [self _zoomingView];
    
    if (self.zoomScale <= 0.0f){
        return;
    }

    CHScrollView* __weak selfRef = self;
    if (zoomingView && self.zoomScale != scale) {
        [UIView animateWithDuration:animated? CHScrollViewAnimationDuration : 0
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^(void) {

                             // cache contentOffset, we don't want any side effects which changes this value
                             CGPoint contentOffset = selfRef.contentOffset;
                             
                             CGAffineTransform newTransform = CGAffineTransformScale(zoomingView.transform, scale, scale);
                             [zoomingView setTransform:newTransform];
                             
                             CGSize size = zoomingView.frame.size;
                             zoomingView.layer.position = CGPointMake(size.width/2.f, size.height/2.f);
                             selfRef.contentSize = size;
                             
                             CGPoint scaledContentOffset = CGPointMake(zoomPoint.x*scale - (zoomPoint.x - contentOffset.x), zoomPoint.y*scale - (zoomPoint.y - contentOffset.y));
                             
                             if (confined) {
                                 scaledContentOffset = [selfRef _confinedContentOffset:scaledContentOffset];
                             }
                             
                             if (!CGPointEqualToPoint(scaledContentOffset, selfRef.contentOffset)) {
                                 selfRef.contentOffset = scaledContentOffset;
                             }
                         }
                         completion:completion];
    }
}


#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // we want users can be draging the images and zooming at the same time
    if (gestureRecognizer == _panGestureRecognizer && otherGestureRecognizer == _pinchGestureRecognizer) {
        return YES;
    }
    
    if (gestureRecognizer == _pinchGestureRecognizer && otherGestureRecognizer == _panGestureRecognizer) {
        return YES;
    }
    return NO;
}

#pragma mark - Actions for gesture
- (void)pinchGestureUpdated:(UIPinchGestureRecognizer*)gesture
{
    //when user's finder is lifted, reset lastscale to 1.0
    CHScrollView* __weak selfRef = self;
    if([gesture state] == UIGestureRecognizerStateEnded) {
        self.lastScale = 1.0;
        self.zooming = NO;
        // NSLog(@"reset to 1.0");
        
        BOOL didConfineOffset = NO;
        if (self.bouncesZoom && !self.zoomBouncing) {
            // perform bounces zoom animation
            CGFloat scale = MIN(MAX(self.zoomScale, self.minimumZoomScale), self.maximumZoomScale);
            if (scale != self.zoomScale && self.zoomScale > 0.0f){
                self.zoomBouncing = YES;
                CGFloat relScale = scale / self.zoomScale;
                // TODO: should fire willDecelerate?
                [self zoomToPoint:self.lastZoomPoint
                            scale:relScale
                         animated:YES
                        confined:YES
                       completion:^(BOOL finished) {
                           selfRef.zoomBouncing = NO;
                       }];
                didConfineOffset = YES;
            }
        }
        
        if (!didConfineOffset) {
            [self _endDraggingWithDecelerationVelocity:CGPointMake(0.0, 0.0)];
        }
        return;
    }
    
    if ([gesture numberOfTouches] < 2) {
        return;
    }
    self.zooming = YES; // user begins zooming
    self.zoomBouncing = NO;
    
    CGFloat scaleDiff = self.lastScale - [gesture scale];
    CGFloat scale = 1.0 - scaleDiff;
    CGFloat absScale = self.zoomScale*scale;
    
    if (absScale > self.maximumZoomScale || absScale < self.minimumZoomScale) {
        if (self.bouncesZoom) {
            CGFloat damping = MAX(absScale/self.maximumZoomScale, self.minimumZoomScale/absScale);
            NSAssert(damping >= 1.0f, @"");
            scaleDiff /= (2.0f*damping); //add some damping
            scale = 1.0f - scaleDiff;
        }else{
            if (self.zoomScale > 0) {
                absScale = MIN(self.maximumZoomScale, MAX(self.minimumZoomScale, absScale));
                scale = absScale/self.zoomScale;
            }
            
        }
    }
    
    CGPoint zoomPoint;
    CGPoint point1 = [gesture locationOfTouch:0 inView:self]; //first
    CGPoint point2 = [gesture locationOfTouch:1 inView:self]; //second
    zoomPoint.x = (point1.x + point2.x)/2.0f;
    zoomPoint.y = (point1.y + point2.y)/2.0f;
    
    self.lastScale = [gesture scale];
    self.lastZoomPoint = zoomPoint;
    
    [self zoomToPoint:zoomPoint scale:scale animated:NO confined:NO completion:nil];
}

- (void)panGestureDidChange:(UIPanGestureRecognizer *)gesture
{
    // the scrolling gestures are broken into two components due to the somewhat fundamental differences
    // in how they are handled by the system. The UIPanGestureRecognizer will only track scrolling gestures
    // that come from actual touch scroller devices. This does *not* include old fashioned mouse wheels.
    // the non-standard UIScrollWheelGestureRecognizer is a discrete recognizer which only responds to
    // non-gesture scroll events such as those from non-touch devices. HOWEVER the system sends momentum
    // scroll events *after* the touch gesture has ended which allows for us to distinguish the difference
    // here between actual touch gestures and the momentum gestures and thus feed them into the playing
    // deceleration animation as we receive them so that we can preserve the system's proper feel for that.
    
    // Also important to note is that with a legacy scroll device, each movement of the wheel is going to
    // trigger a beginDrag, dragged, endDragged sequence. I believe that's an acceptable compromise however
    // it might cause some potentially strange behavior in client code that is not expecting such rapid
    // state changes along these lines.
    
    // Another note is that only touch-based panning gestures will trigger calls to _dragBy: which means
    // that only touch devices can possibly pull the content outside of the scroll view's bounds while
    // active. An old fashioned wheel will not be able to do that and its scroll events are confined to
    // the bounds of the scroll view.
    
    // There are some semi-legacy devices like the magic mouse which 10.6 doesn't seem to consider a true
    // touch device, so it doesn't send the gestureBegin/ended stuff that's used to recognize such things
    // but it *will* send momentum events. This means that those devices on 10.6 won't give you the feeling
    // of being able to grab and pull your content away from the bounds like a proper touch trackpad will.
    // As of 10.7 it appears Apple fixed this and they do actually send the proper gesture events, so on
    // 10.7 the magic mouse should end up acting like any other touch input device as far as we're concerned.
    
    // Momentum scrolling doesn't work terribly well with how the paging stuff is now handled. Something
    // could be improved there. I'm not sure if the paging animation should just pretend it's longer to
    // kind of "mask" the OS' momentum events, or if a flag should be set, or if it should work so that
    // even in paging mode the deceleration and stuff happens like usual and it only snaps to the correct
    // page *after* the usual deceleration is done. I can't decide what might be best, but since we
    // don't use paging mode in Twitterrific at the moment, I'm not suffeciently motivated to worry about it. :)
    
    if (gesture == _panGestureRecognizer) {
        if (_panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
            [self _beginDragging];
        } else if (_panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
            [self _dragBy:[_panGestureRecognizer translationInView:self]];
            [_panGestureRecognizer setTranslation:CGPointZero inView:self];
        } else if (_panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
            CGPoint velocity = [_panGestureRecognizer velocityInView:self];
            
            // the scroll view's moving direction is the opposite of finger's movement
            velocity.x = -velocity.x;
            velocity.y = -velocity.y;
            [self _endDraggingWithDecelerationVelocity:velocity];
        }
    }
}

#pragma mark - CHScrollerDelegate
- (void)_UIScrollerDidBeginDragging:(CHScroller *)scroller withEvent:(UIEvent *)event
{
    [self _beginDragging];
}

- (void)_UIScroller:(CHScroller *)scroller contentOffsetDidChange:(CGFloat)newOffset
{
    if (scroller == _verticalScroller) {
        [self setContentOffset:CGPointMake(self.contentOffset.x,newOffset) animated:NO];
    } else if (scroller == _horizontalScroller) {
        [self setContentOffset:CGPointMake(newOffset,self.contentOffset.y) animated:NO];
    }
}

- (void)_UIScrollerDidEndDragging:(CHScroller *)scroller withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    const CGPoint point = [touch locationInView:self];
    
    if (!CGRectContainsPoint(scroller.frame,point)) {
        scroller.alwaysVisible = NO;
    }
    
    [self _endDraggingWithDecelerationVelocity:CGPointZero];
}
@end
