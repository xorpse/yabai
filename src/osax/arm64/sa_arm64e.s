.global _start
.align 2

_start:
sub sp, sp, #0x20
stp x29, x30, [sp, #0x10]
add x29, sp, #10
add x0, sp, #0x8

adr x9, __pthread_set_self
ldr x9, [x9]
blr x9

adr x2, _payload
paciza x2

add x0, sp, #0x8
mov x1, #0
mov x3, #0
adr x9, _pthread_create_from_mach_thread
ldr x9, [x9]
blr x9

adr x9, _mach_thread_self
ldr x9, [x9]
blr x9

adr x9, _thread_suspend
ldr x9, [x9]
blr x9

ldp x29, x30, [sp, #0x10]
add sp, sp, #0x20
ret

_payload:
pacibsp
stp x29, x30, [sp, #-0x10]!
mov x29, sp

adr x0, _payload_path
mov w1, #0x2
adr x9, _dlopen
ldr x9, [x9]
blr x9

cbnz x0, _payload_done

adr x9, _dlerror
ldr x9, [x9]
blr x9

_payload_done:
mov x0, #0

ldp x29, x30, [sp], #0x10
retab

; function pointers
__pthread_set_self: .ascii "AAAAAAAA"
_pthread_create_from_mach_thread: .ascii "BBBBBBBB"
_mach_thread_self: .ascii "CCCCCCCC"
_thread_suspend: .ascii "DDDDDDDD"
_dlopen: .ascii "EEEEEEEE"
_dlerror: .ascii "FFFFFFFF"

; data
_payload_path: .ascii "/Library/ScriptingAdditions/yabai.osax/Contents/Resources/payload.bundle/Contents/MacOS/payload\0"
