# Test suite of uki-tool

> * **Author**: Valentin LEFEBVRE <valentin.lefebvre@suse.com>
> * **Created at**: 2025-02-25
> * **Updated at**: 2025-02-25
> * **Description**: Briefing of the uki-tool's test-suite

## Goals

* `uki-tool` aims to produce workflows to easily manage Unified Kernel Image,
  from the creation to the new bootloader menuentry.
* Most of the worflows can be testing directly in the host, wherever the
  sources are installed. However, some of them needs will need to be ran in a
  Virtual Machine. Testing the boot time of a generated UKI or checking if the
  bootloader has been well updated.
  To easily manage VM, choise goes to `mkosi` that generates customized disk
  images. [See mkosi repo](https://github.com/systemd/mkosi)
* The uki-tool's testsuite can be configured to run with and without a VM.

## mkosi architectures for test

### Main configuration

Using a main configuration file avoid having to call `mkosi` command with
multiple argument. In that way, we can call directly `mkosi build` to build
the image and then `mkosi vm` to run the vm in the same condition.

* see [mkosi.conf](./../tests/mkosi/mkosi.conf)
  * [Distribution] : For now only tumbleweed release is supported for this
    testsuite.
  * [Content] section defines all needed stuff for the image
    * **RootPassword**: set up a known root password
    * **Autologin**: Avoid having to login to the machine when it starts.
    * **Packages**: List of packages needed to run `uki-tool` inside the VM.
    * **Keymap** and **Timezoe**: are needed to not being stop in the vm
      creation. Otherwise, calling `mkosi vm` in background will block us.
  * [Runtime] allows configuring the Machine for the runtime
    * **Machine**: Name of the generated machine. Can be usefull when usgin
      `mkosi vm` to start the machine with a name, and `mkosi ssh` to connect
      or send a command to the correct machine with the name.
    * **RAM**: For our need, 1G is enought
    * **Register**: TO avoid conflict with `systemd-machined` in case the
      service is running, it is better to not register the machine. All process
      in the testsuite will go through mkosi.

### mkosi skeleton and mkosi.build

* To be able to test the last changes, our tool can be build in the same time
  as the machine.
* To provides our sources files into the build environment of the machine, a
  trick is to **symlink** our sources into **mksoi.skeleton**. It will be
  seen in `/buildroot` during the machine build time.
* [01-build-ukittool.sh](../tests/mkosi/mkosi.build.d/01-build-ukittool.sh)
    will contains shell command to build and install our `uki-tool`. Sources
    are fetched from `/buildroot` and generated files will be installed in
    `${DESTDIR}`. The generated tool will be install in our generated machine.

### mkosi.extra

* Files including in this directory will be including in the generated machine.
  * [00-sshd.preset](../tests/mkosi/mkosi.extra/usr/lib/systemd/system-preset/00-sshd.preset)
    is included to automatically start the sshd service in the machine
* mkosi disable sshd service by default. To be able to send command to the VM
  as soon as it has been started, itneeds to be enabled.

### mksoi.repart

* Tumbleweed image use grub2 bootloader, and we need an ESP partition to
  play with Unified KEernel Image. For that we need to configure our image to
  have a correct ESP partion.
  * [mkosi.repart/00-esp.conf](../tests/mkosi/mkosi.repart/00-esp.conf) creates
    a vfat ESP partion of 1G.
  * [mkosi.repart/10-root.conf](../tests/mkosi/mkosi.repart/10-root.conf)
    creates the root partition.

## Files architectures

### The test main script `test.sh`

The main script of the test suit. Run it to execute the testsuite:

```bash
sh tests/test.sh --help
```

### common file `common.sh`

Implement common functions:

```shell
###
# Print succeeded test
# ARGUMENTS:
#   1 - ID/Name of the test
# OUTPUTS:
#   test succeeded message
###
assert_test_OK()

###
# Print failure test
# ARGUMENTS:
#   1 - ID/Name of the test
# OUTPUTS:
#   test failure message
###
assert_test_NOK()

###
# Print info message for test
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
###
assert_info()

###
# Print a error message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   error message
###
assert_error()
###
# Run the cmd in the test environment (it could be in a VM)
# ARGUMENTS:
#   1 - command
# OUTPUTS:
#   cmd output
# RETURN:
#   return of the command
####
test_run_cmd()

###
# Run the cmd only if VM is used (usefull when dealing with reboot, bootloader)
# ARGUMENTS:
#   1 - command
# OUTPUTS:
#   cmd output
# RETURN:
#   return of the command
####
test_run_cmd_vm()

###
# Test reboot. Will only be executed if VM is used
# ARGUMENTS:
#   None
# OUTPUTS:
#   Status
# RETURN:
#   0 if rebooted
####
test_run_reboot()

###
# Get size of a file in bytes
#   1 - file path
# OUTPUTS:
#   None
# RETURN:
#   size
###
test_common_get_size_bytes()

###
# Extract the SizeOfImage from an EFI file using objdump
# ARGUMENTS:
#   1 - file path
# OUTPUTS:
#   size
###
test_common_get_SizeOfImage()

###
# Check if result is the one expected
# ARGUMENT:
#   1 - expected result
#   2 - result to test
#   3 - [optional] info msg
# OUTPUTS:
#   Error
# RETURN:
#   0 if good, > 0 otherwise
###
test_expected_results()
```

### vm file `vm.sh`

```bash
###
# Setting up the VM env and usefull variables
# ARGUMENTS:
#   1 - source directory (absolute path)
#   2 - test dir
# OUTPUTS:
#   None
# RETURN:
#   None
###
vm_setup()

###
# Build a VM using mkosi and its configuration files
# OUTPUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_build()

###
# Wait until the VM is booted or until the trigger of the timeout
# OUTPUTS:
#   Status
# Return:
#   0 if booted, 1 if timeout
###
vm_wait_boot()

###
# Boot a VM and check if it is ready waiting a timeout in case of failure
# ARGUMENTS:
#   1 - test dir (absolute path)
# OUTPUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_start()

###
# Exec a command in a booted VM
# OUTPUTS:
#   Command status
# RETURN:
#   0 id command success, >0 otherwise
###
vm_run_cmd()

###
# Update a value of the default conf for the grub bootloader in the created VM
# ARGUMENTS:
#   1 - Key
#   2 - Value
# OUTOUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_grub_update_default_conf()

###
# Reboot and wait the VM to be ready
# OUTPUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_reboot()

###
# Stop a booted VM by sending poweroff. If it fails, it fkills the PID
# OUTPUTS:
#   Status
# RETURN:
#   None
###
vm_stop()

###
# Kill the VM. Needed if the VM is stucked
# OUTPUTS:
#   Status
# RETURN:
#   None
###
vm_kill() 
```

### mkosi dir `mkosi/`

* Includes all mkosi configuration files needed

### suits dir `suits/`

* Include all tests to run

## test scripts

```bash
sh tests/test.sh --help
USAGE: tests/test.sh [OPTIONS]
OPTIONS:
  -u|--unit:        Run specific unit test by this filename
                        If not, run all tests
  -p|--path:        Path to the uki-tool script to test
  -v|--vm:          Use VM to run TESTs
  --reuse:          Take the previous test env if exists
                    Avoid VM creation, speed up the test
  --clear:          Clear generated test files
  help:             Print this helper
 
INFO:
    Test suite of the uki-tool script
```
