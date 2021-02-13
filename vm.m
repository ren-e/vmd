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
#include <signal.h>
#include "vmctl.h"
#include "vmd.h"

#define HARD_ABORT_CTR 4

static int abortsignal = 0;

static void
abort_trap()
{
	if (abortsignal < HARD_ABORT_CTR)
		abortsignal += 1;
}

static void
log_vm_state(char *name, int state)
{
	if (abortsignal == HARD_ABORT_CTR)
		state = VZVirtualMachineStateStopped;

	switch (state) {
	case VZVirtualMachineStateStopped:
		if (abortsignal == HARD_ABORT_CTR)
			NSLog(@"VM %s has forcefully shutdown", name);
		else
			NSLog(@"VM %s has shutdown", name);
		break;
	case VZVirtualMachineStateRunning:
		NSLog(@"VM %s has started", name);
		break;
	case VZVirtualMachineStatePaused:
		NSLog(@"VM %s has paused", name);
		break;
	case VZVirtualMachineStateError:
		NSLog(@"VM %s has encountered an internal error", name);
		break;
	case VZVirtualMachineStateStarting:
		NSLog(@"VM %s is configuring the hardware and starting", name);
		break;
	case VZVirtualMachineStatePausing:
		NSLog(@"VM %s is being paused", name);
		break;
	case VZVirtualMachineStateResuming:
		NSLog(@"VM %s is being resumed", name);
		break;
	default:
		NSLog(@"VM %s in unknown state %d", name, state);
		break;
	}
}

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
stop_vm(dispatch_queue_t *q, VZVirtualMachine *vm)
{
	/* Reset abort signal */
	abortsignal = 0;

	/* Tell the hypervisor framework to shutdown the VM */
	if (vm.state == VZVirtualMachineStateRunning) {
		dispatch_sync(*q, ^{
			NSError * _Nullable *error = nil;
			if (vm.canRequestStop) {
				NSLog(@"Trying to shutdown VM");
				[vm requestStopWithError:error];
			}
			if (error || !vm.canRequestStop)
				NSLog(@"Could not shutdown VM");
		});
	} else {
		goto done;
	}

	/* Keepalive until shutdown or hard abort */
	while (vm.state == VZVirtualMachineStateRunning &&
	  abortsignal < HARD_ABORT_CTR) {
		sleep(1);
	}

done:
	return (0);
}


int
run_vm(struct parse_result *res, struct vmconfig *vmcfg)
{
	int pid = -1;

	/* Trap CTRL+C */
	signal(SIGINT, abort_trap);

	dispatch_queue_t q = dispatch_queue_create(NULL, NULL);
        
        VZVirtualMachine *vm = [
		[VZVirtualMachine alloc]
		initWithConfiguration:vmcfg->vm
		queue:q
	];

	/* VM must be tested and started inside the queue */
	dispatch_sync(q, ^{
	  if (!vm.canStart)
		NSLog(@"Unable to start VM");

	  [vm startWithCompletionHandler:^(NSError * _Nullable errorOrNil) {
	  if (errorOrNil)
		NSLog(@"Failed to start VM: %@", errorOrNil);
	  }];
	});

	if (verbose > 1)
		log_vm_state(vmcfg->name, vm.state);

	/* Spawn console on child */
	if (res->tty_autoconnect == 1) {
		pid = fork();                                                        
		if (pid == 0)
			ctl_openconsole(vmcfg);
	}

	/* Wait for final VM state */
	while (vm.state == VZVirtualMachineStateStarting && abortsignal == 0) {
		usleep(100);
	}

	if (vm.state != VZVirtualMachineStateRunning)
		goto done;

	log_vm_state(vmcfg->name, vm.state);

	/* Keepalive */
	while (vm.state == VZVirtualMachineStateRunning && abortsignal == 0) {
		sleep(1);
	}

	if (abortsignal)
		stop_vm(&q, vm);

done:
	if (res->tty_autoconnect == 1 && pid != -1)
		kill(pid, SIGINT);

	/* Wait for child to terminate */
	waitpid(pid, 0, 0);
	log_vm_state(vmcfg->name, vm.state);

	if (vm)
		[vm release];

	if (q)
		dispatch_release(q);

	return (0);
}
