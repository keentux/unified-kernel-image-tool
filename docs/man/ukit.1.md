---
title: UKIT
section: 1
header: Manual of Unified Kernel Image Tool script
footer: Version 1.1.0
date: May 27, 2024
commnent: Generate man with `pandoc name.1.md -s -t man -o name.1`
---

# NAME
Unified Kernel Image Tool (UKI)

# SYNOPSIS
**ukit** [help|verbose] COMMANDS [*OPTION*]...

# DESCRIPTION

Tool that regroup useful command dealing with the Unified Kernel Image (UKI)
project. Write in shell script, and adapted to the **packaging**.

# COMMANDS
**create**
: Generate PCR keys and use them to create an UKI using the systemd tool
'ukify'

    * **-k**|**--kerver**: Kernel Version [default: 6.7.6-1-default]
    * **-i**|**--initrd**: Path to the initrd [Default: /usr/share/initrd/initrd-dracut-generic-kerver.unsigned]
    * **-n**|**--name**: Name to the UKI to generate [Default: uki]
    * **-c**|**--cmdline**: kernel cmdline [Default: rw rhgb]
    * **-o**|**--output**: Output dir where to generate the UKI. [Default: $PWD]
    * **help**: Print this helper

**extension**
: Generate an extension for an UKI 'name-ext.format'

    * **-n**|**--name**: Extension's name
    * **-p**|**--packages**: List of packages to install into the extension
    * **-f**|**--format**: Extension format (squashfs by default)
    * **-t**|**--type**: Type of the extension (dir, raw)
    * **-u**|**--uki**: Path to the referenced UKI (installed one by default)
    * **-a**|**--arch**: Specify an architecture See https://uapi-group.org/specifications/specs/extension_image For the list of potential value. Print this helper

**grub2**
: Create or remove an entry to the grub2 menu. If initrd argurment is provided, uki shouldn't, and vice versa. If the initrd provided isn't in the boot partition, it will copy it in /boot. If the uki provided isn't in the the efi partition, it will copy it in /boot/efi/EFI/opensuse

    * **-add-entry**|**--remove-entry**: Add/Remove grub2 entry (mandatory)
    * **-k**|**--kerver**: Kernel Version [Default: 6.7.6-1-default]
    * **-i**|**--initrd**: Path to the initrd
    * **-u**|**--uki**: Path to the UKI
    * **help**: Print this helper

**sdboot**
: Create or remove an entry to the UKI for sdboot installed for a specified Kernel version. It
will search binary from '/usr/lib/modules/$ker_ver/$image'.

    * **--add**: Add entry
    * **--remove**: Remove entry
    * **-k**|**--kerver**: Kernel Version [Default: 6.7.7-1-default]
    * **-i**|**--image**: Image name (should be end by .efi)
    * **-a**|**--arch**: Architecture to use [Default 'uname -m']
    * **help**: Print this helper

**addon**
: Generate an addon with a custom .cmdline section using the systemd tool
'ukify'

    * **-c**|**--cmdline**: To put in .cmdline section
    * **-n**|**--name**: Name of the addon
    * **-o**|**--output**: Output dir where to generate the addon. [Default: $PWD]
    * **help**: Print this helper

# EXAMPLES
**ukit create -k 6.7.6-1-default -n uki-0.1.0.efi -o /usr/lib/modules/6.7.6-1-default/**
: Create an unified kernel image, named 'uki-0.1.0.efi' taking the kernel '6.7.6-1-default' and
stored it into '/usr/lib/modules/6.7.6-1-default/'.

**ukit extension -n "debug" -p "strace,gdb" -t "raw"**
: Create a raw uki's extension, named "debug", containing 'strace,gdb' with their dependencies.

**ukit grub2 --add-entry -k 6.3.4-1-default -u /boot/efi/EFI/opensuse/uki.efi**
: Add an entry to the grub bootloader.

**ukit sdboot --add -k 6.3.4-1-default -i uki-0.1.0.efi**
: Add an entry to sdboot bootloader.

**ukit addon -c ='|Test uki addon|' -o /boot/efi/EFI/loader/addons -n test**
: Create an uki's addon named "test" used to add "|Test uki addon|" into the kernel cmdline.

# AUTHOR
Valentin Lefebvre <valentin.lefebvre@suse.com>

# REPORTING ISSUES
Submit bug reports onlie at:
<https://github.com/keentux/unified-kernel-image-tool/issues>

# COPYRIGHT
Copyright © 2024 Valentin Lefebvre. MIT License.

# SEE ALSO
Unified Kernel Image Tool at
<https://github.com/keentux/unified-kernel-image-tool/blob/main/README.md>