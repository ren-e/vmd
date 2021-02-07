# macOS vmd
The vmd application from OpenBSD has been adjusted to work on macOS.
This version uses the Apple Hypervisor Framework, which came with macOS Big Sur.

This tool is like SimpleVM and vftool, but followes the vmd/vmctl syntax.

### Requirements
  - macOS >= 11.0

### Compile
```
make
```

### Run
To start the VM in verbose mode:
```
./vmctl -v start -cb vmlinuz \
	-i initrd.gz \
	-k "console=hvc0 root=/dev/vda" \
	-d disk.img \
	-l 01:23:45:67:89:ab \
	-m 1g \
	-p 1 \
	vm_name
```

This will automatically spawn a new console session to interact with the guest.

Multiple disks can be attached by repeating the -d flag.

The -l flag can be used to specify the link layer address (MAC address). This
should be specified as six colon-separated hex values.

### Shutdown
To shutdown a running VM press CTRL+C in the terminal, or send the SIGINT
signal. When a cu session is still running, first enter ~., and then CTRL+C.
Keep repeating the signal to forcefully shutdown the VM.

### Console handling
The program cu is used to facilitate the console. When the -c flag has been used
with vmctl, then the console will automatically open. The uucp directory must be
writable, which can be fixed with:
```
sudo chmod 775 /var/spool/uucp/
sudo chgrp staff /var/spool/uucp/
```

If cu doesn't respond to ~ commands, make sure to enter CTRL+D first.

### Linux guests
Currently, only Linux guests are supported due to the framework limitations. Not
all distributions support the virtio console out of the box (like Debian). Make
sure to boot these systems with `console=tty1`, so you can add the required
modules to `/etc/initramfs-tools/modules`:
```
virtio
virtio_pci
virtio_blk
virtio_net
virtio_console
```
After changing the modules file re-create the initramfs image:
```
update-initramfs -u
```

Copy the new initramfs image to the host, and then you should be able to use
the virtio console (hvc0).
