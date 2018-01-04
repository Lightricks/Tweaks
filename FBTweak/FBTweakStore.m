/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTweakStore.h"
#import "FBTweak.h"
#import "FBTweakCategory.h"
#import "FBTweakCollection.h"

@implementation FBTweakStore {
  NSMutableArray *_orderedCategories;
  NSMutableDictionary *_namedCategories;
}

+ (instancetype)sharedInstance
{
  static FBTweakStore *sharedInstance = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  
  return sharedInstance;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
  if ((self = [self init])) {
    _orderedCategories = [[coder decodeObjectForKey:@"categories"] mutableCopy];
    
    for (id<FBTweakCategory> tweakCategory in _orderedCategories) {
      [_namedCategories setObject:tweakCategory forKey:tweakCategory.name];
    }
  }
  
  return self;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _orderedCategories = [[NSMutableArray alloc] initWithCapacity:16];
    _namedCategories = [[NSMutableDictionary alloc] initWithCapacity:16];
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_orderedCategories forKey:@"categories"];
}

- (NSArray *)tweakCategories
{
  return [_orderedCategories copy];
}

- (id<FBTweakCategory>)tweakCategoryWithName:(NSString *)name {
  return _namedCategories[name];
}

- (FBNativeTweakCategory *)nativeTweakCategoryWithName:(NSString *)name {
  FBNativeTweakCategory *nativeCategory = _namedCategories[name];
  if (![nativeCategory isKindOfClass:[FBNativeTweakCategory class]]) {
    return nil;
  }
  return nativeCategory;
}

- (void)addTweakCategory:(id<FBTweakCategory>)category
{
  [_namedCategories setObject:category forKey:category.name];
  [_orderedCategories addObject:category];
}

- (void)removeTweakCategory:(id<FBTweakCategory>)category
{
  [_namedCategories removeObjectForKey:category.name];
  [_orderedCategories removeObject:category];
}

- (void)reset
{
  for (id<FBTweakCategory> category in self.tweakCategories) {
    [category reset];
  }
}

@end
