/*
 * OpenBSD vmd/vmctl modified for macOS with Apple Hypervisor Framework
 */

/*
 * Copyright (c) 2015 Reyk Floeter <reyk@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <Virtualization/Virtualization.h>

#include <err.h>
#include <sys/stat.h>
#include <sys/tty.h>
#include "vmctl.h"
#include "vmd.h"

#ifdef WITH_EFI
  #include "compat/VZEFIVariableStore.h"
  #include "compat/VZEFIBootLoader.h"
#endif

int
vmcfg_init(struct parse_result *res, struct vmconfig *vmcfg)
{
	NSError *error = nil;

	/* OpenTTY */
	if (vm_opentty(vmcfg))
		goto err;

	/* Configure VM */
	if (vmcfg_vhw(res, vmcfg->vm))
		goto err;
#ifdef WITH_EFI
	if (res->efi) {
		if (vmcfg_efi_boot(res, vmcfg->vm))
			goto err;
	} else {
		if (vmcfg_boot(res, vmcfg->vm))
			goto err;
	}
#else
	if (vmcfg_boot(res, vmcfg->vm))
		goto err;
#endif
	if (vmcfg_storage(res, vmcfg->vm))
		goto err;
	if (vmcfg_net(res, vmcfg->vm))
		goto err;
	if (vmcfg_console(res, vmcfg))
		goto err;
	if (vmcfg_misc(res, vmcfg->vm))
		goto err;

	/* Validate configuration */
	error = nil;
	[vmcfg->vm validateWithError:&error];
	if (error)
		goto err;

	vmcfg->name = strdup(res->name);

	if (verbose > 1)
		NSLog(@"Succesfully initialized VM %s", vmcfg->name);


	return (0);
err:
	if (error)
		NSLog(@"Failed to initialize VM configuration: %@", error);
	else
		NSLog(@"Failed to initialize VM configuration");

	return (-1);
}

int
vmcfg_vhw(struct parse_result *res, VZVirtualMachineConfiguration *vmcfg)
{
	NSError *error = nil;

	[vmcfg setCPUCount:res->vcpu];
	[vmcfg setMemorySize:res->size];

	if (error)
		goto err;

	return (0);
err:
	NSLog(@"Unable to configure vCPU or memory: %@", error);
	return (-1);
}

#ifdef WITH_EFI

/*
 * XXX: Play time, but it will come when it comes.
 */

int
vmcfg_efi_boot(struct parse_result *res, VZVirtualMachineConfiguration *vmcfg)
{
	NSError *error = nil;
	NSURL *efiURL = [NSURL fileURLWithPath:res->kernelpath];
	NSURL *variableStoreURL = [NSURL fileURLWithPath:@"nvram.plist"];

	_VZEFIBootLoader *efi = [
		[_VZEFIBootLoader alloc]
		init
	];
	[efi setEfiURL:efiURL];

	/* XXX: -EE enables EFI Variable Store, plist ??? */
	if (res->efi == 2) {
		_VZEFIVariableStore *vars = [
			[_VZEFIVariableStore alloc]
			initWithURL:variableStoreURL
			error:&error
		];

		[efi setVariableStore:vars];
	}
	[vmcfg setBootLoader:efi];

	if (error)
		goto err;

	if (verbose > 1) {
		NSLog(@"Assigned file \"%@\" to EFI firmware",
		[res->kernelpath lastPathComponent]
		);
	}
	return (0);
err:
	NSLog(@"Unable to configure boot loader: %@", error);
	return (-1);
}
#endif

int
vmcfg_boot(struct parse_result *res, VZVirtualMachineConfiguration *vmcfg)
{
	NSError *error = nil;
	NSURL *kernelURL = [NSURL fileURLWithPath:res->kernelpath];
	NSURL *initrdURL;

	/* Linux bootloader and initramfs  */
	VZLinuxBootLoader *linux = [
		[VZLinuxBootLoader alloc]
		initWithKernelURL:kernelURL
	];

	if (res->kernelcmdline)
		[linux setCommandLine:res->kernelcmdline];

	if (res->initrdpath) {
		initrdURL = [NSURL fileURLWithPath:res->initrdpath];
		[linux setInitialRamdiskURL:initrdURL];
	}
	[vmcfg setBootLoader:linux];

	if (error)
		goto err;

	if (verbose > 1) {
		NSLog(@"Assigned file \"%@\" to kernel",
		[res->kernelpath lastPathComponent]
		);
		if (res->initrdpath) {
			NSLog(@"Assigned file \"%@\" to initramfs",
			[res->initrdpath lastPathComponent]
			);
		}
	}
	return (0);
err:
	NSLog(@"Unable to configure boot loader: %@", error);
	return (-1);
}

