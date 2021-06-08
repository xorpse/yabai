//
// MOV             X8, X0
// LDR             X0, [X20,#0x10]
// MOV             X20, X8 ; eqv. r13 for x86-64 (display_space)
// BL              getAddSpaceOffset
//
static void asm__call_add_space(id new_space, id display_space, void(*fptr)(void)) {
    __asm__ __volatile__(
        "mov x0, %0\n"
        "mov x20, %1\n"
        ::
        "r"(new_space),
        "r"(display_space)
        : "x0", "x20");
    fptr();
}

//
// loc_100168C98
// ADRP            X8, #g_dock_spaces_ptr@PAGE
// NOP
// LDR             X20, [X8,#g_dock_spaces_ptr@PAGEOFF]
// CBZ             X20, loc_100168F68
// ...
// loc_100168CC4
// LDR             W26, [X21,#0x38]
// BL              sub_10016A9C8
// MOV             X0, X28 ; int
// MOV             X1, X19 ; int
// MOV             X2, X26 ; int
// BL              getMoveSpaceOffset
//
static void asm__call_move_space(id source_space, id dest_space, CFStringRef dest_display_uuid, id dock_spaces, void(*fptr)(void)) {
    __asm__ __volatile__(
        "mov x0, %0\n"
        "mov x1, %1\n"
        "mov x2, %2\n"
        "mov x20, %3\n"
        ::
        "r"(source_space),
        "r"(dest_space),
        "r"(dest_display_uuid),
        "r"(dock_spaces)
        : "x0", "x1", "x2", "x20");
    fptr();
}

// __DPDesktopPictureManager__addDisplay_notifyWindowServer__
//
// where this is the address of the ID passed:
//
// lea     r13, g_dock_spaces_ptr
// mov     rdi, [r13+0]    ; id
// mov     rsi, cs:selRef_currentSpaceForDisplay_ ; SEL
//
// ADRL            X21, g_dock_spaces_ptr
// LDR             X0, [X21] ; id
// ADRP            X8, #selRef_currentSpaceForDisplay_@PAGE
// LDR             X1, [X8,#selRef_currentSpaceForDisplay_@PAGEOFF] ; SEL
//

static uint64_t get_dock_spaces_addr(NSOperatingSystemVersion ver) {
  if (ver.majorVersion == 11) {
    if (ver.minorVersion == 3 && ver.patchVersion == 1) {
      return 0x1004264D0ULL;
    }

    if (ver.minorVersion == 4) {
      return 0x100426500ULL;
    }
  } else if (ver.majorVersion == 12) {
    return 0x10042FDD0ULL;
  }

  return 0;
}

// __DPDesktopPictureManager_init_
//
// where this is the address of the ID passed:
//
// mov     rcx, cs:classRef_DPDesktopPictureManager_0
// mov     [rax+8], rcx
// mov     rsi, cs:selRef_init ; SEL
// mov     rdi, rax        ; objc_super *
// call    _objc_msgSendSuper2
// mov     r15, rax
// lea     rdi, g_dppm     ; location
// mov     rsi, rax        ; obj
// call    _objc_storeStrong
//
// ADRP            X8, #classRef_DPDesktopPictureManager_0@PAGE
// LDR             X8, [X8,#classRef_DPDesktopPictureManager_0@PAGEOFF]
// STP             X0, X8, [SP,#0x280+var_128]
// ADRP            X8, #selRef_init@PAGE
// LDR             X1, [X8,#selRef_init@PAGEOFF] ; SEL
// ADD             X0, SP, #0x280+var_128 ; objc_super *
// BL              _objc_msgSendSuper2
// MOV             X19, X0
// ADRL            X0, g_dppm ; location
// MOV             X1, X19 ; obj
// BL              _objc_storeStrong

static uint64_t get_dppm_addr(NSOperatingSystemVersion ver) {
  if (ver.majorVersion == 11) {
    if (ver.minorVersion == 3 && ver.patchVersion == 1) {
      return 0x100426550ULL;
    }

    if (ver.minorVersion == 4) {
      return 0x100426580ULL;
    }
  } else if (ver.majorVersion == 12) {
    return 0x10042FE50ULL;
  }

  return 0;
}

static uint64_t get_add_space_addr(NSOperatingSystemVersion ver) {
  if (ver.majorVersion == 11) {
    if (ver.minorVersion == 3 && ver.patchVersion == 1) {
      return 0x100225DE0ULL;
    }

    if (ver.minorVersion == 4) {
      return 0x1002259D0ULL;
    }
  } else if (ver.majorVersion == 12) {
    return 0x10022B93CULL;
  }

  return 0;
}

static uint64_t get_remove_space_addr(NSOperatingSystemVersion ver) {
  if (ver.majorVersion == 11) {
    if (ver.minorVersion == 3 && ver.patchVersion == 1) {
      return 0x1002D6A58ULL;
    }

    if (ver.minorVersion == 4) {
      return 0x1002D668CULL;
    }
  } else if (ver.majorVersion == 12) {
    return 0x1002DE224ULL;
  }

  return 0;
}

