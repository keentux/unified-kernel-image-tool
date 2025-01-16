# Change Log

All notable changes to this project will be documented in this file.

## [1.x.x] - 2025-mm-dd

### Added

- test suite:
  - Creation of the testsuite skeleton including common test functions.
  - Using virtual machine manage by mkosi tool.
  - Make easier the integration of future test.
  - Add arguments to the main scripts:
    - vm: tu use VM for tests.
    - clear: to clear test environment.
    - dir: Use a custome dir, can be used to reuse previous env.
- testsuite documentation.

### Changed

- create: PCR keys will be generated and used only if asked
  - new arg: --pcrkeys
- common: Dynamicaly check the ESP patition.
- grub2: Remove insmod from menuentry

### Fixed

## [1.4.1] - 2024-12-16

### Added

- bootloaders:
  - all-ukis, remove/install bootloader entries for all installed ukis

### Changed

- Use common variable to get the kernel modules dir
- When removing the bootloader entry, remove also the associated installed UKI.

### Fixed

## [1.4.0] - 2024-09-09

### Added

- sdboot: Add static initrd argument
  - Add bootloader entry to a static initrd
  - When removing entry, remove the installed static initrd
- Check available size in efi before installing a file
- bootloaders:
  - Add title option
  - Add cmdline option
- common functions
  - get machine id
  - install file
  - check avaialble space in efi
  - install initrd in efi

### Changed

- grub2_initrd: Add the default option
- uki installation: Fromat the efi filename in the efi partition including the
  kernel major version in the name.

### Fixed

- grub2_initrd: fix root uuid discovering
- grub2 remove: use uki with id name instead of file name
- sdboot default: call bootctl set-default

## [1.3.0] - 2024-08-01

### Added

- sdboot:
  - add new paramters to choose in which efi directory deals
  - default one is "/EFI/Linux" but could be "/EFI/opensuse"

### Changed

- Format build and install script
- binary name from `ukit` to `uki-tool`
- extensi
- on:
  - Generate dedicated extensions with size optimisation
- Move device functions into common
  - common_get_dev
- Create a common function to install uki into efi dir
- sdboot paramter
  - BEAK RETRO-COMPATIBILITY
  - from "image" to "uki"
- sdboot indepependant of sdbootutil
  - Until uki feature is implemented into this tool, it uses now bootctl
    command and basic configuration files.
- Improve how entry are added/removed for sdboot and grub
  - Create the UKI in case of missing installation.

### Fixed

- sdboot: parameter should be "kerver" instead of "kernel"
- common: prefer verify "/boot/efi" to know if efi is in used.

## [1.2.0] - 2024-05-27

### Added

- Snapper plugin to create snapshot with UKI.
- doc: Create the manual.
- doc: Add specfile.
- extension: add --no-deps option

### Changed

- Remove snapshot's condition about number, where uki snapshot douls be int
  text.
- Moving sources files

### Fixed

## [1.1.0] - 2024-04-23

### Added

- sdboot's argument arch
- addon command
  - snapshots argument
- Documentation (static intiramfs and uki)

### Changed

- build.sh
  - don't use lines begining by export
  - Check if all needed functions for a verbs are defined

### Fixed

- Call the correct usage message from "create" verb

## [1.0.0] - 2024-01-06

### Added

- sdboot command: Add/Remove UKI entry for a specified kernel version for
  systemd-boot.
- create command: Generate PCR keys and create an UKI with them.

### Changed

- grub2: create dir in efi part
- helpers: Improve helper's messages
- Export useful variables (KER_NAME, KER_VER)

### Fixed

- grub2: fix variable condition
- print correct helper & check grub2 file
- grub2: fix: UUID device & transactional

## [0.3.0] - 2023-09-25

## Added

### Changed

- grub2: check kernel version only when add initrd
- extension: add default format to squashfs
- format script from bash to sh
  - Adding shellcheck verification

### Fixed

## [0.2.1] - 2023-07-02

### Added

- grub2 commmand
  - Add, remove entry for an initrd or an uki specified in the command line.

### Changed

- uki instalaltion path
- documentation and readme

### Fixed

- build script
  - Don't scip lines with '#!' at the beginning

## [0.1.1] - 2023-06-09

### Added

### Changed

- Optimized extension image size

### Fixed

## [0.1.0] - 2023-06-05

First version including basics features
