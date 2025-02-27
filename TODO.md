# uki-tool todo list

List of todo task for the `uki-tool` project

### Todo 📍

- [ ] sdboot: add more verifiaction about arch provided.
  IA32, x64, IA64, ARM, AA64,
- [ ] grub2: when searching if config exists, need to base on uki name id
  instead of path
- suite test:
  - [ ] Check versioning of uki-tool when verifying kernel size to take the
    correct value to compare. See
    [systemd issue 35851](https://github.com/systemd/systemd/issues/35851)
  - [ ] Add `--package` argument to test the uki package distributed by the
    distribution.
  - [ ] Improve the UKI test by checking the systemd services values in a basic
    boot and status of same services after booting the UKI
  - [ ] Made the test-suite executable for openQA server
  - [ ] Create missing TESTs

### In Progress ⌛

### Done 🏁

- [x] Create bases features
- [x] Optimize sized of image
- [x] Create command to add/remove grub2 entry
- [x] Write the documentation (README)
- [x] make shellcheck compliant
- [x] build script: add debug argument (Add verbosity)
- [x] Create command to generate UKI
- [x] extension cmd: Get the list of packages dependencies
- [x] install script: write it and add the install dir argument
- [x] Write a Man
- [x] set default options for bootloader
- [x] Write a suite test
