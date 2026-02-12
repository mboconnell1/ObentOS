# ----------------------------------------------------------------------
# Boot build (MBR, stages, VBR)
# ----------------------------------------------------------------------
BOOT_SRC_DIR        := src/boot

MBR_SRC             := $(BOOT_SRC_DIR)/mbr/mbr.asm
VBR_SRC             := $(BOOT_SRC_DIR)/vbr/vbr.asm
STAGE1_SRC          := $(BOOT_SRC_DIR)/stage1/stage_1.asm
STAGE2_SRC          := $(BOOT_SRC_DIR)/stage2/stage_2.asm

MBR_BIN        := $(BOOT_BUILD_DIR)/mbr.bin
VBR_BIN        := $(BOOT_BUILD_DIR)/vbr.bin
BPB_BIN        := $(BOOT_BUILD_DIR)/bpb.bin
STAGE1_BIN     := $(BOOT_BUILD_DIR)/stage_1.bin
STAGE2_BIN     := $(BOOT_BUILD_DIR)/stage_2.bin

BOOT_TARGETS   := $(MBR_BIN) $(VBR_BIN) $(STAGE1_BIN) $(STAGE2_BIN)

.PHONY: boot-build-dirs
boot-build-dirs:
	mkdir -p $(BOOT_BUILD_DIR)

$(MBR_BIN): $(MBR_SRC) | boot-build-dirs
	$(NASM) $(NASM_BIN_FLAGS) -MD $(MBR_BIN:.bin=.d) -o $@ $<

$(STAGE1_BIN): $(STAGE1_SRC) | boot-build-dirs
	$(NASM) $(NASM_BIN_FLAGS) -MD $(STAGE1_BIN:.bin=.d) -o $@ $<

$(BOOT_LAYOUT_INC): $(STAGE1_BIN)
	$(GEN_BOOT_LAYOUT) $< > $@

$(VBR_BIN): $(VBR_SRC) $(BOOT_LAYOUT_INC) $(BPB_BIN) | boot-build-dirs
	$(NASM) $(NASM_BIN_FLAGS) -I $(BOOT_BUILD_DIR) -MD $(VBR_BIN:.bin=.d) -o $@ $<

$(STAGE2_BIN): $(STAGE2_SRC) | boot-build-dirs
	$(NASM) $(NASM_BIN_FLAGS) -MD $(STAGE2_BIN:.bin=.d) -o $@ $<

BOOT_DEP_FILES := $(MBR_BIN:.bin=.d) $(STAGE1_BIN:.bin=.d) $(STAGE2_BIN:.bin=.d) $(VBR_BIN:.bin=.d)

-include $(BOOT_DEP_FILES)
