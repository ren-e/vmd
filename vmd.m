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

#include <util.h>
#include <err.h>
#include <sys/stat.h>
#include <sys/tty.h>
#include "vmctl.h"
#include "vmd.h"

int
vm_opentty(struct vmconfig *vmcfg)
{
	int			 fd, ttys_fd;
	char			 ptyname[VM_TTYNAME_MAX];

	if (openpty(&fd, &ttys_fd, ptyname, NULL, NULL) == -1 ||
	    (vmcfg->vm_ttyname = strdup(ptyname)) == NULL) {
		fprintf(stderr, "%s: can't open tty %s", __func__, ptyname);
		goto fail;
	}

	vmcfg->vm_tty = fd;

	if (verbose > 1)
		NSLog(@"Succesfully opened tty at %s", ptyname);

	return (0);
fail:
	return (-1);
}
