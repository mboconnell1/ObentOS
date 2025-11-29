%ifndef __DEFS__INC
    %define __DEFS__INC

    ; Definitions
    ; --------------------------------------------------------------------------
    ; Get b high/low bits of a.
    %define HIGH_BITS(a,b) ((a) >> (b))
    %define LOW_BITS(a,b)  ((a) & ((1 << (b)) - 1))

    ; Macros
    ; --------------------------------------------------------------------------
    ; Creates constants for a segmented memory address.
    ; %1    - Label             (name of memory location)
    ; %2    - 32-bit address    ([16-bit segment]_[16-bit offset])
    %macro SEG_MEM_LOC 2
        %1_SEG  EQU HIGH_BITS(%2,16)
        %1_OFF  EQU LOW_BITS(%2,16)
        %1_MEM  EQU (%1_SEG << 4) + %1_OFF
    %endmacro

    ; Creates constant for a non-segmented memory address.
    ; %1    - Label             (name of memory location)
    ; %2    - 32-bit address
    %macro MEM_LOC 2
        %1_MEM  EQU %2
    %endmacro

    ; Fixed memory locations
    ; --------------------------------------------------------------------------
    ; Segmented memory locations      |SEG:OFF|
        SEG_MEM_LOC     BOOT_INFO,  0x0000_7E00

    ; Structures
    ; ---------------------------------------s-----------------------------------
    struc boot_info_t
        .Signature          : resw 1    ; 'BI'
        .Version            : resb 1    ; structure version
        .Flags              : resb 1    ; bitfield

        .BootDrive          : resb 1    ; BIOS drive number (DL)
        .Reserved0          : resb 1    ; reserved / alignment

        .PartitionLBAAbs    : resd 1    ; absolute LBA of partition start

        .LoaderRelLBA       : resd 1    ; LBA relative to partition start
        .LoaderSectors      : resw 1    ; loader size in sectors
        .LoaderSegment      : resw 1    ; segment where loader is loaded
        .LoaderOffset       : resw 1    ; offset where loader is loaded

        .ReservedFlags      : resw 1    ; reserved / alignment
        .ReservedArea       : resb 32   ; room for future fields
    endstruc

    struc daps_t
        .PacketSize         : resb 1
        .Reserved           : resb 1
        .SectorsToTransfer  : resw 1
        .BufferAddrOffset   : resw 1
        .BufferAddrSegment  : resw 1
        .LBAAddrLow         : resw 2
        .LBAAddrHigh        : resw 2
    endstruc
    
    struc mbr_t
        .Bootstrap          : resb 440
        .DiskUID            : resw 2
        .Reserved           : resw 1
        .PartitionEntry1    : resb partition_table_entry_t_size
        .PartitionEntry2    : resb partition_table_entry_t_size
        .PartitionEntry3    : resb partition_table_entry_t_size
        .PartitionEntry4    : resb partition_table_entry_t_size
        .BootSignature      : resw 1
    endstruc

    struc partition_table_entry_t
        .Attributes         : resb 1
        .CHSStartAddress    : resb 3
        .PartitionType      : resb 1
        .CHSEndAddress      : resb 3
        .LBAStartAddress    : resw 2
        .SectorCount        : resw 2
    endstruc

%endif