/* TODO: Allow multiple network devices */
int
vmcfg_net(struct parse_result *res, VZVirtualMachineConfiguration *vmcfg)
{
	NSError *error = nil;
	NSArray *ndevs = @[];
	VZMACAddress *lladdr;

	/* VirtIO network device */
	VZVirtioNetworkDeviceConfiguration *vio0 = [
		[VZVirtioNetworkDeviceConfiguration alloc]
		init
	];
	VZNetworkDeviceAttachment *nat = [
		[VZNATNetworkDeviceAttachment alloc]
		init
	];

	if (res->lladdr != NULL) {
		lladdr = [
			[VZMACAddress alloc]
			initWithString:res->lladdr
		];
	} else {
		lladdr = [VZMACAddress randomLocallyAdministeredAddress];
	}

	if (lladdr == NULL) {
		NSLog(@"Unable to assign link layer address to vio0");
		goto done;
	}

	[vio0 setMACAddress:lladdr];
	[vio0 setAttachment:nat];
	ndevs = [ndevs arrayByAddingObject:vio0];

	[vmcfg setNetworkDevices:ndevs];
	if (error)
		goto err;

	if (verbose > 1)
		NSLog(@"Assigned link layer address %@ to vio0", lladdr);

	return (0);
err:
	NSLog(@"Unable to configure network device: %@", error);
done:
	return (-1);
}

int
vmcfg_storage(struct parse_result *res, VZVirtualMachineConfiguration *vmcfg)
{
	int i;

	NSError *error = nil;
	NSArray *disks = @[];
	NSString *diskpath;
	NSURL *diskurl;

	/* VirtIO storage device */
	for (i=0; i < res->ndisks; i++) {
		diskpath = [NSString stringWithUTF8String:res->disks[i]];
		diskurl = [NSURL fileURLWithPath:diskpath];

		VZDiskImageStorageDeviceAttachment *sd = [
			[VZDiskImageStorageDeviceAttachment alloc]
			initWithURL:diskurl
			readOnly:false
                        error:&error
		];

		if (sd) {
			VZStorageDeviceConfiguration *disk = [
				[VZVirtioBlockDeviceConfiguration alloc]
				initWithAttachment:sd
			];
			disks = [disks arrayByAddingObject:disk];
			if (verbose > 1)
				NSLog(@"Assigned disk \"%@\" to sd%d\n",
					[diskpath lastPathComponent],
					i
				);
		}
	}
	[vmcfg setStorageDevices:disks];

	if (error)
		goto err;

	return (0);
err:
	NSLog(@"Unable to configure storage device: %@", error);
	return (-1);
}

int
vmcfg_console(struct parse_result *res, struct vmconfig *vmcfg)
{
	NSError *error = nil;
	NSFileHandle *inputfh = [
		[NSFileHandle alloc]
		initWithFileDescriptor:vmcfg->vm_tty
	];
	NSFileHandle *outputfh = [
		[NSFileHandle alloc]
		initWithFileDescriptor:vmcfg->vm_tty
	];

	/* VirtIO console device */
	VZSerialPortAttachment *ttyVI00 = [
		[VZFileHandleSerialPortAttachment alloc]
		initWithFileHandleForReading:inputfh
		fileHandleForWriting:outputfh
	];
	VZVirtioConsoleDeviceSerialPortConfiguration *viocon = [
		[VZVirtioConsoleDeviceSerialPortConfiguration alloc]
		init
	];
	[viocon setAttachment:ttyVI00];
	[vmcfg->vm setSerialPorts:@[viocon]];
	if (error)
		goto err;

	return (0);
err:
	NSLog(@"Unable to configure serial console: %@", error);
	return (-1);
}

int
vmcfg_misc(struct parse_result *res, VZVirtualMachineConfiguration *vmcfg)
{
	NSError *error = nil;

	/* VirtIO entropy device */
	VZEntropyDeviceConfiguration *viornd = [
		[VZVirtioEntropyDeviceConfiguration alloc]
		init
	];
	[vmcfg setEntropyDevices:@[viornd]];

	if (error)
		goto err;

	return (0);
err:
	NSLog(@"Unable to configure miscellaneous device: %@", error);
	return (-1);
}
