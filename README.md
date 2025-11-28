[Building]

Dependencies: `make`, `nasm`, `dd` (coreutils). On Windows, the Makefile assumes a POSIX-like environment (e.g., MSYS2) for `dd`/`rm`.

```
make clean   # optional; removes bin/ and stage build dirs
make all     # builds mbr.bin, vbr.bin, loader.bin, then stitches bin/ObentOS.img
```

Artifacts end up in `bin/`:

- `mbr.bin`, `vbr.bin`, `loader.bin` – raw stage binaries.
- `ObentOS.img` – three-sector disk image with the stages laid out at LBAs 0–2.

[Running]

You can boot the raw image under QEMU (any x86 BIOS target works):

```
qemu-system-x86_64 -drive file=bin/ObentOS.img,format=raw
```

For more visibility add serial or debug options, e.g., `-serial stdio`.