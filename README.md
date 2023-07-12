# Unified Kernel Image Tool (UKIT)

> * **Author**: Valentin LEFEBVRE <valentin.lefebvre@suse.com>
> * **Created at**: 2023-05-04
> * **Updated at**: 2023-07-12
> * **Description**:Utilities using osc command to automate repetitive action.
> * **version**: 0.2.1

## I - Description

Tool that regroup useful command dealing with the Unified Kernel Image (UKI)
project. Write in Bash script, and adapted to the packaging

## II - Installation

### a) From scratch

0. Clone the project `git clone gitlab.suse.de/vlefebvre/ukit.git && cd ukit/`
1. Build to project using `sh build.sh`
    * merge all command script with the main into one called `ukit` into build
    directory.
2. Install the project using `sh install.sh --prefix=$HOME/.share/`

### b) From distributions

* Add the repo from this [link](https://download.opensuse.org/repositories/home:/vlefebvre:/unified/standard/home:vlefebvre:unified.repo)

    ```bash
    [home_vlefebvre_unified]
    name=Unified (standard)
    type=rpm-md
    baseurl=https://download.opensuse.org/repositories/home:/vlefebvre:/unified/standard/
    gpgcheck=1
    gpgkey=https://download.opensuse.org/repositories/home:/vlefebvre:/unified/standard/repodata/repomd.xml.key
    enabled=1
    ```

* Install the package with zypper

    ````bash
    zypper refresh
    zypper install ukit
    ```

## III - Commands

```bash
./ukit [ help ] COMMAND [ help | COMMAND OPTION ] 
    - help: Print this helper
    - COMMAND help: Print the helper of the command
    - COMMAND [OPTION]: Execute the command with additional options.

List of COMMAND:
    - help
    - create
    - extension
    - grub2
```

### a) help

Print basically the helper of the tool `ukit`

### b) create

[WIP]

Command to create unified kernel image according tool used (dracut or
mkosi+ukify)

### c) extension

Create well formatted extension for an Unified Kernel Image:

```bash
ukit extension [-n | --name] [-p | --package] [-f | --format ] [ -t | --type]
    - -n|--name: Extension's name
    - -p|--packages: List of packages to install into the extension
    - -f|--format: Extension format [squashfs by default]
    - -t|--type: Type of the extension [dir, raw]
    - -u|--uki: Path to the referenced UKI [installed one by default]
    - -a|--arch: Specify an architecture
                See https://uapi-group.org/specifications/specs/extension_image/
                For the list of potential value.
    - help: Print this helper

Info:
    Generate an extension for an UKI 'name-ext.format'

example:
    ukit extension -n "debug" -p "strace,gdb" -t "raw"

```

### d) grub2

Add useful commands dealing with grub2 menuentry. Can easily add or remove
menuentry for initrd or uki.

```bash
./ukit grub2 [--add-entry | --remove-entry] [-k | --kerver] [-i | --initrd ] [ -u | --uki]
    - --add-entry|--remove-entry: Add/Remove grub2 entry (mandatory)
    - -k|--kerver: Kernel Version [uname -r output by default]
    - -i|--initrd: Path to the initrd
    - -u|--uki: Path to the UKI
    - help: Print this helper

Info:
    Create or remove an entry to the grub2 menu. If initrd argurment is provided,
uki shouldn't, and vice versa.
    If the initrd provided isn't in the boot partition, it will copy it in /boot
    If the uki provided isn't in the the efi partition, it will copy it in
/boot/efi/EFI/opensuse/ 

examples:
    ./ukit grub2 --add-entry -u /boot/efi/EFI/opensuse/uki.efi
    ./ukit grub2 --remove-entry -u /boot/efi/EFI/opensuse/uki.efi
    ./ukit grub2 --add-entry -k 6.3.4-1-default -i /boot/initrd
    ./ukit grub2 --remove-entry -k 6.3.4-1-default -i /boot/initrd
```
