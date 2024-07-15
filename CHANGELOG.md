# Change Log

All notable changes to this project will be documented in this file.

## [x.x.x] - 2024-mm-dd

### Added

### Changed

* Format build and install script
* binary name from `ukit` to `uki-tool`

### Fixed

## [1.2.0] - 2024-05-27

### Added

* Snapper plugin to create snapshot with UKI.
* doc: Create the manual.
* doc: Add specfile.
* extension: add --no-deps option

### Changed

* Remove snapshot's condition about number, where uki snapshot douls be int text.
* Moving sources files

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
