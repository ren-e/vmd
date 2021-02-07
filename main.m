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

#include <stdio.h>
#include <err.h>
#include <sys/stat.h>
#include <sys/tty.h>
#include "vmctl.h"
#include "vmd.h"

#define RAW_FMT		"raw"
#define QCOW2_FMT	"qcow2"

__dead void	 usage(void);
__dead void	 ctl_usage(struct ctl_command *);


struct ctl_command ctl_commands[] = {
	{ "start",	CMD_START,	ctl_start,
	    "[-c] [-b path] [-k cmdline] [-i path] [-d disk]\n"
	    "\t\t[-m size] [-p count] [-l lladdr] id | name" },
	{ NULL }
};

__dead void
usage(void)
{
	extern char	*__progname;
	int		 i;

	fprintf(stderr, "usage:\t%s [-v] command [arg ...]\n",
	    __progname);
	for (i = 0; ctl_commands[i].name != NULL; i++) {
		fprintf(stderr, "\t%s %s %s\n", __progname,
		    ctl_commands[i].name, ctl_commands[i].usage);
	}
	exit(1);
}


__dead void
ctl_usage(struct ctl_command *ctl)
{
	extern char	*__progname;

	fprintf(stderr, "usage:\t%s [-v] %s %s\n", __progname,
	    ctl->name, ctl->usage);
	exit(1);
}


int
main(int argc, char *argv[])
{
	int	 ch;
	verbose = 1;

	while ((ch = getopt(argc, argv, "v")) != -1) {
		switch (ch) {
		case 'v':
			if (verbose < 4)
				verbose += 1;
			break;
		default:
			usage();
			/* NOTREACHED */
		}
	}
	argc -= optind;
	argv += optind;
	optreset = 1;
	optind = 1;

	if (argc < 1)
		usage();

	return (parse(argc, argv));
}

int
parse(int argc, char *argv[])
{
	struct ctl_command	*ctl = NULL;
	struct parse_result	 res;
	int			 i;

	memset(&res, 0, sizeof(res));
	res.nifs = -1;

	for (i = 0; ctl_commands[i].name != NULL; i++) {
		if (strncmp(ctl_commands[i].name,
		    argv[0], strlen(argv[0])) == 0) {
			if (ctl != NULL) {
				fprintf(stderr,
				    "ambiguous argument: %s\n", argv[0]);
				usage();
			}
			ctl = &ctl_commands[i];
		}
	}

	if (ctl == NULL) {
		fprintf(stderr, "unknown argument: %s\n", argv[0]);
		usage();
	}

	res.action = ctl->action;
	res.ctl = ctl;

	if (ctl->main(&res, argc, argv) != 0)
		exit(1);

	return (0);
}

int
ctl_start(struct parse_result *res, int argc, char *argv[])
{
	int		 ch, type;
	char		 path[PATH_MAX];

	while ((ch = getopt(argc, argv, "b:k:i:d:m:p:l:c")) != -1) {
		switch (ch) {
                case 'b':
			if (res->kernelpath)
				errx(1, "Kernel path specified multiple times");
			if (realpath(optarg, path) == NULL)
				err(1, "invalid kernel path");
			res->kernelpath = [NSString stringWithUTF8String:optarg];
			break;
                case 'k':
			if (res->kernelcmdline)
				errx(1, "Kernel commandline specified multiple times");
			res->kernelcmdline = [NSString stringWithUTF8String:optarg];
			break;
		case 'i':
			if (res->initrdpath)
				errx(1, "Initrd image path specified multiple times");
			if (realpath(optarg, path) == NULL)
				err(1, "invalid initrd image path");
			res->initrdpath = [NSString stringWithUTF8String:optarg];
			break;
		case 'd':
			type = VMDF_RAW;
			if (realpath(optarg, path) == NULL)
				err(1, "invalid disk path");
			if (parse_disk(res, path, type) != 0)
				errx(1, "invalid disk: %s", optarg);
			break;
		case 'm':
			if (res->size)
				errx(1, "memory specified multiple times");
			if (parse_size(res, optarg) != 0)
				errx(1, "invalid memory size: %s", optarg);
			break;
		case 'p':
			if (res->vcpu)
				errx(1, "vCPU specified multiple times");
			if (parse_vcpu(res, optarg, 0) != 0)
				errx(1, "invalid vCPU amount");
			break;
		case 'l':
			if (res->lladdr)
				errx(1, "Linklocal address specified multiple times");
			res->lladdr = [NSString stringWithUTF8String:optarg];
			break;
		case 'c':
			if (access("/var/spool/uucp/", W_OK) != 0)
				errx(1, "Ensure directory /var/spool/uucp/ is writable");
			res->tty_autoconnect = 1;
			break;
		default:
			ctl_usage(res->ctl);
			/* NOTREACHED */
		}
	}
	argc -= optind;
	argv += optind;

	if (argc != 1)
		ctl_usage(res->ctl);

	if (parse_vmid(res, argv[0], 0) == -1)
		errx(1, "invalid id: %s", argv[0]);

	return (vm_action(res));
}

