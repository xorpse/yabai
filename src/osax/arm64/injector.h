#pragma once

#include <sys/types.h>
#include <mach/error.h>

extern kern_return_t inject(pid_t pid);
