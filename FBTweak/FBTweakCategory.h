/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class FBTweakCollection;

/**
 @abstract Represents an named array of \c FBTweakCollection objects.
 */
@protocol FBTweakCategory <NSObject>

/**
 @abstract The name of the category.
 */
@property (nonatomic, copy, readonly) NSString *name;

/**
 @abstract The collections contained in this category.
 */
@property (nonatomic, copy, readonly) NSArray<FBTweakCollection *> *tweakCollections;

/**
 @abstract Resets all tweaks in \c tweakCollection to their default value.
 */
- (void)reset;

@optional

/**
 @abstract Asynchronously updates \c tweakCollections to the latest value, and calls \c completion
 when done. Upon error \c error is set, otherwise \c error is \c nil.
 @param completion Completion block to be called when the update is complete. \c completion can be
 called after this method returns.
 @discussion When the update operation is complete, is it expected that the \c tweakCollection will
 be update with the latest object.
 */
- (void)updateWithCompletion:(void (^)(NSError *error))completion;

@end

/**
 @abstract A named grouping of collections.
 */
@interface FBNativeTweakCategory : NSObject <FBTweakCategory, NSCoding>

- (instancetype)init NS_UNAVAILABLE;

/**
 @abstract Creates a tweak category.
 */
- (instancetype)initWithName:(NSString *)name NS_DESIGNATED_INITIALIZER;

/**
 @abstract Finds a collection by name. Returns \c nil when catergory with \c name cannot be found.
 @param name The collection name to find.
 */
- (FBTweakCollection *)tweakCollectionWithName:(NSString *)name;

/**
 @abstract Adds a tweak collection to the category.
 @param tweakCollection The tweak collection to add.
 */
- (void)addTweakCollection:(FBTweakCollection *)tweakCollection;

/**
 @abstract Removes a tweak collection from the category.
 @param tweakCollection The tweak collection to remove.
 */
- (void)removeTweakCollection:(FBTweakCollection *)tweakCollection;

@end

