//
//  MWGridViewController.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//

#import <math.h>
#import "MWGridViewController.h"
#import "MWGridCell.h"
#import "MWPhotoBrowserPrivate.h"
#import "MWCommon.h"

@interface MWGridViewController () {

    // Store margins for current setup
    CGFloat _margin, _gutter, _marginL, _gutterL, _columns, _columnsL;

}

@end

@implementation MWGridViewController

- (id)init {
    if ((self = [super initWithCollectionViewLayout:[UICollectionViewFlowLayout new]])) {

        // Defaults
        _columns = 3, _columnsL = 4;
        _margin = 0, _gutter = 1;
        _marginL = 0, _gutterL = 1;

        // For pixel perfection...
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            // iPad
            _columns = 6, _columnsL = 8;
            _margin = 1, _gutter = 2;
            _marginL = 1, _gutterL = 2;
        } else if ([UIScreen mainScreen].bounds.size.height == 480) {
            // iPhone 3.5 inch
            _columns = 3, _columnsL = 4;
            _margin = 0, _gutter = 1;
            _marginL = 1, _gutterL = 2;
        } else {
            // iPhone 4 inch
            _columns = 3, _columnsL = 5;
            _margin = 0, _gutter = 1;
            _marginL = 0, _gutterL = 2;
        }

        _initialContentOffset = CGPointMake(0, CGFLOAT_MAX);
        _indexPathOfLastPanGestureChange = nil;

    }
    return self;
}

#pragma mark - View

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.collectionView registerClass:[MWGridCell class] forCellWithReuseIdentifier:@"GridCell"];
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.backgroundColor = [UIColor darkGrayColor];

    UIPanGestureRecognizer * panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPanToSelectCells:)];
    panGesture.cancelsTouchesInView = NO;
    panGesture.delegate = self;
    [self.collectionView addGestureRecognizer:panGesture];

    UILongPressGestureRecognizer * longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressOnCell:)];
    longPressGesture.cancelsTouchesInView = YES;
    longPressGesture.allowableMovement = 100.0f;
    panGesture.delegate = self;
    [self.collectionView addGestureRecognizer:longPressGesture];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    // Cancel outstanding loading
    NSArray *visibleCells = [self.collectionView visibleCells];
    if (visibleCells) {
        for (MWGridCell *cell in visibleCells) {
            [cell.photo cancelAnyLoading];
        }
    }
    [super viewWillDisappear:animated];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self performLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)adjustOffsetsAsRequired {

    // Move to previous content offset
    if (_initialContentOffset.y != CGFLOAT_MAX) {
        self.collectionView.contentOffset = _initialContentOffset;
        [self.collectionView layoutIfNeeded]; // Layout after content offset change
    }

    // Check if current item is visible and if not, make it so!
    if (_browser.numberOfPhotos > 0) {
        NSIndexPath *currentPhotoIndexPath = [NSIndexPath indexPathForItem:_browser.currentIndex inSection:0];
        NSArray *visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
        BOOL currentVisible = NO;
        for (NSIndexPath *indexPath in visibleIndexPaths) {
            if ([indexPath isEqual:currentPhotoIndexPath]) {
                currentVisible = YES;
                break;
            }
        }
        if (!currentVisible) {
            [self.collectionView scrollToItemAtIndexPath:currentPhotoIndexPath atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
        }
    }

}

- (void)performLayout {
    UINavigationBar *navBar = self.navigationController.navigationBar;
    self.collectionView.contentInset = UIEdgeInsetsMake(navBar.frame.origin.y + navBar.frame.size.height + [self getGutter], 0, 0, 0);
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self.collectionView reloadData];
    [self performLayout]; // needed for iOS 5 & 6
}

#pragma mark - Layout

- (CGFloat)getColumns {
    if ((UIInterfaceOrientationIsPortrait(self.interfaceOrientation))) {
        return _columns;
    } else {
        return _columnsL;
    }
}

- (CGFloat)getMargin {
    if ((UIInterfaceOrientationIsPortrait(self.interfaceOrientation))) {
        return _margin;
    } else {
        return _marginL;
    }
}

- (CGFloat)getGutter {
    if ((UIInterfaceOrientationIsPortrait(self.interfaceOrientation))) {
        return _gutter;
    } else {
        return _gutterL;
    }
}

