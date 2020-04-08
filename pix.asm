extern pixtime

%macro mod128 3                 ; (%1, %2) mod %3. Result in rsi. No params in rax, rdx!!!
    mov     rdx, %1
    mov     rax, %2
    div     %3
    mov     rax, rdx
%endmacro

%macro divf 2                   ; counts {%1/%2}, modifies rdx, rdi, result in rax. No params in rdx!!!
    mov     rdx, %1
    mov     rdi, %2
    mov     rax, 0
    div     rdi
%endmacro

%macro sub_128 4                ; number1: more significant in 1st arg, less significant in 2nd arg, number2: more significant in 3rd arg, less significant 4th arg
    sub     %2, %4
    sbb     %1, %3
%endmacro

%macro bsr1_128 2               ; more significant bytes in 1st arg, less significant bytes in 2nd arg
    shrd    %2, %1, 1
    shr     %1, 1
%endmacro

%macro bsl1_128 2               ; more significant bytes in 1st arg, less significant bytes in 2nd arg
    shld    %1, %2, 1
    shl     %2, 1
%endmacro

global pix

section .text
pix:                            ; global pix function calculating pi digits. Modifies: rax, rcx, r8, r9, r10, r11
    push    rsi                 ; pushing all arguments
    push    rdx
    push    r14
    push    r15
    push    rdi
    mov     r14, rdx
    mov     r15, rsi

    rdtsc         
    mov     rdi, rax
    call    pixtime
pix_loop:
    mov     rax, 1
    lock\
    xadd    qword[r15], rax     ; find my index to fill in

    cmp     rax, r14            ; end if *pidx > max
    jae     pix_exit

    lea     r11, [rax*8]        ; r11 = *pidx         
    push    rax                 ; push *pidx

    call    count_digits
    shr     rax, 32             ; skip redundant bytes
    
    pop     r11                 ; r11 = *pidx
    pop     rdi
    mov\
    dword[rdi + 4*r11], eax     ; add my result
    push    rdi

    jmp     pix_loop
pix_exit:
    rdtsc               
    mov     rdi, rax
    call    pixtime

    pop     rdi                 ; pop all args
    pop     r15
    pop     r14
    pop     rdx
    pop     rsi
    ret

power:                          ; counts 16^rsi mod r8, result in rax, modifies: rdi, rdx
    cmp     rsi, 0              ; check edge case of recursion
    je      power_0
    
    push    rsi
    shr     rsi, 1              ; recursively count 16^(rsi/2) mod r8
    call    power
    
    mul     rax                 ; count 16^(rsi/2*2)
    mov     rdi, rdx
    mov     rsi, rax
    mod128  rdi, rsi, r8        ; count 16^(rsi/2*2) mod r8

    pop     rsi                 ; check if it was odd power
    bt      rsi, 0
    jc      odd_power
    ret
odd_power:                      ; count count 16^(rsi/2*2)*16 mod r8
    xor     rdx, rdx
    shld    rdx, rax, 4         ; rax *= 4, overflow in rdx
    shl     rax, 4

    push    rsi
    mov     rsi, rax
    mod128  rdi, rsi, r8        ; (rdx, rax) mod r8
    
    pop     rsi
    ret
power_0:
    mov     rax, 1
    ret

Sj:                             ; First loop from BBP. j in r10, n in r11, result in rax, modifies: rcx, rdx, rdi, rsi, r8, r9
    xor     rcx, rcx
    xor     rax, rax
    xor     r9, r9              ; result kept in r9
SLoop1:
    mov     rsi, r11            ; rsi is current power
    sub     rsi, rcx
    lea     r8, [rcx*8 + r10]   ; r8 is modulo

    call    power               ; count 16^rsi mod r8  
    divf    rax, r8             ; count {rax/r8}

    add     r9, rax             ; add result to total result

    cmp     rcx, r11            ; exit cond check
    je      Sj2
    add     rcx, 1
    jmp     SLoop1

Sj2:                            ; second loop of BBP
    mov     rcx, 1 
    mov     rsi, 1              ; 16^0
SLoop2:
    add     rcx, r11
    lea     r8, [rcx*8 + r10]   ; 8k+j in r8
    
    sub     rcx, r11
    shl     rsi, 4              ; current 16 power: rsi *= 16
    mov     rax, rsi
    mul     r8                  ; calculate 16^(k-n)*(8k+j)

    cmp     rdx, 0              ; check if 16^(k-n)*(8k+j) <= 2^64. If not - end.
    jne     SLoop2_exit

    divf    1, rax              ; calculate 1/16^(k-n)*(8k+j)   
    add     r9, rax             ; add result to total result

    add     rcx, 1
    jmp     SLoop2
SLoop2_exit:
    mov     rax, r9             ; result in rax
    ret

count_digits:                   ; n in r11, result in rax (more significant 32 bits)
    push    r12

    mov     r10, 1              ; count {S1}
    call    Sj
    
    mov     r12, rax
    shl     r12, 2              ; count {4*S1}

    mov     r10, 4              ; count {S4}
    call    Sj
    shl     rax, 1              ; count {2*S4}

    sub     r12, rax            ; count {4*S1 - 2*S4} 

    add     r10, 1              ; count {S5}
    call    Sj

    sub     r12, rax            ; count {4*S1 - 2*S4 - S5} 

    add     r10, 1              ; count {S6}
    call    Sj

    sub     r12, rax            ; count {4*S1 - 2*S4 - S5 - S6} 
    mov     rax, r12            ; result in rax

    pop     r12
    ret
