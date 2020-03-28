%macro reversed_cycle_shift 0	; gets sign in al, shift in rcx. Assigns new sign to al.
	imul rcx, -1
	call cycle_shift
	imul rcx, -1
%endmacro

%macro permute_sign 0			; gets sign in al, permutation in rdx. Assigns new sign to al.
	mov rdi, rdx
	add rdi, rax
	mov al, [rdi]
%endmacro

%macro check_sign 1				; pointer to sign is first arg, modifies: rax
	mov al, [%1]
	cmp al, '1'
	jl err_exit
	cmp al, 'Z'
	jg err_exit
%endmacro

%macro process_sign 0			; gets sign in al, assigns it to al
	mov rcx, r9					; r position in r9
	mov rdx, R
	call cycle_shift
	permute_sign
	reversed_cycle_shift

	mov rcx, r8					; l position in r8
	mov rdx, L
	call cycle_shift
	permute_sign
	reversed_cycle_shift
	
	mov rdx, T
	permute_sign
	
	mov rcx, r8
	mov rdx, revL
	call cycle_shift
	permute_sign
	reversed_cycle_shift
	
	mov rcx, r9
	mov rdx, revR
	call cycle_shift
	permute_sign
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
	revL: resb SIGNS
	revR: resb SIGNS
	T: resb SIGNS
	K: resb 2


section .text

_start:

	call reset_buffer			; check_buffer reset
	lea rcx, [rsp+16]			; adress of args[1]
	mov rsi, [rcx]				; first argument
	mov rdx, L					; destination adress
	mov rdi, SIGNS				; number of signs to read
	call read_args				; reading L
	call check_params_length	; check correctness of parameters length
	call check_RLT				; check if R, L, T permutations contain all signs
	
	call reset_buffer
	lea rcx, [rsp+24]
	mov rsi, [rcx]
	mov rdx, R
	mov rdi, SIGNS
	call read_args				;reading R
	call check_params_length
	call check_RLT
	
	call reset_buffer
	lea rcx, [rsp+32]			
	mov rsi, [rcx]
	mov rdx, T
	mov rdi, SIGNS
	call read_args				; reading T
	call check_params_length
	call check_RLT
	call check_T
	
	lea rcx, [rsp+40]
	mov rsi, [rcx]
	mov rdx, K
	mov rdi, 2
	call read_args				; reading K
	call check_params_length
	
	xor r8, r8					; start sign for L
	mov r8b, [K]
	
	xor r9, r9					; start sign for R
	mov r9b, [K+1]
	
	mov rdi, L					; reversing L permutation
	mov rsi, revL
	call reverse_permutation
	
	mov rdi, R					; reversing R permutation
	mov rsi, revR
	call reverse_permutation
	
	call process_input
	
	mov eax, SYS_EXIT
  	xor edi, edi      			; return code 0
  	syscall
	
write:		  					; buffer to write in rsi, number of bytes in edx, does not modify registers
	mov eax, SYS_WRITE
  	mov edi, STDOUT
  	syscall
	ret
	
read_args:			  			; origin buffer in rsi, destination buffer in rdx, numer of bytes in rdi, modifies: rcx, rdx, r9, r10
	xor rcx, rcx
	push rsi
loop1:
	cmp rcx, rdi	
	je exit1
	check_sign rsi				; check if parameter sign is correct
	xor r9, r9					
	mov r9b, [rsi]
	sub r9b, ASCII_ONE
	mov [rdx], r9b				; move sign to destination buffer
	add rdx, 1
	add rsi, 1
	add rcx, 1
	
	mov r10, check_buffer		; notice in check_buffer, that sign exists in argument permutation
	add r10, r9
	mov r9b, 1
	mov [r10], r9b
	
	jmp loop1
exit1:
	pop rsi
	ret
	
reverse_permutation:			; base permutation buffer in rdi, destination buffer in rsi, modifies: rcx, rdx, rsi, rdi
	xor rcx, rcx
	xor rdx, rdx	
