/*	$OpenBSD: vmd.h,v 1.101 2020/09/23 19:18:18 martijn Exp $	*/

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

#define VMM_MAX_NAME_LEN	64

#include <sys/types.h>
#include <sys/queue.h>
#include <sys/socket.h>

#include <net/if.h>
#include <netinet/in.h>
#include <netinet/if_ether.h>
#include <netinet6/in6_var.h>

#include <limits.h>
#include <stdio.h>
#include <pthread.h>

#ifndef VMD_H
#define VMD_H

#define SET(_v, _m)		((_v) |= (_m))
#define CLR(_v, _m)		((_v) &= ~(_m))
#define ISSET(_v, _m)		((_v) & (_m))
#define NELEM(a) (sizeof(a) / sizeof((a)[0]))

#define VMD_USER		"_vmd"
#define VMD_CONF		"/etc/vm.conf"
#define SOCKET_NAME		"/var/run/vmd.sock"
#define VMM_NODE		"/dev/vmm"
#define VM_DEFAULT_BIOS		"/etc/firmware/vmm-bios"
#define VM_DEFAULT_KERNEL	"/bsd"
#define VM_DEFAULT_DEVICE	"hd0a"
#define VM_BOOT_CONF		"/etc/boot.conf"
#define VM_NAME_MAX		64
#define VM_MAX_BASE_PER_DISK	4
#define VM_TTYNAME_MAX		16
#define MAX_TAP			256
#define NR_BACKLOG		5
#define VMD_SWITCH_TYPE		"bridge"
#define VM_DEFAULT_MEMORY	512

#define VMD_DEFAULT_STAGGERED_START_DELAY 30

/* Rate-limit fast reboots */
#define VM_START_RATE_SEC	6	/* min. seconds since last reboot */
#define VM_START_RATE_LIMIT	3	/* max. number of fast reboots */

/* default user instance limits */
#define VM_DEFAULT_USER_MAXCPU	4
#define VM_DEFAULT_USER_MAXMEM	2048
#define VM_DEFAULT_USER_MAXIFS	8

/* vmd -> vmctl error codes */
#define VMD_BIOS_MISSING	1001
#define VMD_DISK_MISSING	1002
					/* 1003 is obsolete VMD_DISK_INVALID */
#define VMD_VM_STOP_INVALID	1004
#define VMD_CDROM_MISSING	1005
#define VMD_CDROM_INVALID	1006
#define VMD_PARENT_INVALID	1007

/* Image file signatures */
#define VM_MAGIC_QCOW		"QFI\xfb"

/* 100.64.0.0/10 from rfc6598 (IPv4 Prefix for Shared Address Space) */
#define VMD_DHCP_PREFIX		"100.64.0.0/10"

/* Unique local address for IPv6 */
#define VMD_ULA_PREFIX		"fd00::/8"



struct vm_dump_header_cpuid {
	unsigned long code, leaf;
	unsigned int a, b, c, d;
};

#define VM_DUMP_HEADER_CPUID_COUNT	5

struct vm_dump_header {
	uint8_t			 vmh_signature[12];
#define VM_DUMP_SIGNATURE	 VMM_HV_SIGNATURE
	uint8_t			 vmh_pad[3];
	uint8_t			 vmh_version;
#define VM_DUMP_VERSION		 7
	struct			 vm_dump_header_cpuid
	    vmh_cpuids[VM_DUMP_HEADER_CPUID_COUNT];
} __packed;

struct vmboot_params {
	off_t			 vbp_partoff;
	char			 vbp_device[PATH_MAX];
	char			 vbp_image[PATH_MAX];
	uint32_t		 vbp_bootdev;
	uint32_t		 vbp_howto;
	unsigned int		 vbp_type;
	void			*vbp_arg;
	char			*vbp_buf;
};

struct vmd_if {
	char			*vif_name;
	char			*vif_switch;
	char			*vif_group;
	int			 vif_fd;
	unsigned int		 vif_rdomain;
	unsigned int		 vif_flags;
	TAILQ_ENTRY(vmd_if)	 vif_entry;
};

struct vmd_switch {
	uint32_t		 sw_id;
	char			*sw_name;
	char			 sw_ifname[IF_NAMESIZE];
	char			*sw_group;
	unsigned int		 sw_rdomain;
	unsigned int		 sw_flags;
	int			 sw_running;
	TAILQ_ENTRY(vmd_switch)	 sw_entry;
};
TAILQ_HEAD(switchlist, vmd_switch);

#define VMOP_CREATE_CPU		0x01
#define VMOP_CREATE_KERNEL	0x02
#define VMOP_CREATE_MEMORY	0x04
#define VMOP_CREATE_NETWORK	0x08
#define VMOP_CREATE_DISK	0x10
#define VMOP_CREATE_CDROM	0x20
#define VMOP_CREATE_INSTANCE	0x40
#define VMBOOTDEV_AUTO		0
#define VMBOOTDEV_DISK		1
#define VMBOOTDEV_CDROM		2
#define VMBOOTDEV_NET		3
#define VMIFF_UP		0x01
#define VMIFF_LOCKED		0x02
#define VMIFF_LOCAL		0x04
#define VMIFF_RDOMAIN		0x08
#define VMIFF_OPTMASK		(VMIFF_LOCKED|VMIFF_LOCAL|VMIFF_RDOMAIN)
#define VMDF_RAW		0x01
#define VMDF_QCOW2		0x02

#endif /* VMD_H */
