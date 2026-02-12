%ifndef __KERNEL_HEADER_INC
%define __KERNEL_HEADER_INC

%define KERNEL_HEADER_MAGIC 0x4F42454E ; 'OBEN'

struc kernel_header_t
    .Magic  : resd 1
    .Entry  : resd 1
endstruc

%endif ; __KERNEL_HEADER_INC
