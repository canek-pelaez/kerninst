Kerninst
========

Kerninst is a little script that configures, compiles, and installs the kernel
which the `/usr/src/linux` symbolic link points to. It also generates an
appropriate initrd for this kernel using `dracut` (re emerging modules if
necessary), and updates `Bootctl` or `GRUB2` configuration files.

The script assumes to be running in a Gentoo install, and that a kernel
configuration file is provided. No attempt to autoconfigure the kernel is made.

The idea is that when the kernel is updated by portage, the user only needs to
do

```shell
eselect kernel set ${NEW_KERNEL}
kerninst
```

and the script will take care of everything else.

**WARNING**: The script will delete the kernel, initrd, and modules with the
same version as the kernel in `/usr/src/linux`; I take no responsibility in any
damage that may result by using it.
