locals @@
.model small
.stack 100h

screen_w = 320
screen_h = 200
fpp = 7 ; fixed-point precision (x/128)

.data
original_video_mode db 0

vec3 struc
    x dw ?
    y dw ?
    z dw ?
ends

co vec3<0, 0, 0>         ; camera origin
cd vec3<0, 0, 1 shl fpp> ; camera direction
ro vec3<0, 0, 0>         ; ray origin
rd vec3<0, 0, 0>         ; ray direction
tmp vec3<0, 0, 0>        ; for temp calcs

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
    ;call show_pallete
    call start_app
    
    jmp exit

; calculates sqrt in fixed point format
; INPUT:  AX - fixed point number
; OUTPUT: AX - fixed point number
; Registers that get modified: AX
sqrtf proc
    push cx bx dx bx di
    ; store AX << fpp to DX:AX
    rol ax, fpp
    mov dx, ax
    and ax, not ((1 shl fpp) - 1)
    and dx, (1 shl fpp) - 1
    push ax dx
    mov cx, 1 shl fpp
    mov di, 20d
    @@l1:
        mov bx, cx
        pop dx ax ; moves are faster maby
        push ax dx
        div cx
        add cx, ax
        shr cx, 1
        cmp cx, bx
        je @@break
        dec di
        cmp di, 0
        jne @@l1
        
    @@break:
    
    mov ax, cx
    add sp, 4 ; clear ax dx
    pop di bx dx bx cx
    ret
sqrtf endp

; Multiplies fixed point with fixed point
; INPUT:  AX - fixed point number, BX - fixed point number
; OUTPUT: AX - fixed point number
; Registers that get modified: AX DX
mulf proc
    imul bx
    shr ax, fpp ; fp correction for mul
    ror dx, fpp ; fp correction for mul (shift overflow to ax)
    and dx, not ((1 shl (16 - fpp)) - 1)
    or ax, dx
    ret
mulf endp

; Divides fixed point with fixed point
; INPUT:  AX - fixed point number, BX - fixed point number
; OUTPUT: AX - fixed point number
; Registers that get modified: AX DX
divf proc
    push bx
    cmp ax, 0
    jge @@positive
    neg ax
    neg bx
    @@positive:
    ; store AX << fpp to DX:AX
    rol ax, fpp
    mov dx, ax
    and ax, not ((1 shl fpp) - 1)
    and dx, (1 shl fpp) - 1
    idiv bx
    pop bx
    ret
divf endp

start_app proc
    @@main_loop:
        ; set ES to video memory
        mov ax, 0a000h
        mov es, ax 

        xor di, di ; pixel index
        xor bx, bx ; y axis
        @@for_y:
            xor cx, cx ; x axis
            @@for_x:
                push bx cx

                ; Get ray dir ##########################################
                ; TODO: take into account cam origin and dir
                ; get rd.x
                mov ax, -(screen_h/2)
                add ax, cx
                shl ax, fpp
                mov cx, screen_h/2
                cwd
                idiv cx
                mov rd.x, ax
                ; get rd.y
                mov ax, -(screen_h/2)
                add ax, bx
                shl ax, fpp
                mov cx, screen_h/2
                cwd
                idiv cx
                mov rd.y, ax
                ; get rd.z
                ; TODO: implement
                mov rd.z, (1 shl fpp)

                ; normalize
                ; calculate length squared
                mov ax, rd.x
                mov bx, ax
                call mulf
                mov cx, ax
                mov ax, rd.y
                mov bx, ax
                call mulf
                add cx, ax
                mov ax, rd.z
                mov bx, ax
                call mulf
                add ax, cx ; store len in ax

                ; bx = sqrt(ax)
                call sqrtf
                mov bx, ax

                ; div rd by bx
                mov ax, rd.x
                call divf
                mov rd.x, ax
                mov ax, rd.y
                call divf
                mov rd.y, ax
                mov ax, rd.z
                call divf
                mov rd.z, ax                        
                ; ######################################################

                ; Intersect sphere #####################################

                ; sc(sphere center) = (0, 0, 4), r = 1         
                ; tmp = ro - sc
                mov tmp.x,  0 shl fpp
                mov tmp.y,  0 shl fpp
                mov tmp.z, -(8 shl fpp)

                ; cx = dot(tmp, tmp) - r*r
                ; TODO: add x and y into calculation, skipped for now
                mov ax, tmp.z
                mov bx, ax
                call mulf
                mov cx, ax
                sub cx, 1 shl fpp ; TODO: make radius non-const

                ; bx = dot(tmp, rd)
                ; TODO: add x and y into calculation, skipped for now
                mov ax, tmp.z
                mov bx, rd.z
                call mulf
                mov bx, ax

                ; ax = bx*bx-cx
                call mulf
                sub ax, cx
                ; if ax >= 0, ray hit sphere
                mov dl, 0
                cmp ax, 0
                jl @@no_hit
                mov dl, 11100000b
                @@no_hit:
                ; ######################################################

                pop cx bx
                ; set color
                mov byte ptr es:[di], dl
                inc di
                ; loop back
                inc cx
                cmp cx, screen_w
                je @@skip_for_x
                jmp @@for_x
                @@skip_for_x:

            ; loop back
            inc bx
            cmp bx, screen_h
            je @@skip_for_y
            jmp @@for_y
            @@skip_for_y:

        ; check if key is pressed    
        mov ah, 01h
        int 16h
        jnz @@key_pressed
        jmp @@main_loop
        @@key_pressed:
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