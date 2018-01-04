/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTweak.h"
#import "FBTweakCategory.h"
#import "FBTweakCollection.h"

@interface FBNativeTweakCategory ()

/**
 @abstract The collections contained in this category.
 */
@property (nonatomic, copy, readwrite) NSMutableArray<FBTweakCollection *> *tweakCollections;

@end

@implementation FBNativeTweakCategory

@synthesize name = _name;
@synthesize tweakCollections = _tweakCollections;

- (instancetype)initWithCoder:(NSCoder *)coder
{
  NSString *name = [coder decodeObjectForKey:@"name"];
  
  if ((self = [self initWithName:name])) {
    _tweakCollections = [coder decodeObjectForKey:@"collections"];
  }
  
  return self;
}

- (instancetype)initWithName:(NSString *)name
{
  if ((self = [super init])) {
    _name = [name copy];
    _tweakCollections = [NSMutableArray array];
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:self.name forKey:@"name"];
  [coder encodeObject:self.tweakCollections forKey:@"collections"];
}

- (FBTweakCollection *)tweakCollectionWithName:(NSString *)name
{
  NSUInteger index = [_tweakCollections indexOfObjectPassingTest:
                      ^BOOL(FBTweakCollection * _Nonnull collection, NSUInteger __unused idx, BOOL * _Nonnull stop) {
    return [collection.name isEqualToString:name];
  }];
  return index != NSNotFound ? [self.tweakCollections objectAtIndex:index] : nil;
}

- (void)addTweakCollection:(FBTweakCollection *)tweakCollection
{
  [self.tweakCollections addObject:tweakCollection];
  self.tweakCollections = self.tweakCollections;
}

- (void)removeTweakCollection:(FBTweakCollection *)tweakCollection
{
  NSMutableArray<FBTweakCollection *> *collections = self.tweakCollections;
  [collections removeObject:tweakCollection];
  self.tweakCollections = collections;
}

- (void)reset {
  for (FBTweakCollection *collection in self.tweakCollections) {
    for (FBTweak *tweak in collection.tweaks) {
      if (!tweak.isAction) {
        tweak.currentValue = nil;
      }
    }
  }
}

@end
