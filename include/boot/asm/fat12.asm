[bits 16]

%ifndef __FAT12_ASM
%define __FAT12_ASM

; ------------------------------------------------------------------------------
; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
; Expects g_BPB_* symbols from volume.asm to be available

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------
FAT_WINDOW_BYTES_PER_SEC_MAX    equ 512
ROOT_BYTES_PER_SEC_MAX          equ 512

DIR_ENTRY_SIZE              equ 32
DIR_NAME_LEN                equ 11
DIR_ATTR_OFFSET             equ 11
DIR_FIRST_CLUSTER_OFFSET    equ 26
DIR_FILE_SIZE_OFFSET        equ 28

DIR_ATTR_VOLUME             equ 08h
DIR_ATTR_DIRECTORY          equ 10h


; ------------------------------------------------------------------------------
; Globals
; ------------------------------------------------------------------------------
g_FAT_WindowBaseSector  dw 0FFFFh
g_FAT_WindowBuffer      times 2*FAT_WINDOW_BYTES_PER_SEC_MAX db 0
g_ROOT_Buffer           times ROOT_BYTES_PER_SEC_MAX db 0

g_Stage2FirstCluster    dw 0
g_Stage2FileSize        dd 0
g_Stage2BytesRemaining  dd 0
g_Stage2BytesLoaded     dd 0

; ------------------------------------------------------------------------------
; Helpers
; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------
; Function: fat12_load_fat_window
;
; Purpose:  Ensure that a 2-sector window containing the requested FAT sector
;           is loaded and cached.
;
;           The window always starts on an even FAT-relative sector index:
;               base = requestedSector & ~1
;           Normally the buffer holds: FAT[base] and FAT[base+1].
;           For an odd-length FAT, if base is the last sector (base = FATSz16-1),
;           only that last sector is loaded (no second sector exists).
;
; Inputs:   AX      = FAT-relative sector index (within one FAT)
;           FS      = BOOT_INFO segment
;           (Uses g_FirstFATSector, g_BPB_FATSz16, g_BPB_BytesPerSec)
;
; Outputs:  CF      = 0 on success
;                     1 on error (out-of-range or I/O error)
;           g_FAT_WindowBuffer      updated
;           g_FAT_WindowBaseSector  updated to base, or 0FFFFh on error
;
; Assumes:  g_FAT_WindowBuffer is in segment 0000h and ES can be set to 0.
;
; Preserves: BX, CX, DX, ES, DI
; Clobbers:  AX, EAX, FLAGS
; ------------------------------------------------------------------------------
fat12_load_fat_window:
        push    bx
        push    cx
        push    dx
        push    di
        push    es

        ; BX = requested sector
        mov     bx, ax

        ; BX = even base sector = requested sector & ~1
        and     bx, 0FFFEh

        ; Check if this window is already cached
        mov     ax, [g_FAT_WindowBaseSector]
        cmp     ax, bx
        je      .cached

        ; Bounds check: base must be within this FAT
        ; FATSz16 is the number of sectors per FAT
        mov     ax, [g_BPB_FATSz16]
        cmp     bx, ax              ; base >= FATSz16?
        jae     .range_error

        ; DX = base + 1 (used to decide if a second sector exists)
        mov     dx, bx
        inc     dx

        ; Mark window as invalid while I/O is in progress
        mov     word [g_FAT_WindowBaseSector], 0FFFFh

        ; Read first FAT sector: LBA = g_FirstFATSector + base
        xor     eax, eax
        mov     ax, [g_FirstFATSector]
        add     ax, bx              ; EAX = base LBA

        push    ax
        push    ds
        pop     es
        mov     di, g_FAT_WindowBuffer
        pop     ax
        call    volume_read_sector
        jc      .io_error

        ; Decide whether a second FAT sector (base+1) exists
        mov     ax, [g_BPB_FATSz16]
        cmp     dx, ax              ; base+1 >= FATSz16?
        jae     .no_second_sector   ; if so, skip reading a second sector

        ; Read second FAT sector at base+1 into the second half of the buffer
        inc     eax                 ; EAX = base+1 LBA

        push    ax
        push    ds
        pop     es
        mov     di, g_FAT_WindowBuffer
        add     di, [g_BPB_BytesPerSec]
        pop     ax
        call    volume_read_sector
        jc      .io_error

