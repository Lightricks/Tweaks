/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTweakCollection.h"
#import "FBTweakCategory.h"
#import "FBTweak.h"
#import "_FBKeyboardManager.h"
#import "_FBTweakArrayViewController.h"
#import "_FBTweakCollectionViewController.h"
#import "_FBTweakColorViewController.h"
#import "_FBTweakDictionaryViewController.h"
#import "_FBTweakTableViewCell.h"

@implementation _FBTweakCollectionViewController {
   NSArray<FBTweakCollection *> *_sortedCollections;
  _FBKeyboardManager *_keyboardManager;
}

- (instancetype)initWithTweakCategory:(id<FBTweakCategory>)category
{
  if ((self = [super init])) {
    _tweakCategory = category;
    self.clearsSelectionOnViewWillAppear = YES;
    self.title = _tweakCategory.name;

    [(id)self.tweakCategory addObserver:self
                             forKeyPath:NSStringFromSelector(@selector(tweakCollections))
                                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                context:nil];

    if ([self _supportsUpdates]) {
      self.refreshControl = [[UIRefreshControl alloc] init];
      [self.refreshControl addTarget:self action:@selector(_updateCategory)
                    forControlEvents:UIControlEventValueChanged];
    }
  }
  
  return self;
}

- (void)dealloc
{
  [(id)self.tweakCategory removeObserver:self
                              forKeyPath:NSStringFromSelector(@selector(tweakCollections))];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(NSArray<FBTweakCollection *> *)tweakCollections change:(NSDictionary *)change context:(void *)context
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self _reloadData];
  });
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(_done)];

  _keyboardManager = [[_FBKeyboardManager alloc] initWithViewScrollView:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  [self _reloadData];

  [_keyboardManager enable];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [_keyboardManager disable];
}

- (BOOL)_supportsUpdates {
  return [self.tweakCategory respondsToSelector:@selector(updateWithCompletion:)];
}

- (void)_updateCategory {
  self.refreshControl.attributedTitle =
      [[NSAttributedString alloc] initWithString:@"Refreshing..."];
  [self.refreshControl beginRefreshing];
  [self.tweakCategory updateWithCompletion:^(NSError * _Nullable error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl endRefreshing];
        if (error) {
          [self presentViewController:[self errorAlertControllerWithError:error] animated:YES
                           completion:nil];
        }
      });
    }];
}

- (UIAlertController *)errorAlertControllerWithError:(NSError * _Nonnull)error {
  NSString *alertMessage = [NSString stringWithFormat:@"An error occured while updating: %@.",
                            error.description];
  UIAlertController *alertController = [UIAlertController
                                        alertControllerWithTitle:@"Error updating catergory"
                                        message:alertMessage
                                        preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *okAction = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction __unused *action){}];

  [alertController addAction:okAction];
  return alertController;
}

- (void)_reloadData
{
  _sortedCollections = [_tweakCategory.tweakCollections sortedArrayUsingComparator:^(FBTweakCollection *a, FBTweakCollection *b) {
    return [a.name localizedStandardCompare:b.name];
  }];
  [self.tableView reloadData];
}

- (void)_done
{
  [_delegate tweakCollectionViewControllerSelectedDone:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return _sortedCollections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  FBTweakCollection *collection = _sortedCollections[section];
  return collection.tweaks.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  FBTweakCollection *collection = _sortedCollections[section];
  return collection.name;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *_FBTweakCollectionViewControllerCellIdentifier = @"_FBTweakCollectionViewControllerCellIdentifier";
  _FBTweakTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:_FBTweakCollectionViewControllerCellIdentifier];
  if (cell == nil) {
    cell = [[_FBTweakTableViewCell alloc] initWithReuseIdentifier:_FBTweakCollectionViewControllerCellIdentifier];
  }
  
  FBTweakCollection *collection = _sortedCollections[indexPath.section];
  FBTweak *tweak = collection.tweaks[indexPath.row];
  cell.tweak = tweak;
  
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  FBTweakCollection *collection = _sortedCollections[indexPath.section];
  FBTweak *tweak = collection.tweaks[indexPath.row];
  if ([tweak.possibleValues isKindOfClass:[NSDictionary class]]) {
    _FBTweakDictionaryViewController *vc = [[_FBTweakDictionaryViewController alloc] initWithTweak:tweak];
    [self.navigationController pushViewController:vc animated:YES];
  } else if ([tweak.possibleValues isKindOfClass:[NSArray class]]) {
    _FBTweakArrayViewController *vc = [[_FBTweakArrayViewController alloc] initWithTweak:tweak];
    [self.navigationController pushViewController:vc animated:YES];
  } else if ([tweak.defaultValue isKindOfClass:[UIColor class]]) {
    _FBTweakColorViewController *vc = [[_FBTweakColorViewController alloc] initWithTweak:tweak];
    [self.navigationController pushViewController:vc animated:YES];
  } else if (tweak.isAction) {
    dispatch_block_t block = tweak.defaultValue;
    if (block != NULL) {
        block();
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
  }
}

@end