int
parse_vmid(struct parse_result *res, char *word, int needname)
{
	const char	*error;
	uint32_t	 id;

	if (word == NULL) {
		warnx("missing vmid argument");
		return (-1);
	}
	if (*word == '-') {
		/* don't print a warning to allow command line options */
		return (-1);
	}
	id = strtonum(word, 0, UINT32_MAX, &error);
	if (error == NULL) {
		if (needname) {
			warnx("invalid vm name");
			return (-1);
		} else {
			res->id = id;
			res->name = NULL;
		}
	} else {
		if (strlen(word) >= VMM_MAX_NAME_LEN) {
			warnx("name too long");
			return (-1);
		}
		res->id = 0;
		if ((res->name = strdup(word)) == NULL)
			errx(1, "strdup");
	}

	return (0);
}

int
parse_vcpu(struct parse_result *res, char *word, int val)
{
	const char	*error;

	if (word != NULL) {
		val = strtonum(word, 1, 4, &error);
		if (error != NULL)  {
			warnx("count is %s: %s", error, word);
			return (-1);
		}
	}
	res->vcpu = val;

	return (0);
}



int
parse_size(struct parse_result *res, char *word)
{
	long long val = 0;

	if (word != NULL) {
		if (scan_scaled(word, &val) != 0) {
			warn("invalid size: %s", word);
			return (-1);
		}
	}

	if (val < (1024 * 1024)) {
		warnx("size must be at least one megabyte");
		return (-1);
	} else
		res->size = val;

	if (res->size != val)
		warnx("size rounded to %lld megabytes", res->size);

	return (0);
}

int
parse_disk(struct parse_result *res, char *word, int type)
{
	char		**disks;
	int		*disktypes;
	char		*s;

	if ((disks = reallocarray(res->disks, res->ndisks + 1,
	    sizeof(char *))) == NULL) {
		warn("reallocarray");
		return (-1);
	}
	if ((disktypes = reallocarray(res->disktypes, res->ndisks + 1,
	    sizeof(int))) == NULL) {
		warn("reallocarray");
		return -1;
	}
	if ((s = strdup(word)) == NULL) {
		warn("strdup");
		return (-1);
	}
	disks[res->ndisks] = s;
	disktypes[res->ndisks] = type;
	res->disks = disks;
	res->disktypes = disktypes;
	res->ndisks++;

	return (0);
}

__dead void
ctl_openconsole(struct vmconfig *vmcfg)
{
	if (verbose > 1)
		NSLog(@"Spawning console session, press ~. to terminate.");

	execl(VMCTL_CU, VMCTL_CU, "-l", vmcfg->vm_ttyname, "-s", "115200",
		(char *)NULL);
	err(1, "failed to open the console");
}