#pragma mark - Collection View

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return [_browser numberOfPhotos];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MWGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"GridCell" forIndexPath:indexPath];
    if (!cell) {
        cell = [[MWGridCell alloc] init];
    }
    id <MWPhoto> photo = [_browser thumbPhotoAtIndex:indexPath.row];
    cell.photo = photo;
    cell.gridController = self;
    cell.selectionMode = _selectionMode;
    cell.isSelected = [_browser photoIsSelectedAtIndex:indexPath.row];
    cell.index = indexPath.row;
    UIImage *img = [_browser imageForPhoto:photo];
    if (img) {
        [cell displayImage];

        if ([_browser.delegate respondsToSelector:@selector(photoBrowser:customizeGridCell:)]) {
            [_browser.delegate photoBrowser:_browser customizeGridCell:cell];
        }
    } else {
        [photo loadUnderlyingImageAndNotify];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [_browser setCurrentPhotoIndex:indexPath.row];
    [_browser hideGrid];
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [((MWGridCell *)cell).photo cancelAnyLoading];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat margin = [self getMargin];
    CGFloat gutter = [self getGutter];
    CGFloat columns = [self getColumns];
    CGFloat value = floorf(((self.view.bounds.size.width - (columns - 1) * gutter - 2 * margin) / columns));
    return CGSizeMake(value, value);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return [self getGutter];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return [self getGutter];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    CGFloat margin = [self getMargin];
    return UIEdgeInsetsMake(margin, margin, margin, margin);
}

- (void)didPanToSelectCells:(UIPanGestureRecognizer *)panGesture {
    if (!_browser.displaySelectionButtons) {
        [self.collectionView setScrollEnabled:YES];
        return;
    }

    CGPoint velocity = [panGesture velocityInView:self.collectionView];

    if (_indexPathOfLastPanGestureChange == nil && fabsf(velocity.y) > fabsf(velocity.x)) {
        // if we have an up/down pan gesture it is probably a scroll gesture
        [self.collectionView setScrollEnabled:YES];
        return;
    }

    // Allow selecting multiple images using a single pan gesture over them
    // based on http://stackoverflow.com/a/36580992

    if (panGesture.state == UIGestureRecognizerStateBegan) {
        [self.collectionView setUserInteractionEnabled:NO];
        [self.collectionView setScrollEnabled:NO];

    } else if (panGesture.state == UIGestureRecognizerStateChanged) {
        CGPoint location = [panGesture locationInView:self.collectionView];

        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
        if (_indexPathOfLastPanGestureChange != nil && indexPath.row == _indexPathOfLastPanGestureChange.row) {
            return;
        }
        _indexPathOfLastPanGestureChange = indexPath;

        BOOL selectedState = [_browser photoIsSelectedAtIndex:(NSUInteger) indexPath.row];

        [_browser setPhotoSelected:!selectedState atIndex:(NSUInteger) indexPath.row];

        MWGridCell *cell = (MWGridCell *) [self.collectionView cellForItemAtIndexPath:indexPath];
        [cell setIsSelected:!selectedState];

    } else if (panGesture.state == UIGestureRecognizerStateEnded) {
        _indexPathOfLastPanGestureChange = nil;
        [self.collectionView setScrollEnabled:YES];
        [self.collectionView setUserInteractionEnabled:YES];
    }
}

- (void)didLongPressOnCell:(UILongPressGestureRecognizer *)longPressGesture {
    if (longPressGesture.state != UIGestureRecognizerStateBegan) {
        return;
    }

    CGPoint location = [longPressGesture locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
    MWGridCell *cell = (MWGridCell *) [self.collectionView cellForItemAtIndexPath:indexPath];
    if (cell == nil) {
        return;
    }

    if ([self.browser.delegate respondsToSelector:@selector(photoBrowser:longPressOnPhotoAtIndex:atCell:inCollectionView:inNavigationController:)]) {
        [self.browser.delegate photoBrowser:self.browser longPressOnPhotoAtIndex:(NSUInteger) indexPath.row atCell:cell inCollectionView:self.collectionView inNavigationController:self.navigationController];
    }
}

@end
