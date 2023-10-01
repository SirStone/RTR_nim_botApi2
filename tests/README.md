# TESTs

Testing is good, testing si wise, testing is...boring

Here some test I've put together in order to do automatically check some (not all) aspect of these API.

How to run, in the root directory of this project
```shell
nimble test --out=bin/tests/test1
```

if you want stdout and sterr printed in the console at the end of the tests add _--debug_ at the end:
```shell
nimble test --out=bin/tests/test1 --debug
```