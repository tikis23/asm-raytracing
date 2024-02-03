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
    mov ax, 0013h ; VGA 320x200 256col
    int 10h

    ; check if mode is supported
    cmp ah, 0h
    je @@skip_mode_check_exit
    jmp exit
    @@skip_mode_check_exit:

    call set_pallete
    call show_pallete
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

                ; set color
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

        ; check if key is pressed    
        mov ah, 01h
        int 16h
        jz @@main_loop
        mov ah, 0h
        int 16h
        ; if 'q' pressed, exit
        cmp ah, 10h
        je @@break_main

        jmp @@main_loop ; while (true)
    @@break_main:

    ret
start_app endp

set_pallete proc
    ; 3 red 3 green 2 blue

    mov dx, 03c8h ; set pallete index
    mov al, 0     ; automatically increments
    out dx, al
    mov dx, 03c9h ; start writing colors

    xor bx, bx ; index
    @@l1:
        ; red
        mov al, bl
        and al, 11100000b
        shr al, 2
        out dx, al
        ; green
        mov al, bl
        and al, 00011100b
        shl al, 1
        out dx, al
        ; blue
        mov al, bl
        and al, 00000011b
        shl al, 4
        out dx, al
    
        inc bx
        cmp bx, 255d
        jbe @@l1

    ret
set_pallete endp

show_pallete proc
    @@main_loop:
        ; set ES to video memory
        mov ax, 0a000h
        mov es, ax 

        mov bx, screen_w * (screen_h/6) + (screen_w/3) ; pixel index
        xor ax, ax ; y axis
        @@for_y:
            ; get y axis coord
            mov dh, al
            shr dh, 3
            shl dh, 4

            xor cx, cx ; x axis
            @@for_x:
                ; get x axis coord
                mov dl, cl
                shr dl, 3
                add dl, dh

                ; set color
                mov byte ptr es:[bx], dl
                inc bx

                ; loop back
                inc cx
                cmp cx, 16d*8d
                jb @@for_x

            add bx, screen_w - (16d*8d)
            ; loop back
            inc ax
            cmp ax, 16d*8d
            jb @@for_y

        ; check if key is pressed    
        mov ah, 01h
        int 16h
        jz @@main_loop
        mov ah, 0h
        int 16h
        ; if 'q' pressed, exit
        cmp ah, 10h
        je @@break_main

        jmp @@main_loop ; while (true)
    @@break_main:
    ret
show_pallete endp

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