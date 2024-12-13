# Unified Kernel Image Tool (UKIT)

> * **Author**: Valentin LEFEBVRE <valentin.lefebvre@suse.com>
> * **Created at**: 2023-05-04
> * **Updated at**: 2024-12-16
> * **Description**:Utilities to help with UKI and static initrd projects.
> * **version**: 1.4.1
> * **Topics**
>   * [I-Description](#i---description)
>   * [II-Installation](#ii---installation)
>   * [III-Commands](#iii---commands)
>   * [IV-Contributing](./CONTRIBUTING.md)
>   * [V-Changelog](./CHANGELOG.md)
>   * [VI-Documentations](./docs/)

## I - Description

Tool that regroups useful command dealing with the Unified Kernel Image (UKI)
and static initrd project. Write in shell script, and adapted to the
**packaging**.

## II - Installation

### a) From scratch

1. Clone the project `git clone gitlab.suse.de/vlefebvre/ukit.git && cd ukit/`
2. Build to project using `sh build.sh`
    * merge all command script with the main into one called `uki-tool` into
      build directory.
3. Install the project using `sh install.sh --prefix=$HOME/.share/`

### b) From distributions

* Add the repo:

    ```bash
    zypper ar https://download.opensuse.org/repositories/home:/vlefebvre:/unified/standard/home:vlefebvre:unified.repo
    ```

* Install the package with zypper

    ```bash
    zypper refresh
    zypper install uki-tool
    ```

## III - Commands

```bash
USAGE: uki-tool [help] [verbose] COMMAND [help | COMMAND OPTION]
OPTIONS:
  - help:               Print this helper
  - verbose:            Print debug information to the output
  - COMMAND help:       Print the helper of the command
  - COMMAND [OPTION]:   Execute the command with additional options.
 
COMMANDS:
  - help
  - addon
  - create
  - extension
  - grub2
  - sdboot
```

### a) help

Print basically the helper of the tool `uki-tool`

### b) create

> Needs `ukify` tool

Generate PCR keys and use them to create an UKI.

```bash
USAGE: uki-tool create [OPTIONS]
OPTIONS:
  -k|--kerver:          Kernel Version 
                            [default: $(uname -r)]
  -i|--initrd:          Path to the initrd
                            [default: /usr/share/initrd/initrd-dracut-generic-kerver.unsigned]
  -n|--name:            Name to the UKI to generate 
                            [Default: uki]
  -c|--cmdline:         kernel cmdline 
                            [Default: rw rhgb]
  -o|--output:          Output dir where to generate the UKI.
                            [Default: $PWD]
  help:                 Print this helper
 
INFO:
    Generate PCR keys and use them to create an UKI using the systemd tool
'ukify'
 
EXAMPLE:
    uki-tool create -k 6.7.6-1-default -n uki-0.1.0.efi -o /usr/lib/modules/6.7.6-1-default/
```

### c) extension

Create well formatted extension for an Unified Kernel Image:

```bash
USAGE: uki-tool extension [OPTIONS]
OPTIONS:
  -n|--name:        Extension's name
  -p|--packages:    List of packages to install into the extension
  -f|--format:      Extension format (squashfs by default)
  -t|--type:        Type of the extension (dir, raw)
  -u|--uki:         Path to the referenced UKI (dedicated exetnsion)
  -a|--arch:        Specify an architecture
                        See https://uapi-group.org/specifications/specs/extension_image
                        For the list of potential value.
  --no-deps:        Build without any dependences
  help:             Print this helper
 
INFO:
    - Generate an extension for an UKI 'name-ext.format'.
    - If 'uki' parameter is set, the extension will be optimized by not taking
    into account the files already installed into it. The extension will be
    lighter. These extensions, depending on a specific uki, will have to be
    installed in '/usr/lib/modules/KERV_VER/UKI_NAME.extrad.d/'.
    - Without 'uki', it will generate gloabal extension that could extends all
    UKI. It will need to be installed into '/usr/lib/modules/uki.extra.d/'.
 
EXAMPLE:
    uki-tool extension -n "debug" -p "strace,gdb" -t "raw"
```

* dedicated extensions: Extensions that  extend a particular UKI. The parameter
  "uki" could be used to optimise the size of the extension avoiding duplicate
  files.
* Generic, or global extensions: Extensions that could extend all UKI. Do not
  use the "uki" parameter to not be dependent of a specific one.

### d) grub2

> Needs `grub2-mkconfig` tool

Add useful commands dealing with grub2 menuentry. Can easily add or remove
menuentry for initrd or uki.

```bash
USAGE: uki-tool grub2 [OPTIONS]
OPTIONS:
  --add|--remove:       Add/Remove grub2 entry (mandatory)
  -k|--kerver:          Kernel Version [Default: 6.11.8-1-default]
  -i|--initrd:          Path to the initrd
  -u|--uki:             Path to the UKI
  --all-ukis:           Add or remove all ukis installed on the system
  -e|--efi:             efi directory [Default EFI/Linux]
  -D|--default:         set entry as default (only with --add)
  -t|--title:           Title of the entry
  -c|--cmdline:         cmdline arguments (works only with initrd)
  help:                 Print this helper
INFO:
    Create or remove an entry to the grub2 menu. If initrd argurment is provided, uki shouldn't, and vice versa.
    If the initrd provided isn't in the boot partition, it will copy it in /boot
    If the uki provided isn't in the the efi partition, it will copy it in EFI/Linux
    When remove is asked, --uki should point to the installed uki (in /boot partition )
 
EXAMPLE:
    uki-tool grub2 --add -k 6.3.4-1-default -u /usr/lib/modules/kerver/uki.efi
    uki-tool grub2 --remove -u /boot/efi/EFI/Linux/uki.efi
```

### e) sdboot

> Needs `bootctl` tool with patch for UKI.

Create or remove an entry to the UKI for sdboot installed for a specified Kernel
version.

```bash
USAGE: uki-tool sdboot [OPTIONS]
OPTIONS:
  --add | --remove:     Add / Remove sdboot entry (mandatory)
  -k|--kerver:          Kernel Version [Default: 6.11.8-1-default]
  -i|--initrd:          Path to the initrd
  -u|--uki:             Path to the UKI name (should be end by .efi)
  --all-ukis:           Add or remove all ukis installed on the system
  -a|--arch:            Architecture to use [Default 'uname -m']
  -e|--efi:             efi directory [Default EFI/Linux]
  -D|--default:         set entry as default (only with --add)
  -t|--title:           Title of the entry
  -c|--cmdline:         cmdline arguments (works only with initrd)
  help:                 Print this helper
 
INFO:
  Create or remove a sdboot entry for the specified UKI or initrd.
  If uki from path (--uki) point to a binary outside the boot partition, it will try to install it into /boot/efi/.
  If uki just mention an uki name file, it will search the binary from '/usr/lib/modules/$ker_ver/$image'.
  If the initrd provided isn't in the boot partition, it will copy it in /boot.
 
EXAMPLE:
  uki-tool sdboot --add -k 6.11.8-1-default -efi /EFI/opensuse -u uki-0.1.0.efi
  uki-tool sdboot --remove -k 6.11.8-1-default -u uki-0.1.0.efi
```

### f) addon

> Needs `ukify` tool

Create an Addon with a custom cmdline section.

```bash
USAGE: uki-tool addon [OPTIONS]
OPTIONS:
  -c|--cmdline:         To put in .cmdline section
  -n|--name:            Name of the addon
  -o|--output:          Output dir where to generate the addon.
                            [Default: $PWD]
  help:                 Print this helper
 
INFO:
    Generate an addon with a custom .cmdline section using the systemd tool
'ukify'
 
EXAMPLE:
    uki-tool addon -c ='|Test uki addon|' -o /boot/efi/EFI/loader/addons -n test
```
