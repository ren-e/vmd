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
./vmctl -v start -cb vmlinuz -i initrd.gz -k "console=hvc0 root=/dev/vda" -d disk.img -m 1g -p 1 vm_name
```

This will automatically spawn a new screen session to interact with the guest.

Multiple disks can be attached by repeating the -d flag.

The -l flag can be used to specify the linklocal address.
