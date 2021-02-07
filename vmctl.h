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

#ifndef VMCTL_PARSER_H
#define VMCTL_PARSER_H


#define VMCTL_CU	"/usr/bin/cu"

int verbose;

enum actions {
	NONE,
	CMD_CONSOLE,
	CMD_CREATE,
	CMD_LOAD,
	CMD_LOG,
	CMD_RELOAD,
	CMD_RESET,
	CMD_START,
	CMD_STATUS,
	CMD_STOP,
	CMD_STOPALL,
	CMD_WAITFOR,
	CMD_PAUSE,
	CMD_UNPAUSE,
	CMD_SEND,
	CMD_RECEIVE,
};

struct ctl_command;

struct parse_result {
	enum actions		 action;
	NSString		*kernelpath;
	NSString		*initrdpath;
	NSString		*kernelcmdline;
	NSString		*lladdr;
	int			tty_autoconnect;
	int			vcpu;
	uint32_t		 id;
	char			*name;
	char			*path;
	char			*isopath;
	long long		 size;
	int			 nifs;
	char			**nets;
	int			 nnets;
	size_t			 ndisks;
	char			**disks;
	int			*disktypes;
	int			 verbose;
	char			*instance;
	unsigned int		 flags;
	unsigned int		 mode;
	unsigned int		 bootdevice;
	struct ctl_command	*ctl;
};
struct ctl_command {
	const char		*name;
	enum actions		 action;
	int			(*main)(struct parse_result *, int, char *[]);
	const char		*usage;
	int			 has_pledge;
};

struct vmconfig {
	uint32_t			 id;
	char				*name;
	int				 vm_tty;
	char				*vm_ttyname;
	VZVirtualMachineConfiguration	*vm;
};

/* main.c */
int	 ctl_start(struct parse_result *, int, char *[]);
int	 vmmaction(struct parse_result *);
int	 parse_vcpu(struct parse_result *, char *, int);
int	 parse_ifs(struct parse_result *, char *, int);
int	 parse_network(struct parse_result *, char *);
int	 parse_size(struct parse_result *, char *);
int	 parse_disktype(const char *, const char **);
int	 parse_disk(struct parse_result *, char *, int);
int	 parse_vmid(struct parse_result *, char *, int);
int	 parse_instance(struct parse_result *, char *);
void	 parse_free(struct parse_result *);
int	 parse(int, char *[]);
__dead void
	 ctl_openconsole(struct vmconfig *);
__dead void
	 ctl_closeconsole(struct vmconfig *);

/* config.m */
int	vmcfg_init(struct parse_result *, struct vmconfig *);
int	vmcfg_vhw(struct parse_result *, VZVirtualMachineConfiguration *);
int	vmcfg_boot(struct parse_result *, VZVirtualMachineConfiguration *);
int	vmcfg_net(struct parse_result *, VZVirtualMachineConfiguration *);
int	vmcfg_storage(struct parse_result *, VZVirtualMachineConfiguration *);
int	vmcfg_console(struct parse_result *, struct vmconfig *);
int	vmcfg_misc(struct parse_result *, VZVirtualMachineConfiguration *);

/* vm.m */
int	vm_action(struct parse_result *);
int	run_vm(struct parse_result *, struct vmconfig *);
int	stop_vm(dispatch_queue_t *, VZVirtualMachine *);

/* vmd.m */
int	vm_opentty(struct vmconfig *);

/* realllocarray.c */
void	*reallocarray(void *, size_t , size_t );

/* fmt_scaled.c */
int	scan_scaled(char *, long long *);

#endif /* VMCTL_PARSER_H */
