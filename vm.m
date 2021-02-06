/*
 * OpenBSD vmd/vmctl modified for macOS with Apple Hypervisor Framework
 */

/*
 * Copyright (c) 2015 Mike Larkin <mlarkin@openbsd.org>
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



int
vm_action(struct parse_result *res)
{
	int r = -1;
	struct vmconfig vmcfg;

	memset(&vmcfg, 0, sizeof(vmcfg));
	
	vmcfg.vm = [
		[VZVirtualMachineConfiguration alloc]
		init
	];
	if (vmcfg_init(res, &vmcfg))
		goto done;


	r = run_vm(res, &vmcfg);

done:
	if (vmcfg.vm)
		[vmcfg.vm release];

	if (vmcfg.vm_tty)
		close(vmcfg.vm_tty);

	return (r);
}


int
run_vm(struct parse_result *res, struct vmconfig *vmcfg)
{
	int pid = -1;

	/* TODO: Should trap signals here */
	dispatch_queue_t q = dispatch_queue_create(NULL, NULL);
        
        VZVirtualMachine *vm = [
		[VZVirtualMachine alloc]
		initWithConfiguration:vmcfg->vm
		queue:q
	];

	/* VM must be tested and started inside the queue */
	dispatch_sync(q, ^{
	  if (!vm.canStart) {
		NSLog(@"Failed to start VM");
		exit(1);
	  }
	  [vm startWithCompletionHandler:^(NSError * _Nullable errorOrNil) {
	  if (errorOrNil) {
		NSLog(@"Failed to start VM: %@", errorOrNil);
		exit(1);
	  }
	  }];
	});

	NSLog(@"Succesfully started VM %s", vmcfg->name);

	usleep(100);

	/* Spawn console on child */
	if (res->tty_autoconnect == 1) {
		pid = fork();                                                        
		if (pid == 0)
			ctl_openconsole(vmcfg);
	}

	/* Keepalive */
	while (
	  vm.state == VZVirtualMachineStateStarting ||
	  vm.state == VZVirtualMachineStateRunning
	) {
		sleep(1);
	}

	if (res->tty_autoconnect == 1) {
		pid = fork();
		if (pid == 0)
			ctl_closeconsole(vmcfg);
	}

	/* Wait for child to terminate */
	waitpid(pid, 0, 0);
	usleep(100);
	NSLog(@"VM %s has shutdown with state %ld", vmcfg->name, vm.state);

	if (vm)
		[vm release];

	return (0);
}
