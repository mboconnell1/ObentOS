%ifndef __DEFS__INC
    %define __DEFS__INC

    ; Structures
    ; --------------------------------------------------------------------------
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