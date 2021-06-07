# yabai-injector

Provides an alternative means to inject the scripting additions payload.

## Building and usage

Edit `config.h` to set the path to the scripting additions payload.

Build with:

```.sh
$ make
```

Run with:

```.sh
$ ./yabai-injector
```

## Notes

The injector will be built with the setuid bit set and so will run as root
without prompting for a password.