reverse_loop:
	mov dl, [rdi]				; current sign in base permutation
	add rsi, rdx				; current position in reversed permutation
	mov [rsi], cl				; reversal
	sub rsi, rdx				
	add rcx, 1					; move to next sign
	
	cmp rcx, 42
	je exit_reverse
	
	add rdi, 1
	jmp reverse_loop	
exit_reverse:
	ret
	
reset_buffer:					; sets all signs in check_buffer as 0, modifies: rcx, rdx, rsi 
	xor rcx, rcx
	mov rsi, check_buffer
reset_loop:
	cmp rcx, SIGNS
	je reset_exit
	xor rdx, rdx
	mov [rsi], dl				; move 0 to check_buffer
	add rsi, 1					; move check_buffer pointer to the next position
	add rcx, 1
	jmp reset_loop
reset_exit:
	ret
	
check_RLT:						; checks if R, L, T contains all signs, modifies: rcx, rdx, rsi
	xor rcx, rcx
	mov rsi, check_buffer
	xor rdx, rdx
check_loop:
	cmp rcx, SIGNS
	je check_exit
	
	add dl, [rsi]				; sum all fileds in check_buffer
	add rcx, 1
	add rsi, 1
	jmp check_loop
check_exit:
	cmp rdx, SIGNS				; if all numbers exist in permutation, all fileds in check_buffer contains 1
	jne err_exit				; code 1 exit if error
	ret
	
check_T:						; checks if T contains only double-element cycles, modifies: rcx, rsi, rdi
	xor rcx, rcx
	mov rsi, T
	mov rdi, T
loop_T:
	cmp rcx, SIGNS
	je exit_T
	
	xor rdx, rdx
	mov dl, [rsi]
	cmp dl, cl					; check if it is not identity permutation in some position
	je err_exit					; code 1 exit if error
	
	add rdi, rdx
	mov dl, cl
	cmp dl, [rdi] 				; check if it is double-element cycle
	jne err_exit				; code 1 exit if error
	
	add rcx, 1
	add rsi, 1
	mov rdi, T
	jmp loop_T
exit_T:
	ret
		
check_params_length:			; adress to check in rsi, number of expected bytes in rdi, modifies rcx, rsi			
	add rsi, rdi
	mov cl, [rsi]
	cmp cl, 0
	jne err_exit
	ret
	
rotate:							; rotates mills, modifies: rdx, r8, r9
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

cycle_shift:					; gets sign in al, shift in rcx, assigns new sign to al, modifies: rax
	add al, cl					; make a cycle shift on current sign
	cmp al, 41					; check if no overflow occured
	jg decrease
	cmp al, 0
	jl increase
	ret
decrease:
	sub al, SIGNS
	ret
increase:
	add al, SIGNS
	ret

err_exit:						; code 1 exit
	mov eax, SYS_EXIT
  	mov edi, 1      			; return code 1
  	syscall
	
process_buffer:					; numer of signs to process in r11, modifies: rax, rcx, rdx, rdi, rsi, r8, r9, r10
	xor r10, r10
	mov rsi, buffer
loop4:
	cmp r10, r11
	je exit4
	
	call rotate					; rotate mills
	xor rax, rax			
	check_sign rsi				; check curent sign
	mov al, [rsi]
	sub al, ASCII_ONE			; transform ASCII code to number in [0..41]
	process_sign
	add al, ASCII_ONE			; transform number to ASCII code
	mov [rsi], al				; write sign to its place in buffer
	add rsi, 1
	add r10, 1
	jmp loop4
exit4:
	ret

process_input:					; reads whole input and processes it, modifies: rax, rcx, rdx, rdi, rsi, r8, r9, r10, r11
	mov rdi, STDIN
    lea rsi, [buffer]  			; buffer address to store read bytes
    mov rdx, PACK     			; number of bytes to read
    mov rax, SYS_READ 	
    syscall
	
	cmp rax, 0					; end if no bytes read
	je exit5
	
	mov r11, rax				; number of bytes to process
	
	call process_buffer
	
	lea rsi, [buffer]			; write processed signs
	mov rdx, r11
	call write
	jmp process_input
exit5:
	ret