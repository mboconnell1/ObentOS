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

stage2_filename         db 'STAGE2  BIN' ; 8.3 name, padded with spaces

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
;           The buffer then holds: FAT[base] and FAT[base+1].
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

        ; Bounds check: base and base+1 must both be within this FAT
        ; FATSz16 is the number of sectors per fat
        mov     ax, [g_BPB_FATSz16]
        cmp     bx, ax              ; base >= FATSz16?
        jae     .range_error

        mov     dx, bx
        inc     dx
        cmp     dx, ax
        jae     .range_error        ; base+1 >= FATSz16?

        ; Mark window as invalid while I/O is in progress
        mov     word [g_FAT_WindowBaseSector], 0FFFFh

        ; Read first FAT sector: LBA = g_FirstFATSector + base
        xor     eax, eax
        mov     ax, [g_FirstFATSector]
        add     ax, bx

        ;mov     ax, seg g_FAT_WindowBuffer
        mov     ax, 0
        mov     es, ax
        mov     di, g_FAT_WindowBuffer

        call    volume_read_sector
        jc      .io_error

        ; Read second FAT sector: LBA+1
        inc     eax

        mov     ax, [g_BPB_BytesPerSec]
        mov     di, g_FAT_WindowBuffer
        add     di, ax

        call    volume_read_sector
        jc      .io_error

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

        ;mov     ax, seg g_FAT_WindowBuffer
        mov     ax, 0
        mov     es, ax

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
; Function: fat12_find_stage2_in_root
;
; Purpose:  Scan the FAT12 root directory for the file STAGE2.BIN (8.3 name
;           stored in stage2_filename) and, if found, record its first cluster
;           and file size.
;
; Inputs:   DL      = BIOS drive (not used directly, kept for interface symmetry)
;           FS      = BOOT_INFO segment
;           DS      = data segment containing globals and stage2_filename
;
; Outputs:  CF      = 0 on success
;                         g_Stage2FirstCluster set to file's first cluster
;                         g_Stage2FileSize     set to file size in bytes
;                     1 on failure
;                         (file not found or disk I/O error)
;
; Preserves: BX, CX, DX, SI, DI, ES
; Clobbers:  AX, FLAGS
; ------------------------------------------------------------------------------
fat12_find_stage2_in_root:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es

        ; Prepare loop counters
        ;   CX = remaining root directory sectors
        ;   BX = current sector offset from g_FirstRootDirSector
        ;   DX = directory entries per sector = BytesPerSec / 32
        mov     ax, [g_RootDirSectors]
        test    ax, ax
        jz      .not_found          ; no root sectors

        mov     cx, ax              ; CX = sectors remaining
        xor     bx, bx              ; BX = sector index (0..CX-1)

        mov     ax, [g_BPB_BytesPerSec]
        xor     dx, dx
        mov     si, DIR_ENTRY_SIZE
        div     si                  ; AX = entries per sector
        mov     si, ax              ; DX = entries per sector (constant)
.next_sector:
        cmp     cx, 0
        je      .not_found          ; scanned all root sectors

        ; Read this root directory sector into g_ROOT_Buffer
        ;   EAX = volume-relative LBA = g_FirstRootDirSector + BX
        ;   ES:DI = g_ROOT_Buffer
        xor     eax, eax
        mov     ax, [g_FirstRootDirSector]
        add     ax, bx              ; AX = sector LBA within volume

        mov     di, g_ROOT_Buffer
        ;mov     ax, seg g_ROOT_Buffer
        xor     ax, ax
        mov     es, ax
        
                ; preserve sector loop counters across the call
        push    cx
        push    bx

        mov     eax, [g_FirstRootDirSector]
        add     ax, bx                    ; AX = sector index in volume
        xor     eax, eax                  ; zero high word
        mov     ax, [g_FirstRootDirSector]
        add     ax, bx

        call    volume_read_sector
        pop     bx
        pop     cx
        jc      .io_error           ; CF=1 -> propagate

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
        je      .not_found          ; end-of-directory marker
        cmp     al, 0E5h
        je      .next_entry;        ; deleted, skip

        ; Compare 11-byte 8.3 name
        push    di                  ; save entry base offset
        mov     si, stage2_filename
        mov     cx, DIR_NAME_LEN
.next_compare_loop:
        mov     al, [es:di]
        mov     ah, [si]
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
        jnz     .next_entry_no_pop  ; treat as mismatch

        ; Extract first cluster (WORD at offset 26) and file size (DWORD at
        ; offset 28)
        mov     ax, [es:di + DIR_FIRST_CLUSTER_OFFSET]
        mov     [g_Stage2FirstCluster], ax

        mov     ax, [es:di + DIR_FILE_SIZE_OFFSET]
        mov     [g_Stage2FileSize], ax
        mov     ax, [es:di + DIR_FILE_SIZE_OFFSET + 2]
        mov     [g_Stage2FileSize + 2], ax

        clc
        jmp     .done
.name_mismatch:
        pop     di
.next_entry_no_pop:
.next_entry:
        add     di, DIR_ENTRY_SIZE  ; advance to next directory entry
        dec     ax                  ; decrement entries remaining in sector
        jnz     .entry_loop

        ; Move to next root directory sector
        inc     bx                  ; next sector index
        dec     cx                  ; one fewer sector remaining
        jmp     .next_sector
