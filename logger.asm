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
LOG_NUM_DEC macro num
    push ax

    PUSHSTATE
    IDEAL
    t1 instr <num>,<H>
    t2 instr <num>,<h>
    t3 instr <num>,<L>
    t4 instr <num>,<l>
    POPSTATE
    IF ((.TYPE num) EQ 30h) AND (t1 OR t2 OR t3 OR t4)
        xor ah, ah
        mov al, num
        call logger_write_num_dec_to_file
    ELSE
        mov ax, num
        call logger_write_num_dec_to_file
    ENDIF

    pop ax
endm

logger_write_num_dec_to_file proc
    push ax bx cx dx bp

    mov bp, sp
    mov cx, 10d

    mov bx, 1
    dec bp
    mov byte ptr ss:[bp], 10d ; newline
    @@l1:
        xor dx, dx
        div cx
        add dl, '0'
        dec bp
        mov byte ptr ss:[bp], dl
        inc bx
        cmp ax, 0d
        jne @@l1

    mov cx, bx ; buffer size
    mov bx, [logger_file_handle] ; file handle
    mov dx, bp ; buffer
    xchg sp, bp
    LOGGER_INTERNAL_SEG_PUSH ss
    mov ah, 40h
    int 21h
    LOGGER_INTERNAL_SEG_POP
    xchg sp, bp

    pop bp dx cx bx ax
    ret
logger_write_num_dec_to_file endp