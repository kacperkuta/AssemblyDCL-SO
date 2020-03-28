%macro reversed_cycle_shift 0			; gets sign in al, shift in rcx. Assigns new sign to al.
	imul rcx, -1
	call cycle_shift
	imul rcx, -1
%endmacro

%macro permute_sign 0					; gets sign in al, permutation in rdx. Assigns new sign to al.
	sub al, ASCII_ONE
	mov rdi, rdx
	add rdi, rax
	mov al, [rdi]
%endmacro

%macro check_sign 1						; pointer to sign is first arg
	mov al, [%1]
	cmp al, '1'
	jl err_exit
	cmp al, 'Z'
	jg err_exit
%endmacro

%macro process_sign 0				; gets sign in al, assigns it to al
	mov rcx, r9
	mov rdx, R
	call cycle_shift
	permute_sign
	reversed_cycle_shift

	mov rcx, r8
	mov rdx, L
	call cycle_shift
	permute_sign
	reversed_cycle_shift
	
	mov rdx, T
	permute_sign
	
	mov rcx, r8
	mov rdx, L
	call cycle_shift
	call reversed_permute_sign
	reversed_cycle_shift
	
	mov rcx, r9
	mov rdx, R
	call cycle_shift
	call reversed_permute_sign
	reversed_cycle_shift
%endmacro

SYS_READ  equ 0
SYS_WRITE equ 1
SYS_EXIT  equ 60
STDOUT    equ 1
STDIN	  equ 0
PACK	  equ 8000
SIGNS 	  equ 42
ASCII_ONE equ 49

global _start

section .bss
	buffer: resb PACK
	check_buffer: resb SIGNS
	L: resb SIGNS
	R: resb SIGNS
	T: resb SIGNS
	K: resb 2


section .text

_start:

	call reset_buffer			; check_buffer reset
	lea rcx, [rsp+16]			;adress of args[1]
	mov rsi, [rcx]				;first argument
	mov rdx, L					;destination adress
	mov rdi, SIGNS				;number of signs to read
	call read_args				;reading L
	call check_RLT
	lea rcx, [rsp+16]			;adress of args[1]
	mov rdi, [rcx]				;first argument
	mov rsi, SIGNS
	call check_params_length
	
	call reset_buffer			; check_buffer reset
	lea rcx, [rsp+24]
	mov rsi, [rcx]
	mov rdx, R
	mov rdi, SIGNS
	call read_args				;reading R
	call check_RLT
	lea rcx, [rsp+24]			
	mov rdi, [rcx]	
	mov rsi, SIGNS
	call check_params_length
	
	call reset_buffer			; check_buffer reset
	lea rcx, [rsp+32]			
	mov rsi, [rcx]
	mov rdx, T
	mov rdi, SIGNS
	call read_args				; reading T
	call check_RLT
	call check_T
	lea rcx, [rsp+32]			
	mov rdi, [rcx]				
	mov rsi, SIGNS
	call check_params_length
	
	lea rcx, [rsp+40]
	mov rsi, [rcx]
	mov rdx, K
	mov rdi, 2
	call read_args				; reading K
	lea rcx, [rsp+40]			
	mov rdi, [rcx]				
	mov rsi, 2
	call check_params_length
	
	xor r8, r8					; start sign for L
	mov r8b, [K]
	sub r8b, ASCII_ONE
	
	xor r9, r9					; start sign for R
	mov r9b, [K + 1]
	sub r9b, ASCII_ONE
	
	call process_input
	
	mov eax, SYS_EXIT
  	xor edi, edi      			; return code 0
  	syscall
	
write:		  					; calling function buffer adress stored in rsi, number of bytes to write in edx
	mov eax, SYS_WRITE
  	mov edi, STDOUT
  	syscall
	ret
	
read_args:			  			; origin buffer in rsi, destination buffer in rdx, numer of bytes in rdi
	mov rcx, 0
loop1:
	cmp rcx, rdi	
	je exit1
	check_sign rsi				; check if parameter sign is correct
	mov r9, 0					
	mov r9b, [rsi]
	mov [rdx], r9b				; move sign to destination buffer
	add rdx, 1
	add rsi, 1
	add rcx, 1
	
	mov r10, check_buffer		; notice in check_buffer, that sign exists in argument permutation
	add r10, r9
	sub r10, ASCII_ONE
	mov r9b, 1
	mov [r10], r9b
	
	jmp loop1