static uint64_t get_move_space_addr(NSOperatingSystemVersion ver) {
  if (ver.majorVersion == 11) {
    if (ver.minorVersion == 3 && ver.patchVersion == 1) {
      return 0x1002C8ED0ULL;
    }

    if (ver.minorVersion == 4) {
      return 0x1002C8B04ULL;
    }
  } else if (ver.majorVersion == 12) {
    return 0x1002CFA8CULL;
  }

  return 0;
}

static uint64_t get_set_front_window_addr(NSOperatingSystemVersion ver) {
  if (ver.majorVersion == 11) {
    if (ver.minorVersion == 3 && ver.patchVersion == 1) {
      return 0x10004FBD8ULL;
    }

    if (ver.minorVersion == 4) {
      return 0x10004F5FCULL;
    }
  } else if (ver.majorVersion == 12) {
    return 0x10004E9D4ULL;
  }

  return 0;
}

const uint64_t payload_compat_base = 0x100000000ULL;

/*
uint64_t get_dock_spaces_offset(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return 0x0;
    }
    return 0;
}

uint64_t get_dppm_offset(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return 0x0;
    }
    return 0;
}

uint64_t get_add_space_offset(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return 0x210000;
    }
    return 0;
}

uint64_t get_remove_space_offset(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return 0x2c0000;
    }
    return 0;
}

uint64_t get_move_space_offset(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return 0x2b0000;
    }
    return 0;
}

uint64_t get_set_front_window_offset(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return 0x4e458;
    }
    return 0;
}

const char *get_dock_spaces_pattern(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return NULL;
    }
    return NULL;
}

const char *get_dppm_pattern(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return NULL;
    }
    return NULL;
}

const char *get_add_space_pattern(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return "7F 23 03 D5 F6 57 BD A9 F4 4F 01 A9 FD 7B 02 A9 FD 83 00 91 F5 03 14 AA 94 A2 00 91 9D 9E 03 94 F3 03 00 AA B3 5E 00 94 B6 16 40 F9 C8 FE 7E D3 08 02 00 B5 C8 E2 7D 92 15 09 40 F9 E0 03 15 AA 3F 5F 00 94 A8 06 00 B1 46 02 00 54 89 02 40 F9 29 E1 7D 92 28 09 00 F9 28 0D 15 8B 13 11 00 F9";
    }
    return NULL;
}

const char *get_remove_space_pattern(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return "7F 23 03 D5 FF 83 02 D1 FC 6F 04 A9 FA 67 05 A9 F8 5F 06 A9 F6 57 07 A9 F4 4F 08 A9 FD 7B 09 A9 FD 43 02 91 F5 03 03 AA F8 03 02 AA F3 03 01 AA F6 03 00 AA F4 03 01 AA 31 4D FD 97 FC 03 00 AA 08 FC 7E D3 A8 1E 00 B5 88 E3 7D 92 14 09 40 F9 9F 0A 00 F1 6B 0C 00 54 F5 4F 02 A9 A8 09 00 B0 1F 20 03 D5 08 81 46 F9 C8 02 08 8B 14 55 40 A9 28 0A 00 B0";
    }
    return NULL;
}

const char *get_move_space_pattern(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return "7F 23 03 D5 E3 03 1E AA A2 5A 00 94 FE 03 03 AA FD 7B 06 A9 FD 83 01 91 F6 03 14 AA F4 03 02 AA FA 03 01 AA FB 03 00 AA 17 0A 00 F0 F7 22 34 91 E8 02 40 F9 18 68 68 F8 E0 03 18 AA E1 03 16 AA 9F 2B 00 94 A0 01 00 B4 F3 03 00 AA F5 03 01 AA 88 0A 00 D0 08 D1 3F 91 08 01 40 39 1F 05 00 71 01 01 00 54 E0 03 13 AA E1 03 1A AA";
    }
    return NULL;
}

const char *get_set_front_window_pattern(NSOperatingSystemVersion os_version) {
    if ((os_version.majorVersion == 11) || (os_version.majorVersion == 10 && os_version.minorVersion == 16)) {
        return "7F 23 03 D5 FF 83 02 D1 F8 5F 06 A9 F6 57 07 A9 F4 4F 08 A9 FD 7B 09 A9 FD 43 02 91 88 19 00 B0 08 85 43 F9 08 01 40 F9 A8 83 1C F8 E1 10 00 34 F3 03 01 AA F4 03 00 AA 15 FC 60 D3 FF BF 00 39 E1 BF 00 91 9D A7 00 94 80 19 00 B0 00 40 44 F9 21 00 80 52 0B BE 0A 94 40 0A 00 36 F6 BF 40 39 E8 83 06 32 E8 53 06 29 08 80 80 52 E8 73 00 79";
    }
    return NULL;
}
*/
