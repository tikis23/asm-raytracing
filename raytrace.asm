locals @@
.model small
.stack 100h

screen_w = 320
screen_h = 200

.data
original_video_mode db 0

.code
include logger.asm
start:
    mov ax, @data
    mov ds, ax
    LOG_INIT

    ; save current video mode
    mov ah, 0fh
    int 10h
    mov byte ptr [original_video_mode], al
    
    ; set video mode to graphics
    ; mov ax, 4f02h
    ; mov bx, 101h ; SVGA 640x480 256col
    ; int 10h
    mov ax, 0013h ; VGA 320x200 256col
    int 10h

    ; check if mode is supported
    cmp ah, 0h
    jne exit

    call start_app
    
    jmp exit

start_app proc
    xor dx, dx
    @@main_loop:
        ; set ES to video memory
        mov ax, 0a000h
        mov es, ax 

        xor bx, bx ; pixel index
        xor ax, ax ; y axis
        @@for_y:
            xor cx, cx ; x axis
            @@for_x:
                mov byte ptr es:[bx], dl
                inc bx

                ; loop back
                inc cx
                cmp cx, screen_h
                jne @@for_x

            ; loop back
            inc ax
            cmp ax, screen_w
            jne @@for_y

        inc dl

        ; check if 'q' is pressed    
        mov ah, 01h
        int 16h
        jz @@main_loop
        ; if 'q' pressed, exit
        cmp ah, 10h
        je @@break_main

        jmp @@main_loop ; while (true)
    @@break_main:

    ret
start_app endp

exit:
    LOG_DEINIT
    ; restore video mode
    mov ah, 00h
    mov al, [original_video_mode]
    int 10h

    ; exit to dos
    mov ax, 4c00h
    int 21h

end start