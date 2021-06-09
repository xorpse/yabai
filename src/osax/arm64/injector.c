#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/error.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <pthread.h>
#include <mach/mach_vm.h>

#include <mach/arm/thread_status.h>
#include <mach/arm/_structs.h>
#include <ptrauth.h>

#include "sa_arm64e.h"

const uint64_t STACK_SIZE = 0x10000;
const char *SA_POINTER_SENTINEL = "AAAAAAAA";

static void fixup_shellcode() {
    uint64_t pthread_set_self_ptr = (uint64_t)ptrauth_strip((void (*)(void))dlsym(RTLD_DEFAULT, "_pthread_set_self"), ptrauth_key_asia);
    uint64_t pthread_create_from_mach_thread_ptr = (uint64_t)ptrauth_strip((void (*)(void))dlsym(RTLD_DEFAULT, "pthread_create_from_mach_thread"), ptrauth_key_asia);
    uint64_t mach_thread_self_ptr = (uint64_t)ptrauth_strip((void (*)(void))mach_thread_self, ptrauth_key_asia);
    uint64_t thread_suspend_ptr = (uint64_t)ptrauth_strip((void (*)(void))thread_suspend, ptrauth_key_asia);
    uint64_t dlopen_ptr = (uint64_t)ptrauth_strip((void (*)(void))dlopen, ptrauth_key_asia);
    uint64_t dlerror_ptr = (uint64_t)ptrauth_strip((void (*)(void))dlerror, ptrauth_key_asia);

    unsigned char *pointers = memmem(__src_osax_arm64_sa_arm64e, sizeof(__src_osax_arm64_sa_arm64e), SA_POINTER_SENTINEL, strlen(SA_POINTER_SENTINEL));
    if (!pointers) {
      return;
    }

    memcpy(pointers, &pthread_set_self_ptr, sizeof(uint64_t));
    pointers += sizeof(uint64_t);

    memcpy(pointers, &pthread_create_from_mach_thread_ptr, sizeof(uint64_t));
    pointers += sizeof(uint64_t);

    memcpy(pointers, &mach_thread_self_ptr, sizeof(uint64_t));
    pointers += sizeof(uint64_t);

    memcpy(pointers, &thread_suspend_ptr, sizeof(uint64_t));
    pointers += sizeof(uint64_t);

    memcpy(pointers, &dlopen_ptr, sizeof(uint64_t));
    pointers += sizeof(uint64_t);

    memcpy(pointers, &dlerror_ptr, sizeof(uint64_t));
}

static kern_return_t inject_task(task_t dock) {
  kern_return_t kr = KERN_SUCCESS;

  mach_vm_address_t stack_region = 0;
  mach_vm_address_t code_region = 0;

  if ((kr = mach_vm_allocate(dock, &stack_region, STACK_SIZE, VM_FLAGS_ANYWHERE)) != KERN_SUCCESS) {
    fprintf(stderr, "could not allocate stack region\n");
    return kr;
  }

  if ((kr = mach_vm_allocate(dock, &code_region, sizeof(__src_osax_arm64_sa_arm64e), VM_FLAGS_ANYWHERE)) != KERN_SUCCESS) {
    fprintf(stderr, "could not allocate code region\n");
    return kr;
  }

  if ((kr = mach_vm_write(dock, code_region, (vm_address_t)__src_osax_arm64_sa_arm64e, sizeof(__src_osax_arm64_sa_arm64e))) != KERN_SUCCESS) {
    fprintf(stderr, "could not write code region\n");
    return kr;
  }

  if ((kr = vm_protect(dock, code_region, sizeof(__src_osax_arm64_sa_arm64e), FALSE, VM_PROT_READ | VM_PROT_EXECUTE)) != KERN_SUCCESS) {
    fprintf(stderr, "could not set permissions on code region\n");
    return kr;
  }

  if ((kr = vm_protect(dock, stack_region, STACK_SIZE, TRUE, VM_PROT_READ | VM_PROT_WRITE)) != KERN_SUCCESS) {
    fprintf(stderr, "could not set permissions on stack region\n");
    return kr;
  }

  struct arm_unified_thread_state thread_state = { };
  struct arm_unified_thread_state machine_thread_state = { };

  thread_state_flavor_t flavor = ARM_UNIFIED_THREAD_STATE;
  mach_msg_type_number_t state_count = ARM_UNIFIED_THREAD_STATE_COUNT;
  mach_msg_type_number_t machine_state_count = ARM_UNIFIED_THREAD_STATE_COUNT;

  thread_act_t dock_thread = 0;

  memset(&thread_state, 0, sizeof(thread_state));
  memset(&machine_thread_state, 0, sizeof(machine_thread_state));

  stack_region += STACK_SIZE >> 1;

  thread_state.ash.flavor = ARM_THREAD_STATE64;
  thread_state.ash.count = ARM_THREAD_STATE64_COUNT;

  __darwin_arm_thread_state64_set_pc_fptr(
      thread_state.ts_64,
      ptrauth_sign_unauthenticated((void (*)(void))code_region, ptrauth_key_asia, 0)
  );

  __darwin_arm_thread_state64_set_sp(
      thread_state.ts_64,
      stack_region
  );

  if ((kr = thread_create(dock, &dock_thread)) != KERN_SUCCESS) {
    fprintf(stderr, "could not create thread: error %s\n", mach_error_string(kr));
    return kr;
  }

  void *module = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_GLOBAL | RTLD_LAZY);
  if (!module) {
    fprintf(stderr, "could not load `libsystem_kernel.dylib`\n");
    return KERN_FAILURE;
  }

  kern_return_t (*_thread_convert_thread_state)(
      thread_act_t, int, thread_state_flavor_t, thread_state_t, mach_msg_type_number_t, thread_state_t, mach_msg_type_number_t *
  ) = dlsym(module, "thread_convert_thread_state");

  dlclose(module);

  if (!_thread_convert_thread_state) {
    fprintf(stderr, "could not get address of `thread_convert_thread_state`\n");
    return KERN_FAILURE;
  }

  if ((kr = _thread_convert_thread_state(dock_thread, 2, flavor, (thread_state_t)&thread_state, state_count, (thread_state_t)&machine_thread_state, &machine_state_count)) != KERN_SUCCESS) {
    fprintf(stderr, "could not convert thread state: error %d %s\n", kr, mach_error_string(kr));
    return kr;
  }

  if ((kr = thread_set_state(dock_thread, flavor, (thread_state_t)&machine_thread_state, machine_state_count)) != KERN_SUCCESS) {
    fprintf(stderr, "could not set thread state: error %s\n", mach_error_string(kr));
    return kr;
  }

  if ((kr = thread_resume(dock_thread)) != KERN_SUCCESS) {
    fprintf(stderr, "could not start thread: error %s\n", mach_error_string(kr));
    return kr;
  }

  mach_port_deallocate(mach_task_self(), dock_thread);

  return kr;
}

kern_return_t inject(pid_t pid) {
    task_t task;
    kern_return_t kr = KERN_SUCCESS;

    fixup_shellcode();

    if ((kr = task_for_pid(mach_task_self(), pid, &task)) != KERN_SUCCESS) {
      return kr;
    }

    if ((kr = inject_task(task)) != KERN_SUCCESS) {
        fprintf(stderr, "could not perform injection into %d (Dock)\n", pid);
    }

    mach_port_deallocate(mach_task_self(), task);
    return kr;
}
