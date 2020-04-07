extern pixtime

%macro sub_128 4          ; number1: more significant in 1st arg, less significant in 2nd arg, number2: more significant in 3rd arg, less significant 4th arg
    sub %2, %4
    sbb %1, %3
%endmacro

%macro bsr1_128 2           ; more significant bytes in 1st arg, less siginificant bytes in 2nd arg
    shrd %2, %1, 1
    shr %1, 1
%endmacro

%macro bsl1_128 2           ; more significant bytes in 1st arg, less siginificant bytes in 2nd arg
    shld %1, %2, 1
    shl %2, 1
%endmacro

SYS_WRITE equ 1
SYS_EXIT  equ 60
STDOUT    equ 1

section .bss
    bufor resb 5
section .data
    one  db "1", `\n`
    zero  db "0", `\n`
    new_line db `\n`


global pix

global print_bytes

section .text
pix:
    push rsi
    push rdx
    push r14
    push r15
    push rdi
    mov r14, rdx
    mov r15, rsi
    rdtsc
    mov rdi, rax
    call pixtime
pix_loop:
    mov rax, 1
    lock xadd qword[r15], rax 

    cmp rax, r14
    jae pix_exit

    mov r11, rax
    shl r11, 3

    call count_digits
    shr rax, 32
    ;mov rdi, rax
    ;call print_bytes

    pop rdi
    mov dword[rdi + 4*r11], eax
    push rdi

    jmp pix_loop
pix_exit:
    rdtsc
    mov rdi, rax
    call pixtime
    pop rdi
    pop r15
    pop r14
    pop rdx
    pop rsi

    ret

sys_exit:
    mov eax, SYS_EXIT
    xor edi, edi
    syscall

print_bytes:           ; in rdi
    push rcx
    push rsi
    push rax
    push rdx
    push r8
    push r11
    xor rcx, rcx
print_loop:
    cmp rcx, 64
    je exit
    add rcx, 1
    mov r8, 64
    sub r8, rcx
    bt rdi, r8
    jc print_one
    bt rdi, r8
    jnc print_zero
print_one:
    push rcx
    push rdi
    mov rax, SYS_WRITE
    mov rsi, one
    mov rdi, 1
    mov rdx, STDOUT
    syscall
    pop rdi
    pop rcx
    jmp print_loop
print_zero:
    push rcx
    push rdi
    mov rax, SYS_WRITE
    mov rsi, zero
    mov rdi, 1
    mov rdx, STDOUT
    syscall
    pop rdi
    pop rcx
    jmp print_loop
exit:
    push rcx
    push rdi
    mov rax, SYS_WRITE
    mov rsi, new_line
    mov rdi, 1
    mov rdx, STDOUT
    syscall
    pop rdi
    pop rcx
    pop r11
    pop r8
    pop rdx
    pop rax
    pop rsi
    pop rcx
    ret




frac_div:             ; divided in rdi, divisor in rsi, result in rax, modifies: rdi, rsi, rdx
    push rcx
    xor rdx, rdx
    mov rax, rdi
    div rsi

    mov rdi, rdx      ; remainder stored in rdi, divisor in rsi
    mov rcx, 63
    xor rax, rax
frac_div_loop:
    shl rdi, 1
    cmp rdi, rsi
    jae set_byte
frac_div_loop2:
    sub rcx, 1
    jz frac_div_exit
    jmp frac_div_loop
set_byte:
    bts rax, rcx
    sub rdi, rsi
    jmp frac_div_loop2
frac_div_exit:
    pop rcx
    ret


power:              ; base is 16, power in rsi, modulo in r8, result in rax, modifies: rdi, rdx, rax
    cmp rsi, 0
    je power_0
    
    push rsi
    shr rsi, 1
    call power
    
    mul rax
    mov rdi, rdx
    mov rsi, rax
    call mod_128
    mov rax, rsi

    pop rsi
    bt rsi, 0
    jc odd_power
    ret
odd_power:
    xor rdi, rdi
    mov rdi, 16
    mul rdi
    mov rdi, rdx
    push rsi
    mov rsi, rax
    call mod_128
    mov rax, rsi
    pop rsi
    ret
power_0:
    mov rax, 1
    ret


mod_128:            ; rdi, rsi - number, r8 - modulo, result in rsi
    push r15
    mov r15, r8      ; X in rax, r15
    xor rax, rax       
loop1_check:
    cmp rax, rdi
    ja loop1_exit
    jb loop1
    cmp r15, rsi
    ja loop1_exit
    jna loop1
loop1:
    bsl1_128 rax, r15
    jmp loop1_check
loop1_exit:
    bsr1_128 rax, r15
loop2_check:
    cmp rdi, 0
    jne loop2
    cmp rsi, r8
    jae loop2
    jmp loop2_exit
loop2:
    cmp rdi, rax
    ja sub_X
    jb loop2_cont
    cmp rsi, r15
    jae sub_X
    jmp loop2_cont
sub_X:
    sub_128 rdi, rsi, rax, r15
loop2_cont:
    bsr1_128 rax, r15
    jmp loop2_check
loop2_exit:
    pop r15
    ret

no_modulo_power:              ; base is 16, power in rsi, result in rax, modifies: rdi, rdx, rax
    cmp rsi, 0
    je power_0

    push rsi
    shr rsi, 1
    call no_modulo_power
    mul rax
    pop rsi
    bt rsi, 0
    jc odd_power2
    ret
odd_power2:
    imul rax, 16
    ret


Sj:                 ; j in r10, n in r11, result in rax, modifies: rcx, rdx, rdi, rsi, r8, r9
    xor rcx, rcx
    xor rax, rax
    xor r9, r9      ; result kept in r9
SLoop1:
    mov rsi, r11    ; rsi is current power
    sub rsi, rcx
    mov r8, rcx      ; r8 is modulo
    shl r8, 3
    add r8, r10

    call power 
    mov rdi, rax

    mov rsi, r8
    call frac_div
    add r9, rax     ; add result to total result

    cmp rcx, r11
    je  Sj2
    add rcx, 1
    jmp SLoop1
Sj2:
    mov rcx, 1 
SLoop2:
    add rcx, r11
    mov r8, rcx     ; 8k+j in r8
    shl r8, 3
    add r8, r10
    sub rcx, r11
    mov rsi, rcx            ; current 16 power
    call no_modulo_power    ; calculate 16^(k-n)
    mul r8                  ; calculate 16^(k-n)*(8k+j)

    cmp rdx, 0              ; check if 16^(k-n)*(8k+j) <= 2^64. If not - end.
    jne SLoop2_exit

    mov rsi, rax        
    mov rdi, 1
    call frac_div           ; calculate 1/16^(k-n)*(8k+j)   

    add r9, rax             ; add result to total result

    add rcx, 1
    jmp SLoop2
SLoop2_exit:
    mov rax, r9
    ret



count_digits:               ; n in r11, result in rax (more significant 32 bits)
    push r12

    mov r10, 1
    call Sj
    
    mov r12, rax
    shl r12, 2

    mov r10, 4
    call Sj
    shl rax, 1

    sub r12, rax

    mov r10, 5
    call Sj

    sub r12, rax

    mov r10, 6
    call Sj

    sub r12, rax
    mov rax, r12

    pop r12
    ret
