# Contributing Guidelines

## Coding Style

* Each commands should contains there code into the `./commands/` directory
* The script should contains 3 mains functions
  * `${cmd_name}_helper` - Print the helper of the command
  * `${cmd_name}_tools_needed` - Print the list of needed tool for the command
  * `${cmd_name}_exec` - Execute the command
* The tests should contains 2 mains functions
  * `test_run` - Run the test
  * `test_tools_needed` - Print the list of needed tool for the tests
  * Read the doc [test-suite](./docs/test-suite.md)
* All global variable from the script should begin by the command name in
  capital letters.
* All script should be compliant with `shellcheck`
* Script lines should not exceed 80 characters