.no_second_sector:
        ; On success, update cache base
        mov     [g_FAT_WindowBaseSector], bx
        clc
        jmp     .done

.cached:
        clc
        jmp     .done

.range_error:
.io_error:
        mov     word [g_FAT_WindowBaseSector], 0FFFFh
        stc

.done:
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        ret



; ------------------------------------------------------------------------------
; Function: fat12_read_word_from_fat
;
; Purpose:  Read a 16-bit little-endian word from the FAT, given a byte offset
;           from the start of the FAT. The byte offset is the standard
;           FAT12 formula: offset = n + n/2 = floor(3*n/2).
;
; Inputs:   AX      = byte offset into this FAT (0 .. FATSz16*BytesPerSec-1)
;           FS      = BOOT_INFO segment
;
; Outputs:  AX      = 16-bit word fetched from FAT
;           CF      = 0 on success
;                     1 on error (out-of-range / I/O)
;
; Preserves: BX, CX, DX, ES, DI
; Clobbers:  AX, FLAGS
; ------------------------------------------------------------------------------
fat12_read_word_from_fat:
        push    bx
        push    cx
        push    dx
        push    di
        push    es

        ; BX = byte offset into FAT
        mov     bx, ax

        ; Divide offset by BytesPerSec:
        ;   sectorIndex  = offset / BytesPerSec
        ;   sectorOffset = offset % BytesPerSec
        mov     ax, bx
        xor     dx, dx
        mov     cx, [g_BPB_BytesPerSec]
        div     cx                  ; AX = sectorIndex, DX = sectorOffset

        ; sectorIndex must be within the FAT
        cmp     ax, [g_BPB_FATSz16]
        jae     .range_error

        ; Save for later
        mov     bx, ax              ; BX = sectorIndex
        mov     cx, dx              ; CX = sectorOffset

        ; Ensure the 2-sector window covers sectorIndex
        mov     ax, bx
        call    fat12_load_fat_window
        jc      .error              ; CF=1 -> propagate

        ; Compute offset into g_FAT_WindowBuffer
        ;   windowBase = g_FAT_WindowBaseSector (even)
        ;   relSector  = sectorIndex - windowBase (0 or 1)
        ;   windowOff  = relSector * BytesPerSec + sectorOffset
        mov     ax, [g_FAT_WindowBaseSector]
        cmp     ax, 0xFFFF
        je      .range_error

        sub     bx, ax              ; BX = relSector

        mov     ax, [g_BPB_BytesPerSec]
        mul     bx                  ; DX:AX = BytesPerSec * relSector
                                    ; (result is 0 or BytesPerSec)
        
        add     ax, cx              ; add sectorOffset
        adc     dx, 0               ; should remain within buffer

        ; ES:DI -> start of window buffer
        mov     di, g_FAT_WindowBuffer
        add     di, ax

        push    ds
        pop     es

        ; Read 16-bit little-endian word from window
        mov     ax, [es:di]

        clc
        jmp     .done
.range_error:
        stc
        jmp     .done
.error:
        ; CF already set by callee
.done:
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        ret

; ------------------------------------------------------------------------------
; Function: fat12_next_cluster
;
; Purpose:  Given a FAT12 cluster number, read its FAT entry and return the
;           next cluster value.
;
; Inputs:   AX      = current cluster number (2 .. maxCluster)
;           FS      = BOOT_INFO segment
;
; Outputs:  AX      = next cluster number
;                     (0xFF8..0xFFF  => end-of-chain)
;           CF      = 0 on success
;                     1 on error (I/O, out-of-range, bad cluster)
;
; Preserves: BX, CX, DX, DI, ES
; Clobbers:  AX, FLAGS
; ------------------------------------------------------------------------------
fat12_next_cluster:
        push    bx
        push    cx
        push    dx
        push    di
        push    es

        mov     cx, ax              ; CX = current cluster

        ; Sanity check; clusters 0,1 are reserved in FAT12
        cmp     ax, 2
        jb      .bad_cluster

        ; Compute byte offset into FAT for this cluster
        ;   offset = n + n/2 = floor(3*n/2)
        mov     bx, ax              ; BX = n
        shr     ax, 1               ; AX = n/2
        add     bx, ax              ; BX = n + (n/2) = offset

        mov     ax, bx              ; AX = offset
        call    fat12_read_word_from_fat
        jc      .error              ; CF=1 -> propagate

        ; AX now holds the 16-bit word that contains the 12-bit FAT12 entry
        ; Select the correct 12 bits based on whether the cluster is even/odd
        test    cx, 1
        jz      .even_cluster       ; even = low 12 bits

        ; Odd cluster: high 12 bits
        shr     ax, 4