.io_error:
        ; CF already set by callee
        jmp     .done
.not_found:
        stc
.done:
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; ------------------------------------------------------------------------------
; Function: fat12_load_stage2
;
; Purpose:  Follow the FAT12 cluster chain for STAGE2.BIN starting at
;           g_Stage2FirstCluster and load the file into memory at 0x1000:0000.
;
;           This routine relies on the metadata gathered by
;           fat12_find_stage2_in_root. It reads sectors cluster-by-cluster
;           until either:
;               - g_Stage2BytesRemaining reaches 0, or
;               - the FAT12 chain ends (EOC marker 0xFF8..0xFFF).
;
; Inputs:   FS      = BOOT_INFO segment
;           DS      = data segment containing globals
;
; Requires: fat12_find_stage2_in_root has returned successfully so that:
;               g_Stage2FirstCluster != 0 and
;               g_Stage2FileSize     > 0
;
; Outputs:  CF      = 0 on success
;                         STAGE2 loaded at 0x1000:0000
;                         g_Stage2BytesRemaining = 0
;                         g_Stage2BytesLoaded    = g_Stage2FileSize
;                     1 on failure (invalid metadata, FAT error, or I/O error)
;
; Preserves: BX, CX, DX, SI, DI, ES
; Clobbers:  AX, EAX, ECX, EDX, FLAGS
;
; Notes:     - This routine does not transfer control to STAGE2; the caller
;             is responsible for performing a far/near jump to 0x1000:0000.
;           - The implementation assumes STAGE2.BIN fits entirely within the
;             64 KiB segment that begins at 0x1000. No special handling is
;             provided for segment wrap-around.
; ------------------------------------------------------------------------------
fat12_load_stage2:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es

        ; Sanity check first cluster and file size
        mov     ax, [g_Stage2FirstCluster]
        cmp     ax, 2
        jb      .no_stage2              ; clusters 0,1 are reserved

        mov     eax, [g_Stage2FileSize]
        test    eax, eax
        jz      .no_stage2              ; file size must be non-zero

        ; Initialise accounting and load destination
        mov     [g_Stage2BytesRemaining], eax   ; bytesRemaining = fileSize

        xor     edx, edx
        mov     [g_Stage2BytesLoaded], edx      ; bytesLoaded = 0

        ; ES:DI = stage two load address
        mov     ax, STAGE_2_SEG
        mov     es, ax
        mov     di, STAGE_2_OFF

        ; Load BPB-derived constants
        ;   SI = sectors per cluster (SecPerClus)
        ;   BP = bytes per sector (BytesPerSec)
        mov     al, [g_BPB_SecPerClus]
        mov     ah, 0
        mov     si, ax                  ; SI = SecPerClus

        mov     bp, [g_BPB_BytesPerSec] ; BP = BytesPerSec

        mov     bx, [g_Stage2FirstCluster]      ; BX = current cluster
.cluster_loop:
        ; Compute starting LBA for this cluster
        ;   dataClusterIndex = cluster - 2
        ;   firstSectorLBA   = g_FirstDataSector + dataClusterIndex * SecPerClus
        mov     ax, bx
        sub     ax, 2
        xor     dx, dx
        mul     si                      ; DX:AX = dataClusterIndex * SecPerClus

        add     ax, [g_FirstDataSector] ; AX = firstSectorLBA
        mov     cx, ax                  ; CX = firstSectorLBA
        mov     dx, si                  ; DX = remainingSectors
.sector_loop:
        ; File already loaded?
        mov     eax, [g_Stage2BytesRemaining]
        test    eax, eax
        jz      .done_success

        cmp     dx, 0
        je      .after_cluster          ; no more sectors in cluster

        xor     eax, eax
        mov     ax, cx                  ; EAX = volume-relative LBA for this sector

        call    volume_read_sector
        jc      .io_error               ; propagate error

        ; Advance destination pointer by BytesPerSec
        mov     ax, bp
        add     di, ax

        ; Update bytesRemaining and bytesLoaded
        ;   bytesThisSector = min(BytesPerSec, BytesRemaining)
        mov     eax, [g_Stage2BytesRemaining]
        xor     ecx, ecx
        mov     cx, bp                  ; ECX = BytesPerSec
        cmp     eax, ecx
        jae     .use_full_sector
        mov     ecx, eax
.use_full_sector:
        sub     eax, ecx
        mov     [g_Stage2BytesRemaining], eax

        mov     edx, [g_Stage2BytesLoaded]
        add     edx, ecx
        mov     [g_Stage2BytesLoaded], edx

        ; Advance to next sector within this cluster
        inc     cx                      ; next LBA
        dec     dx                      ; one fewer sector remaining
        jmp     .sector_loop
.after_cluster:
        mov     ax, bx                  ; AX = current cluster
        call    fat12_next_cluster
        jc      .fat_error              ; I/O or bad cluster

        ; AX = next cluster in chain, or EOC (0xFF8..0xFFF)
        cmp     ax, 0x0FF8
        jae     .done_success           ; end-of-chain marker

        mov     bx, ax                  ; BX = next cluster
        jmp     .cluster_loop
.no_stage2:
        stc
        jmp     .done
.io_error:
.fat_error:
        jmp     .done
.done_success:
        clc
.done:
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

%endif