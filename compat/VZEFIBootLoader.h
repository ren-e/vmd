//
//  VZLinuxBootLoader.h
//  Virtualization
//
//  Copyright © 2019-2020 Apple Inc. All rights reserved.
//

#import <Virtualization/VZBootLoader.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @abstract Boot loader configuration for EFI firmware.
*/
VZ_EXPORT API_AVAILABLE(macos(11.0))
@interface _VZEFIBootLoader : VZBootLoader

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/*!
 @abstract URL of the EFI firmware.
*/
@property (copy) NSURL *efiURL;


@property (readwrite, nullable, strong) _VZEFIVariableStore *VariableStore;

@end


NS_ASSUME_NONNULL_END
