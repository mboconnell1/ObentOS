%ifndef __MEMORY_MAP_INC
%define __MEMORY_MAP_INC
    
    ; Helpers
    ; --------------------------------------------------------------------------
    ; Convert seg:off pair (two 16-bit constants) to a linear address.
    %define LIN(seg, off) (((seg) << 4) + (off))

    ; Define a segmented memory location as both SEG/OFF and linear addresses.
    ; Example: SEG_MEM_LOC BOOT_INFO, 0x0000, 0x7EEE
    %macro SEG_MEM_LOC 3
        %define %1_SEG %2
        %define %1_OFF %3
        %define %1_MEM LIN(%2, %3)
    %endmacro

    ; Define a linear address split into SEG:OFF.
    ; Example: SEG_MEM_LOC E820_MAP, 0x90000 -> 9000:0000
    %macro SEG_MEM_LOC_LIN 2
        %define %1_MEM %2
        %define %1_SEG ((%2) >> 4)
        %define %1_OFF ((%2) & 0xF)
    %endmacro

    ; Creates region declarations START/END/SIZE in linear space.
    ; Example: REGION VBR, 0x7C00, 0x200
    %macro REGION 3
        %define %1_START %2
        %define %1_END   ((%2) + (%3))
        %define %1_SIZE  (%3)
    %endmacro

    ; Check region A does not overlap region B.
    %macro ASSERT_NO_OVERLAP 2
        %if ((%1_START) < (%2_END)) && ((%2_START) < (%1_END))
            %error "Memory map overlap: " %+ %1 %+ " overlaps " %+ %2
        %endif
    %endmacro

    ; Check region lies completely below 1 MiB.
    %macro ASSERT_BELOW_1M 1
        %if (%1_END) > 0x100000
            %error "Region exceeds 1 MiB: " %+ %1
        %endif
    %endmacro

    ; BIOS-reserved regions
    ; --------------------------------------------------------------------------
    REGION IVT_RGN, 0x00000, 0x00400
    REGION BDA_RGN, 0x00400, 0x00100

    ; Fixed locations
    ; --------------------------------------------------------------------------
    SEG_MEM_LOC MBR, 0x0000, 0x0600
    REGION MBR_RGN, MBR_MEM, 0x0200

    SEG_MEM_LOC BOOTSECT, 0x0000, 0x7C00
    REGION BOOTSECT_RGN, BOOTSECT_MEM, 0x0200

    SEG_MEM_LOC STAGE1, 0x0000, 0x8000
    REGION STAGE1_RGN, STAGE1_MEM, 0x8000

    SEG_MEM_LOC STAGE2, 0x1000, 0x0000
    REGION STAGE2_CODE_RGN, STAGE2_MEM, 0xC000

    SEG_MEM_LOC STAGE2_STACK_TOP, STAGE2_SEG, 0xFFFC
    REGION STAGE2_STACK_RGN, (STAGE2_MEM + 0xC000), 0x4000

    SEG_MEM_LOC_LIN KERNEL, 0x00100000
    REGION KERNEL_RGN, KERNEL_MEM, 0x00800000

    SEG_MEM_LOC BOOT_INFO, 0x0000, 0x7E00
    REGION BOOT_INFO_RGN, BOOT_INFO_MEM, 0x0100

    SEG_MEM_LOC_LIN E820_MAP, 0x90000
    REGION E820_MAP_RGN, E820_MAP_MEM, 0x1000

    SEG_MEM_LOC DAP, 0x0000, 0x0900
    REGION DAP_RGN, DAP_MEM, 0x0100

    ; Reusable low RAM band
    ; --------------------------------------------------------------------------
    SEG_MEM_LOC RM_SCRATCH, 0x0000, 0x5000
    REGION RM_SCRATCH_RGN, RM_SCRATCH_MEM, 0x0C00

    SEG_MEM_LOC RM_STACK_TOP, 0x0000, 0x7C00
    REGION RM_STACK_RGN, (RM_STACK_TOP_MEM - 0x2000), 0x2000

    %define MBR_STACK_TOP_SEG  RM_STACK_TOP_SEG
    %define MBR_STACK_TOP_OFF  RM_STACK_TOP_OFF

    %define VBR_STACK_TOP_SEG  RM_STACK_TOP_SEG
    %define VBR_STACK_TOP_OFF  RM_STACK_TOP_OFF

    %define STAGE1_STACK_TOP_SEG RM_STACK_TOP_SEG
    %define STAGE1_STACK_TOP_OFF RM_STACK_TOP_OFF


    ; Overlap assertions
    ; --------------------------------------------------------------------------
    ; Nothing may overlap BIOS reserved
    ASSERT_NO_OVERLAP MBR_RGN, IVT_RGN
    ASSERT_NO_OVERLAP MBR_RGN, BDA_RGN
    ASSERT_NO_OVERLAP BOOTSECT_RGN,  IVT_RGN
    ASSERT_NO_OVERLAP BOOTSECT_RGN,  BDA_RGN
    ASSERT_NO_OVERLAP BOOT_INFO_RGN, IVT_RGN
    ASSERT_NO_OVERLAP BOOT_INFO_RGN, BDA_RGN
    ASSERT_NO_OVERLAP RM_SCRATCH_RGN,IVT_RGN
    ASSERT_NO_OVERLAP RM_SCRATCH_RGN,BDA_RGN
    ASSERT_NO_OVERLAP RM_STACK_RGN,  IVT_RGN
    ASSERT_NO_OVERLAP RM_STACK_RGN,  BDA_RGN

    ; Fixed regions must not overlap each other
    ASSERT_NO_OVERLAP MBR_RGN, BOOTSECT_RGN
    ASSERT_NO_OVERLAP MBR_RGN, BOOT_INFO_RGN
    ASSERT_NO_OVERLAP BOOTSECT_RGN,  BOOT_INFO_RGN

    ASSERT_NO_OVERLAP STAGE1_RGN,    BOOT_INFO_RGN
    ASSERT_NO_OVERLAP STAGE1_RGN,    BOOTSECT_RGN
    ASSERT_NO_OVERLAP STAGE1_RGN,    MBR_RGN

    ASSERT_NO_OVERLAP STAGE2_CODE_RGN, STAGE2_STACK_RGN
    ASSERT_NO_OVERLAP STAGE2_CODE_RGN, STAGE1_RGN
    ASSERT_NO_OVERLAP STAGE2_STACK_RGN,STAGE1_RGN

    ASSERT_NO_OVERLAP E820_MAP_RGN,  STAGE1_RGN
    ASSERT_NO_OVERLAP E820_MAP_RGN,  STAGE2_CODE_RGN
    ASSERT_NO_OVERLAP E820_MAP_RGN,  STAGE2_STACK_RGN
    ASSERT_BELOW_1M   E820_MAP_RGN

    ; Low RAM band must not overlap fixed regions that are live at the same time
    ASSERT_NO_OVERLAP RM_SCRATCH_RGN, MBR_RGN
    ASSERT_NO_OVERLAP RM_SCRATCH_RGN, BOOT_INFO_RGN
    ASSERT_NO_OVERLAP RM_SCRATCH_RGN, BOOTSECT_RGN
    ASSERT_NO_OVERLAP RM_SCRATCH_RGN, STAGE1_RGN

    ASSERT_NO_OVERLAP RM_STACK_RGN,   MBR_RGN
    ASSERT_NO_OVERLAP RM_STACK_RGN,   BOOT_INFO_RGN
    ASSERT_NO_OVERLAP RM_STACK_RGN,   STAGE1_RGN
%endif