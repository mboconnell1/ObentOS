%ifndef __DEFS__INC
    %define __DEFS__INC

    %include "memory_map.inc"

    ; Definitions
    ; --------------------------------------------------------------------------
    ; Get b high/low bits of a.
    %define HIGH_BITS(a,b) ((a) >> (b))
    %define LOW_BITS(a,b)  ((a) & ((1 << (b)) - 1))
    
    ; Compute the linear address of the Nth E820 entry.
    %define E820_ENTRY_ADDR(i)  (E820_MAP_MEM + ((i) * (E820_ENTRY_SIZE)))

    ; Constants
    ; --------------------------------------------------------------------------
    %define BOOT_INFO_MAGIC             0x42494E46
    %define BOOT_INFO_FLAG_E820         (1 << 0)
    %define BOOT_INFO_FLAG_E820_TR      (1 << 1)
    %define BOOT_INFO_FLAG_UMTOP   (1 << 2)
    
    %define E820_MAX_ENTRIES        128
    %define E820_TYPE_USABLE        1
    %define E820_TYPE_RESERVED      2
    %define E820_TYPE_ACPI_RECLAIM  3
    %define E820_TYPE_ACPI_NVS      4
    %define E820_TYPE_BAD_MEMORY    5
    %define E820_MASK               ~(BOOT_INFO_FLAG_E820 | BOOT_INFO_FLAG_E820_TR | BOOT_INFO_FLAG_UMTOP)
    %define E820_ENTRY_SIZE         e820_entry_t_size
    %define E820_BUFFER_SIZE        (E820_MAX_ENTRIES * E820_ENTRY_SIZE)

    ; Structures
    ; --------------------------------------------------------------------------
    struc boot_info_t
        ; Identification / versioning
        .BootSignature      : resd 1
        .Version            : resw 1
        .StructSize         : resw 1
        ; Global flags
        ; - Bit 0: E820 map present
        ; - Bit 1: E820 map truncated
        ; - Bit 2: UsableMemTop valid
        ; - Bits 31..3: reserved
        .Flags              : resd 1
        ; Boot context
        .BootDrive          : resb 1
        .Reserved1          : resb 3
        .PartitionLBAAbs    : resd 1
        ; Memory map
        .E820MapPtr         : resd 1
        .E820EntryCount     : resd 1
        .UsableMemTop       : resd 1
        ; Kernel
        .KernelPhysBase     : resd 1
        .KernelEntry        : resd 1
    endstruc

    struc bpb_t
        .BytsPerSec         : resw 1
        .SecPerClus         : resb 1
        .RsvdSecCnt         : resw 1
        .NumFATs            : resb 1
        .RootEntCnt         : resw 1
        .TotSec16           : resw 1
        .Media              : resb 1
        .FATSz16            : resw 1
        .SecPerTrk          : resw 1
        .NumHeads           : resw 1
        .HiddSec            : resd 1
        .TotSec32           : resd 1
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
    
    struc e820_entry_t
        .BaseAddrLow        : resd 1
        .BaseAddrHigh       : resd 1
        .LengthLow          : resd 1
        .LengthHigh         : resd 1
        .Type               : resd 1
        .ExtAttr            : resd 1
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

    struc gdt_t
        .NullDescriptor     : resd 2
        .CodeDescriptor     : resq 1
        .DataDescriptor     : resq 1
    endstruc

%endif