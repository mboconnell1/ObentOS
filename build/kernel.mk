# ----------------------------------------------------------------------
# Kernel build (loader, C sources, linker)
# ----------------------------------------------------------------------
KERNEL_SRC_DIR     := src/kernel
KERNEL_ARCH_DIR    := $(KERNEL_SRC_DIR)/arch/$(ARCH)
KERNEL_LD_SCRIPT   := $(KERNEL_ARCH_DIR)/linker.ld
KERNEL_BIN         := $(BOOT_BUILD_DIR)/kernel.bin
KERNEL_ELF         := $(KERNEL_BUILD_DIR)/kernel.elf
KERNEL_OBJ_DIR     := $(KERNEL_BUILD_DIR)/obj

# Discover sources automatically, but ignore legacy flat binaries
KERNEL_ASM_IGNORE  := $(KERNEL_ARCH_DIR)/legacy/kernel.asm
KERNEL_C_SRCS      := $(shell find $(KERNEL_SRC_DIR) -name '*.c' -print)
KERNEL_ASM_SRCS    := $(shell find $(KERNEL_SRC_DIR) -name '*.asm' -print)
KERNEL_ASM_SRCS    := $(filter-out $(KERNEL_ASM_IGNORE),$(KERNEL_ASM_SRCS))

KERNEL_C_OBJS      := $(patsubst $(KERNEL_SRC_DIR)/%.c,$(KERNEL_OBJ_DIR)/%.o,$(KERNEL_C_SRCS))
KERNEL_ASM_OBJS    := $(patsubst $(KERNEL_SRC_DIR)/%.asm,$(KERNEL_OBJ_DIR)/%.o,$(KERNEL_ASM_SRCS))
KERNEL_OBJS        := $(KERNEL_C_OBJS) $(KERNEL_ASM_OBJS)
KERNEL_C_DEPS      := $(KERNEL_C_OBJS:.o=.d)
KERNEL_ASM_DEPS    := $(KERNEL_ASM_OBJS:.o=.d)

.PHONY: kernel-build-dirs
kernel-build-dirs:
	mkdir -p $(KERNEL_BUILD_DIR)

$(KERNEL_OBJ_DIR)/%.o: $(KERNEL_SRC_DIR)/%.c | kernel-build-dirs
	@mkdir -p $(dir $@)
	$(CC) $(KERNEL_CFLAGS) -c -o $@ $<

$(KERNEL_OBJ_DIR)/%.o: $(KERNEL_SRC_DIR)/%.asm | kernel-build-dirs
	@mkdir -p $(dir $@)
	$(NASM) $(NASM_ELF_FLAGS) -MD $(patsubst %.o,%.d,$@) -o $@ $<

$(KERNEL_ELF): $(KERNEL_OBJS) $(KERNEL_LD_SCRIPT) | kernel-build-dirs
	@mkdir -p $(dir $@)
	$(LD) $(KERNEL_LDFLAGS) -T $(KERNEL_LD_SCRIPT) -o $@ $(KERNEL_OBJS)

$(KERNEL_BIN): $(KERNEL_ELF) | kernel-build-dirs
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@

-include $(KERNEL_C_DEPS)
-include $(KERNEL_ASM_DEPS)