.even_cluster:
        and     ax, 0x0FFF          ; mask to 12 bits

        ; Interpret special values
        ;   0x000..0x001    reserved (should not appear)
        ;   0xFF0..0xFF6    reserved
        ;   0xFF7           bad cluster
        ;   0xFF8..0xFFF    end-of-chain
        cmp     ax, 0xFF7
        je      .bad_cluster

        ; Success; AX holds next cluster
        clc
        jmp     .done
.bad_cluster:
        stc
        jmp     .done
.error:
        ; CF already set by callee
.done:
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        ret

; ------------------------------------------------------------------------------
; Function: fat12_find_root_file
;
; Purpose:  Scan the FAT12 root directory for a specific 8.3 filename and,
;           if found, return its first cluster and file size.
;
; Inputs:   DS:SI -> 11-byte 8.3 filename (upper-case, space-padded)
;           FS    = BOOT_INFO segment (for volume_read_sector)
;
; Uses:     g_RootDirSectors, g_FirstRootDirSector, g_BPB_BytesPerSec,
;           g_ROOT_Buffer, DIR_* constants.
;
; Outputs:  CF = 0 on success
;               BX  = first cluster (u16)
;               EAX = file size in bytes (u32)
;           CF = 1 on failure (not found or I/O error)
;
; Clobbers: AX, BX, CX, DX, SI, DI, EAX
; Preserves: ES, BP, DS
; ------------------------------------------------------------------------------

fat12_find_root_file:
        ; Preserve only what we promise to preserve (ES, BP, others for safety).
        ; AX and BX are *not* preserved because they are outputs.
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    es

        ; Save filename pointer so we can reset SI for each compare
        mov     bp, si                  ; BP = filename offset in DS

        ; Prepare loop counters:
        ;   CX = remaining root directory sectors
        ;   BX = current sector index (0..CX-1)
        ;   SI = directory entries per sector = BytesPerSec / DIR_ENTRY_SIZE
        mov     ax, [g_RootDirSectors]
        test    ax, ax
        jz      .not_found              ; no root sectors

        mov     cx, ax                  ; CX = sectors remaining
        xor     bx, bx                  ; BX = sector index (0..CX-1)

        mov     ax, [g_BPB_BytesPerSec]
        xor     dx, dx
        mov     si, DIR_ENTRY_SIZE
        div     si                      ; AX = entries per sector
        mov     si, ax                  ; SI = entries per sector (constant)

.next_sector:
        cmp     cx, 0
        je      .not_found              ; scanned all root sectors

        ; Read this root directory sector into g_ROOT_Buffer
        ;   EAX = volume-relative LBA = g_FirstRootDirSector + BX
        ;   ES:DI = g_ROOT_Buffer
        xor     eax, eax
        mov     ax, [g_FirstRootDirSector]
        add     ax, bx                  ; AX = sector LBA within volume

        mov     di, g_ROOT_Buffer
        push    ds
        pop     es

        ; preserve sector loop counters across the call
        push    cx
        push    bx

        xor     eax, eax
        mov     ax, [g_FirstRootDirSector]
        add     ax, bx

        call    volume_read_sector
        pop     bx
        pop     cx
        jc      .io_error               ; CF=1 -> propagate

        ; Scan entries in this sector
        ;   AX = remaining entries in this sector
        ;   DI = current entry offset within g_ROOT_Buffer
        mov     ax, si
        mov     di, g_ROOT_Buffer

.entry_loop:
        ; Check first byte of name
        ;   0x00 => no more entries in entire root directory
        ;   0xE5 => deleted entry
        mov     al, [es:di]
        cmp     al, 0
        je      .not_found              ; end-of-directory marker
        cmp     al, 0E5h
        je      .next_entry             ; deleted, skip

        ; Compare 11-byte 8.3 name against DS:BP
        push    di                      ; save entry base offset
        mov     si, bp                  ; reset filename pointer
        mov     cx, DIR_NAME_LEN