exit1:
	ret
	
reset_buffer:					; sets all signs in check_buffer as 0
	mov rcx, 0
	mov rsi, check_buffer
reset_loop:
	cmp rcx, SIGNS
	je reset_exit
	mov dl, 0
	mov [rsi], dl
	add rsi, 1
	add rcx, 1
	jmp reset_loop
reset_exit:
	ret
	
check_RLT:						; checks if R, L, T contains all signs
	mov rcx, 0
	mov rsi, check_buffer
	mov rdx, 0
check_loop:
	cmp rcx, SIGNS
	je check_exit
	add dl, [rsi]
	add rcx, 1
	add rsi, 1
	jmp check_loop
check_exit:
	cmp rdx, 42
	jne err_exit
	ret
	
check_T:						; checks if T contains only double-element cycles
	mov rcx, 0
	mov rsi, T
	mov rdi, T
loop_T:
	cmp rcx, SIGNS
	je exit_T
	mov rdx, 0
	mov dl, [rsi]
	sub dl, ASCII_ONE
	cmp dl, cl					; check if it is not identity permutation in some position
	je err_exit
	add rdi, rdx
	mov dl, cl
	add dl, ASCII_ONE
	cmp dl, [rdi] 				; check if it is double-element cycle
	jne err_exit
	add rcx, 1
	add rsi, 1
	mov rdi, T
	jmp loop_T
exit_T:
	ret
		
check_params_length:			; adress to check in rdi, number of expected bytes in rsi			
	add rdi, rsi
	mov cl, [rdi]
	cmp cl, 0
	jne err_exit
	ret
	
rotate:
	add r9, 1					; rotate L
	cmp r9, 42					; check if it's in zero position
	je overflowR
	
	mov rdx, r9
	add dl, ASCII_ONE			; find actual sign on R
	
	cmp dl, 'R'					; check if it is not one of 'R', 'L', 'T'
	je addL						; if it is rotate L
	cmp dl, 'L'
	je addL
	cmp dl, 'T'
	je addL
	ret
overflowR:
	xor r9, r9
	ret
overflowL:
	xor r8, r8
	ret
addL:
	add r8, 1
	cmp r8, 42
	je overflowL
	ret
	
reversed_permute_sign:			; gets sign in al, permutation in rdx. Assigns new sign to al.
	push r10
	mov rdi, rdx
	mov r10, 0
loop3:
	cmp al, [rdi]
	je exit3
	add rdi, 1
	add r10, 1
	jmp loop3
exit3:
	add r10b, ASCII_ONE
	mov al, r10b
	pop r10
	ret

cycle_shift:					; gets sign in al, shift in rcx. Assigns new sign to al.
	sub al, ASCII_ONE
	add al, cl
	cmp al, 41
	jg decrease
	cmp al, 0
	jl increase
	add al, ASCII_ONE
	ret
decrease:
	sub al, 42
	add al, ASCII_ONE
	ret
increase:
	add al, 42
	add al, ASCII_ONE
	ret

err_exit:
	mov eax, SYS_EXIT
  	mov edi, 1      			; return code 1
  	syscall
	
process_buffer:					; numer of signs to process in r11
	mov r10, 0
	mov rsi, buffer
loop4:
	cmp r10, r11
	je exit4
	call rotate
	mov rax, 0
	check_sign rsi
	mov al, [rsi]
	process_sign
	mov byte[rsi], al
	add rsi, 1
	add r10, 1
	jmp loop4
exit4:
	ret

process_input:
	mov rdi, STDIN	  			; file descriptor
    lea rsi, [buffer]  			; stack address to store the bytes read
    mov rdx, PACK     			; number of bytes to read
    mov rax, SYS_READ 			; SYSCALL number for reading from STDIN
    syscall           			; make the syscall
	
	cmp rax, 0
	je exit5
	
	mov r11, rax
	
	call process_buffer
	
	lea rsi, [buffer]
	mov rdx, r11
	call write
	jmp process_input
exit5:
	ret
	
	
	
	
	
	