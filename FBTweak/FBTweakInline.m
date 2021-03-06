/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTweakInline.h"
#import "FBTweak.h"
#import "FBTweakInlineInternal.h"
#import "FBTweakCollection.h"
#import "FBTweakStore.h"
#import "FBTweakCategory.h"

#import <UIKit/UIKit.h>
#import <libkern/OSAtomic.h>
#import <stdatomic.h>
#import <mach-o/getsect.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

#if FB_TWEAK_ENABLED

extern NSString *_FBTweakIdentifier(fb_tweak_entry *entry)
{
  return [NSString stringWithFormat:@"FBTweak:%@-%@-%@", *entry->category, *entry->collection, *entry->name];
}

static id<FBTweak> _FBTweakCreateWithEntry(NSString *identifier, fb_tweak_entry *entry)
{
  NSString *name = *entry->name;

  if (strcmp(*entry->encoding, FBTweakEncodingAction) == 0) {
    dispatch_block_t block = *(__strong dispatch_block_t *)entry->value;
    NSCAssert(block, @"Action tweak with identifier %@ contains block that references a local "
              "variable", identifier);
    return [[FBActionTweak alloc] initWithIdentifier:identifier name:name block:block];
  }

  FBTweakValue defaultValue;
  if (strcmp(*entry->encoding, FBTweakEncodingAction) == 0) {
    defaultValue = *(__strong dispatch_block_t *)entry->value;
  } else if (strcmp(*entry->encoding, @encode(BOOL)) == 0) {
    defaultValue = @(fb_tweak_entry_block_field(BOOL, entry, value));
  } else if (strcmp(*entry->encoding, @encode(float)) == 0) {
    defaultValue = [NSNumber numberWithFloat:fb_tweak_entry_block_field(float, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(double)) == 0) {
    defaultValue = [NSNumber numberWithDouble:fb_tweak_entry_block_field(double, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(short)) == 0) {
    defaultValue = [NSNumber numberWithShort:fb_tweak_entry_block_field(short, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(unsigned short)) == 0) {
    defaultValue = [NSNumber numberWithUnsignedShort:fb_tweak_entry_block_field(unsigned short, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(int)) == 0) {
    defaultValue = [NSNumber numberWithInt:fb_tweak_entry_block_field(int, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(unsigned int)) == 0) {
    defaultValue = [NSNumber numberWithUnsignedInt:fb_tweak_entry_block_field(unsigned int, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(long)) == 0) {
    defaultValue = [NSNumber numberWithLong:fb_tweak_entry_block_field(long, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(unsigned long)) == 0) {
    defaultValue = [NSNumber numberWithUnsignedLong:fb_tweak_entry_block_field(unsigned long, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(long long)) == 0) {
    defaultValue = [NSNumber numberWithLongLong:fb_tweak_entry_block_field(long long, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(unsigned long long)) == 0) {
    defaultValue = [NSNumber numberWithUnsignedLongLong:fb_tweak_entry_block_field(unsigned long long, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(NSInteger)) == 0) {
    defaultValue = [NSNumber numberWithInteger:fb_tweak_entry_block_field(NSInteger, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(NSUInteger)) == 0) {
    defaultValue = [NSNumber numberWithUnsignedInteger:fb_tweak_entry_block_field(NSUInteger, entry, value)];
  } else if (*entry->encoding[0] == '[') {
    // Assume it's a C string.
    defaultValue = [NSString stringWithUTF8String:fb_tweak_entry_block_field(char *, entry, value)];
  } else if (strcmp(*entry->encoding, @encode(id)) == 0) {
    defaultValue = fb_tweak_entry_block_field(id, entry, value);
  } else {
    NSCAssert(NO, @"Unknown encoding %s for tweak %@. Value was %p.", *entry->encoding, _FBTweakIdentifier(entry), entry->value);
  }

  FBPersistentTweak *tweak = [[FBPersistentTweak alloc] initWithIdentifier:identifier
                                                                      name:*entry->name
                                                              defaultValue:defaultValue];
  if (entry->possible) {
    tweak.possibleValues = fb_tweak_entry_block_field(id, entry, possible);
  }

  return tweak;
}

@interface _FBTweakInlineLoader : NSObject
@end

@implementation _FBTweakInlineLoader

+ (void)load
{
  static atomic_bool _tweaksLoaded = false;
  if (atomic_fetch_or(&_tweaksLoaded, true)) {
    return;
  }
  
#ifdef __LP64__
  typedef uint64_t fb_tweak_value;
  typedef struct section_64 fb_tweak_section;
  typedef struct mach_header_64 fb_tweak_header;
#define fb_tweak_getsectbynamefromheader getsectbynamefromheader_64
#else
  typedef uint32_t fb_tweak_value;
  typedef struct section fb_tweak_section;
  typedef struct mach_header fb_tweak_header;
#define fb_tweak_getsectbynamefromheader getsectbynamefromheader
#endif
  
  FBTweakStore *store = [FBTweakStore sharedInstance];
  
  uint32_t image_count = _dyld_image_count();
  for (uint32_t image_index = 0; image_index < image_count; image_index++) {
    const fb_tweak_header *mach_header = (const fb_tweak_header *)_dyld_get_image_header(image_index);

    unsigned long size;
    fb_tweak_entry *data = (fb_tweak_entry *)getsectiondata(mach_header, FBTweakSegmentName, FBTweakSectionName, &size);
    if (data == NULL) {
      continue;
    }
    size_t count = size / sizeof(fb_tweak_entry);
    for (size_t i = 0; i < count; i++) {
      fb_tweak_entry *entry = &data[i];
      if (!entry->category || !entry->collection || !entry->value || !entry->name) {
        continue;
      }

      FBTweakCategory *category = [store tweakCategoryWithName:*entry->category];
      if (category == nil) {
        category = [[FBTweakCategory alloc] initWithName:*entry->category];
        [store addTweakCategory:category];
      }
    
      FBTweakCollection *collection = [category tweakCollectionWithName:*entry->collection];
      if (collection == nil) {
        collection = [[FBTweakCollection alloc] initWithName:*entry->collection];
        [category addTweakCollection:collection];
      }
    
      NSString *identifier = _FBTweakIdentifier(entry);
      if ([collection tweakWithIdentifier:identifier] == nil) {
        id<FBTweak> tweak = _FBTweakCreateWithEntry(identifier, entry);

        if (tweak != nil) {
          [collection addTweak:tweak];
        }
      }
    }
  }
}

@end

#endif
