; setup

LOG_INIT macro
    push ax cx dx
    
    jmp logger_skip_internal
    logger_file_name db "log.log", 0
    logger_file_handle dw 0000h
    logger_skip_internal:

    xor cx, cx
    mov ah, 3Ch ; create file
    lea dx, logger_file_name
    LOGGER_INTERNAL_SEG_PUSH cs
    int 21h
    LOGGER_INTERNAL_SEG_POP
    mov [logger_file_handle], ax

    pop dx cx ax
endm
LOG_DEINIT macro
    push ax bx

    mov ax, 3e00h
    mov bx, [logger_file_handle]
    LOGGER_INTERNAL_SEG_PUSH cs
    int 21h
    LOGGER_INTERNAL_SEG_POP

    pop bx ax
endm
LOGGER_INTERNAL_SEG_PUSH macro seg
    push ds
    push seg
    pop ds
endm
LOGGER_INTERNAL_SEG_POP macro
    pop ds
endm

; log functions
LOG_STR macro string_chars
    LOCAL strin, strskip
    push ax cx bx dx
    jmp strskip
    strin db string_chars, 0dh, 0ah
    strskip:

    strlen SIZESTR <string_chars>
    mov cx, strlen ; buffer size
    LOGGER_INTERNAL_SEG_PUSH cs
    mov bx, [logger_file_handle] ; file handle
    lea dx, strin ; buffer
    mov ah, 40h
    int 21h
    LOGGER_INTERNAL_SEG_POP
    pop dx bx cx ax
endm
LOG_NUM_DEC macro num, signed
    LOCAL positive
    push ax bx cx dx bp di
    PUSHSTATE
    IDEAL
    t1 instr <num>,<H>
    t2 instr <num>,<h>
    t3 instr <num>,<L>
    t4 instr <num>,<l>
    POPSTATE
    IF ((.TYPE num) EQ 30h) AND (t1 OR t2 OR t3 OR t4) ;; byte
        xor ah, ah
        mov al, num
        IF signed
            cbw
        ENDIF
    ELSE ;; word
        mov ax, num
    ENDIF
    xor di, di
    IF signed
        cmp ax, 0
        jge positive
        neg ax
        inc di
        positive:
    ENDIF
    call logger_write_num_dec_to_file

    pop di bp dx cx bx ax
endm

; logs number in AX, DI = 0 unsigned, DI = 1 signed
logger_write_num_dec_to_file proc

    mov bp, sp
    mov cx, 10d

    dec bp
    mov byte ptr ss:[bp], 0ah ; newline
    dec bp
    mov byte ptr ss:[bp], 0dh ; carriage
    mov bx, 2
    @@l1:
        xor dx, dx
        div cx
        add dl, '0'
        dec bp
        mov byte ptr ss:[bp], dl
        inc bx
        cmp ax, 0d
        jne @@l1

    cmp di, 1
    jne @@unsigned ; if signed push minus
        mov dl, '-'
        dec bp
        mov byte ptr ss:[bp], dl
        inc bx
    @@unsigned:

    mov cx, bx ; buffer size
    mov bx, [logger_file_handle] ; file handle
    mov dx, bp ; buffer
    xchg sp, bp
    LOGGER_INTERNAL_SEG_PUSH ss
    mov ah, 40h
    int 21h
    LOGGER_INTERNAL_SEG_POP
    xchg sp, bp

    ret
logger_write_num_dec_to_file endp