.next_compare_loop:
        mov     al, [es:di]
        mov     ah, [ds:si]
        cmp     al, ah
        jne     .name_mismatch
        inc     di
        inc     si
        loop    .next_compare_loop

        ; Name matched; restore DI to entry base
        pop     di

        ; Attribute check; require regular file
        mov     al, [es:di + DIR_ATTR_OFFSET]
        test    al, DIR_ATTR_VOLUME | DIR_ATTR_DIRECTORY
        jnz     .next_entry_no_pop      ; treat as mismatch

        ; Extract first cluster (WORD at offset 26) into BX
        mov     bx, [es:di + DIR_FIRST_CLUSTER_OFFSET]

        ; Extract file size (DWORD at offset 28) into EAX
        mov     dx, [es:di + DIR_FILE_SIZE_OFFSET + 2]    ; high word
        mov     ax, [es:di + DIR_FILE_SIZE_OFFSET]        ; low word
        push    dx
        push    ax
        pop     eax                     ; EAX = file size (DX:AX)

        clc
        jmp     .done

.name_mismatch:
        pop     di                      ; restore DI when name mismatched

.next_entry_no_pop:
.next_entry:
        add     di, DIR_ENTRY_SIZE      ; advance to next directory entry
        dec     ax                      ; decrement entries remaining in sector
        jnz     .entry_loop

        ; Move to next root directory sector
        inc     bx                      ; next sector index
        dec     cx                      ; one fewer sector remaining
        jmp     .next_sector

.io_error:
        ; CF already set by callee
        jmp     .done

.not_found:
        stc

.done:
        pop     es
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        ret



; ------------------------------------------------------------------------------
; Function: fat12_load_file_chain
;
; Purpose:  Given a starting cluster and total file size, load the file's
;           cluster chain into memory.
;
; Inputs:   AX    = first cluster number (>= 2)
;           ESI   = total size in bytes
;           ES:DI = destination address
;           FS    = BOOT_INFO / volume segment (for volume_read_sector)
;           DS    = FAT12 globals / volume layout (g_FirstDataSector, etc.)
;
; Outputs:  CF = 0 on success
;               file fully loaded at ES:DI_start
;           CF = 1 on failure (bad cluster, I/O error, size=0)
;
; Notes:    - Assumes the cluster chain is long enough for size_bytes.
;           - Does not handle segment wrap; caller must ensure destination
;             segment is large enough.
;           - Clobbers 32-bit regs (EAX, EBX, ECX, EDX, ESI, EDI).
; ------------------------------------------------------------------------------

fat12_load_file_chain:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    es

        mov     bx, ax          ; BX = current cluster

        test    esi, esi
        jz      .no_data             ; zero-length file => treat as error

        ; Load BPB-derived constants:
        ;   BP = bytes per sector (BytesPerSec)
        mov     bp, [g_BPB_BytesPerSec] ; BP = BytesPerSec

.cluster_loop:
        ; Sanity check cluster number; clusters 0,1 are reserved
        cmp     bx, 2
        jb      .bad_cluster

        ; Compute starting LBA for this cluster:
        ;   dataClusterIndex = cluster - 2
        ;   firstSectorLBA   = g_FirstDataSector + dataClusterIndex * SecPerClus
        movzx   cx, byte [g_BPB_SecPerClus]
        mov     ax, bx
        sub     ax, 2
        mul     cx                      ; DX:AX = dataClusterIndex * SecPerClus
        add     ax, [g_FirstDataSector] ; AX = firstSectorLBA
        mov     cx, ax                  ; CX = current sector LBA
        movzx   dx, byte [g_BPB_SecPerClus]    ; DX = remaining sectors in this cluster

.sector_loop:
        ; Have we loaded all requested bytes?
        mov     eax, esi                ; EAX = bytesRemaining
        test    eax, eax
        jz      .success                ; nothing left to load

        ; Any sectors left in this cluster?
        cmp     dx, 0
        je      .after_cluster          ; move to next cluster

        ; Read this sector:
        ;   EAX = volume-relative LBA (from CX)
        xor     eax, eax
        mov     ax, cx                  ; EAX = sector LBA
        push    cx
        call    volume_read_sector
        pop     cx
        jc      .io_error               ; propagate error

        ; Advance destination pointer by BytesPerSec
        mov     ax, bp
        add     di, ax
        jnc     .no_wrap

        ; DI wrapped -> bump ES by BytesPerSec/16 paragraphs
        ; For 512 bytes/sec, that's 32 paragraphs = 0x20
        mov     ax, bp
        shr     ax, 4

        push    bx
        mov     bx, es
        add     bx, ax
        mov     es, bx
        pop     bx

