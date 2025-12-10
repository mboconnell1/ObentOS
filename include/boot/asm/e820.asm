%ifndef __E820_ASM
    %define __E820_ASM

%include "defs.inc"

DetectMemoryE820:
        ; Initialise counters and flags
        xor     si, si          ; entry count = 0
        xor     bx, bx          ; continuation = 0 (on first call)
        xor     bp, bp          ; truncated flag = 0

        ; Clear usable_top
        xor     ax, ax
        mov     [e820_usable_top], ax
        mov     [e820_usable_top + 2], ax

        ; Point ES:DI at the start of E820_MAP buffer
        mov     ax, E820_MAP_SEG
        mov     es, ax
        mov     di, E820_MAP_OFF

.e820_loop:
        ; If we've filled out buffer, stop and mark as truncated
        cmp     si, E820_MAX_ENTRIES
        jae     .e820_truncated_by_buffer

        ; Prepare registers for INT 15h, AX=E820h
        mov     eax, 0xE820
        mov     edx, 0x534D4150
        mov     ecx, e820_entry_t_size
        ; BX already holds continuation value from previous call

        int     0x15
        jc      .e820_error     ; CF=1 => error/unsupported

        cmp     eax, 0x534D4150 ; did BIOS return 'SMAP'?
        jne     .e820_error

        ; Check Type == 1 (usable)
        mov     eax, [es:di + e820_entry_t.Type]
        cmp     eax, 1
        jne     .entry_not_usable

        ; Check Length != 0
        mov     eax, [es:di + e820_entry_t.LengthLow]
        mov     edx, [es:di + e820_entry_t.LengthHigh]
        or      eax, eax
        or      edx, edx
        jz      .entry_not_usable

        ; Check BaseAddr < 4 GiB
        mov     eax, [es:di + e820_entry_t.BaseAddrHigh]
        or      eax, eax
        jnz     .entry_not_usable

        ; Compute approximate end of region, clipped to 32 bits
        ; - if LengthHigh != 0 => treat end as 0xFFFFFFFF
        ; - else end32 = BaseLow + LengthLow
        mov     eax, [es:di + e820_entry_t.BaseAddrLow]
        mov     edx, [es:di + e820_entry_t.LengthHigh]
        cmp     edx, 0
        jne     .length_high_nonzero

        mov     edx, [es:di + e820_entry_t.LengthLow]
        add     edx, eax
        jc      .overflow_to_4g
        jmp     .have_region_end

.length_high_nonzero:
        ; Region extends beyond 4 GiB; clamp to max 32-bit address
        mov     edx, 0xFFFFFFFF
        jmp     .have_region_end

.overflow_to_4g:
        mov     edx, 0xFFFFFFFF

.have_region_end:
        ; Check end32 (highest address + 1) > current e820_usable_top
        mov     eax, [e820_usable_top]
        cmp     edx, eax
        jbe     .entry_not_usable

        ; This region extends higher; update usable_top = end32
        mov     [e820_usable_top], edx

.entry_not_usable:
        ; Entry is stored in E820_MAP; count it regardless of usability
        inc     si

        ; If continuation == 0, this was the last entry
        test    ebx, ebx
        jz      .e820_done_success

        ; Advance DI to next slot in E820_MAP
        add     di, e820_entry_t_size
        jmp     .e820_loop

.e820_truncated_by_buffer:
        ; BIOS indicated there are more entries than we have buffer space for;
        ; treat as truncated but still usable
        mov     bp, 1
        jmp     .e820_done_success

.e820_error:
        ; No entries were collected; treat as "no E820 support"
        cmp     si, 0
        jae     .e820_done_no_entries

        ; Partial map collected; treat as truncated
        mov     bp, 1
        jmp     .e820_done_success

.e820_done_no_entries:
        ; Fall through to finalise with si == 0 and bp == 0

.e820_done_success:
        ; ES:DI => boot_info_t
        mov     ax, BOOT_INFO_SEG
        mov     es, ax
        mov     di, BOOT_INFO_OFF

        ; Write E820MapPtr
        mov     eax, E820_MAP_MEM
        mov     [es:di + boot_info_t.E820MapPtr], eax

        ; Write E820EntryCount
        xor     eax, eax
        mov     ax, si
        mov     [es:di + boot_info_t.E820EntryCount], eax

        ; Write UsableMemTop
        mov     eax, [e820_usable_top]
        mov     [es:di + boot_info_t.UsableMemTop], eax

        ; Update flags
        mov     eax, [es:di + boot_info_t.Flags]

        ; Clear the E820-related bits, keep all others
        and     eax, E820_MASK

        ; If we have at least one entry, set E820-present bit
        cmp     si, 0
        je      .flags_no_e820
        or      eax, BOOT_INFO_FLAG_E820

        ; If truncated, set the E820_TR bit
        cmp     bp, 0
        je      .flags_skip_trunc
        or      eax, BOOT_INFO_FLAG_E820_TR

.flags_skip_trunc:
        ; If UsableMemTop != 0, set the UMTOP flag
        mov     edx, [e820_usable_top]
        test    edx, edx
        je      .flags_skip_umtop
        or      eax, BOOT_INFO_FLAG_UMTOP

.flags_skip_umtop:
        jmp     .flags_store

.flags_no_e820:
        ; No entries; E820-related bits remain clear

.flags_store:
        mov     [es:di + boot_info_t.Flags], eax

        ret

        e820_usable_top     dd 0

%endif