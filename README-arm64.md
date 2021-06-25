# ARM64 specifics

Enter recovery mode and disable SIP using:

```
$ csrutil disable --with kext --with dtrace --with basesystem
```

Reboot and add boot arguments and reboot again:

```
$ sudo nvram boot-args=-arm64e_preview_abi
```

Build using the `makefile`:

```
$ make -j1
$ make sign
```

# Loading script additions

```
$ sudo ./bin/yabai --install-sa
$ sudo ./bin/yabai --load-sa
```