.no_wrap:
        ; bytesThisSector = min(BytesPerSec, bytesRemaining)
        ; (We mirror the original pattern: use ECX with low 16 bits = BytesPerSec)
        mov     eax, esi                ; EAX = bytesRemaining
        push    cx
        xor     ecx, ecx
        mov     cx, bp                  ; ECX = BytesPerSec
        cmp     eax, ecx
        jae     .use_full_sector
        mov     ecx, eax                ; bytesThisSector = bytesRemaining
.use_full_sector:
        sub     esi, ecx                ; bytesRemaining -= bytesThisSector

        ; Advance to next sector within this cluster
        pop     cx
        inc     cx                      ; next LBA
        dec     dx                      ; one fewer sector remaining
        jmp     .sector_loop

.after_cluster:
        ; Move to next cluster in FAT chain
        mov     ax, bx                  ; AX = current cluster
        call    fat12_next_cluster
        jc      .fat_error              ; I/O or bad cluster in FAT

        ; AX = next cluster or EOC (0xFF8..0xFFF)
        cmp     ax, 0x0FF8
        jb      .not_eoc

        ; EOC reached — only success if we've loaded everything
        test    esi, esi
        jz      .success

        ; Otherwise: truncated chain => hard error
        mov ah, 0x0E
        mov al, '!'
        int 0x10
        jmp $
        stc
        jmp     .done

.not_eoc:
        mov     bx, ax
        jmp     .cluster_loop

.no_data:
        stc
        jmp     .done

.bad_cluster:
        stc
        jmp     .done

.io_error:
.fat_error:
        ; CF already set by callee or by us
        jmp     .done

.success:
        clc

.done:
        pop     es
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret


; ------------------------------------------------------------------------------
; Function: fat12_load_root_file
;
; Purpose:  Convenience helper: find a file by 8.3 name in the FAT12 root
;           directory and load its entire contents into memory.
;
; Inputs:   DS:SI -> 11-byte 8.3 filename (upper-case, space-padded)
;           ES:DI -> destination address where file will be loaded
;           FS    = BOOT_INFO / volume segment
;
; Outputs:  CF = 0 on success
;               file loaded at ES:DI
;               EAX = file size in bytes (32-bit)
;           CF = 1 on failure (file not found or I/O/FAT error)
;               EAX undefined
;
; Notes:    - This is a thin wrapper around fat12_find_root_file +
;             fat12_load_file_chain.
;           - fat12_load_file_chain is allowed to clobber 32-bit regs; this
;             wrapper preserves caller-visible 16-bit regs except AX, and
;             restores EAX to the file size on success.
; ------------------------------------------------------------------------------

fat12_load_root_file:
        ; Save 16-bit registers we promise to preserve (except AX) and ES.
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    es

        ; DS:SI points to the filename. Call fat12_find_root_file:
        ;  On success: CF=0, AX = first_cluster, EAX = size_bytes.
        call    fat12_find_root_file
        jc      .error_find             ; propagate failure

        ; At this point:
        ;   AX  = first cluster
        ;   EAX = file size (32-bit)
        ;
        ; We want to:
        ;   1) Call fat12_load_file_chain(AX=cluster, EAX=size, ES:DI=dest)
        ;   2) Preserve EAX = size for the caller on success.
        ;
        ; Save size on the stack.
        push    eax

        ; AX already holds first_cluster, EAX holds size_bytes.
        ; ES:DI already holds destination from caller.
        call    fat12_load_file_chain
        jc      .error_load             ; loading failed; CF set by callee

        ; On success, restore EAX to file size.
        pop     eax                     ; EAX = saved size_bytes
        clc
        jmp     .done

.error_load:
        ; Loading failed; discard saved size and propagate CF=1.
        add     sp, 4                   ; drop saved EAX (32 bits)
        stc
        jmp     .done

.error_find:
        ; fat12_find_root_file already set CF=1; nothing extra to clean.

.done:
        pop     es
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret


%endif
