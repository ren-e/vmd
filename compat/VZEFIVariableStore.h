//
//  VZLinuxBootLoader.h
//  Virtualization
//
//  Copyright © 2019-2020 Apple Inc. All rights reserved.
//

#import <Virtualization/VZBootLoader.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @abstract EFI Variable store for EFI bootloader.
*/
VZ_EXPORT API_AVAILABLE(macos(11.0))
@interface _VZEFIVariableStore : VZBootLoader
- (nullable instancetype)initWithURL:(NSURL *)url error:(NSError * _Nullable *)error NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
