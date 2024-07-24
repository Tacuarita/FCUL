; fc57547

;********************************************************************
section .data
;********************************************************************
; definições úteis

LF                  equ     10
NULL                equ     0          
    
; tamanhos máximos esperados

MAX_IMG_SIZE        equ     1048576         ; tamanho do buffer da imagem bmp
MAX_MSG_SIZE        equ     1024            ; tamanho do buffer da mensagem de texto
    
txtFile             dq      0               ; o nome da mensagem original de texto
bmpFile             dq      0               ; o nome da imagem original bmp
newFile             dq      0               ; o nome da imagem modificada bmp 

; mensagens de erro
errorManyArgs   	db      "Demasiados argumentos", LF, NULL
errorFewArgs    	db      "Poucos argumentos", LF, NULL   

;********************************************************************
section .bss
;********************************************************************

key             	resq    1               ; valor da rotacao R
eof             	resq    1               ; o numero de bytes lidos no ficheiro txt
newBmpBytes     	resb    MAX_IMG_SIZE 	
imageBuffer     	resb    MAX_IMG_SIZE	
textBuffer      	resb    MAX_MSG_SIZE	
imageOffset     	resq    1               ; offset da imagem bmp
    
;********************************************************************
section .text
;********************************************************************

extern terminate
extern printStr
extern printStrLn
extern readMessageFile
extern readImageFile
extern writeImageFile

global _start
_start:
    
    ; 1) Recebe os argumentos
    mov     rax, [rsp]                      ; RSP -> argc
    cmp     rax, 5                          ; Caso RAX < 5, ha argumentos a menos 
    jb      errorNotEnoughArgs          
    cmp     rax, 5                          ; Caso RAX > 5, ha argumentos a mais
    ja      errorTooManyArgs
    
    ; 2) Distribui os argumentos
    mov     rdi, [rsp + 16]                 ; RSP + 16 -> argv[1] 
    mov     [txtFile], rdi                  ; TxtFile -> o nome da mensagem original de texto
	
    mov     rcx, [rsp + 24]                 ; RSP + 24 -> argv[2]
    mov     al, [rcx]                       ; Primeiro digito de R em AL
    mov     cl, [rcx + 1]                   ; Segundo digito de R em CL
    cmp     cl, 0                           ; Caso R >= 10 multiplicar AL por 10, caso contrario seguir em frente 
    je 	    setKey
    add     al, -0x30                       ; Traduzir AL de numero ASCII para numero Hex
    mov     ch, 10
    mul     byte ch          
setKey: 
    add     cl, -0x30                       ; Traduzir CL de numero ASCII para numero Hex
    add     cl, al                          ; Soma de CL com AL para ter o numero inteiro
    mov     [key], al                       ; Key -> valor da rotacao R
    
    mov     rdi, [rsp + 32]                 ; RSP + 32 -> argv[3] 
    mov     [bmpFile], rdi                  ; BmpFile -> o nome da imagem original bmp
    
    mov     rdi, [rsp + 40]                 ; RSP + 40 -> argv[4]
    mov     [newFile], rdi                  ; NewFile -> o nome da imagem modificada bmp
    
    ; 3) Abre a mensagem original de texto
    mov     rdi, [txtFile]                  ; RDI -> endereço de memória para string com o nome da mensagem original de texto
    mov     rsi, textBuffer                 ; RSI -> endereço do buffer que guardará os bytes lidos
    call    readMessageFile               
    mov     [eof], rax                      ; EOF -> o numero de bytes lidos no ficheiro txt
          
    ; 4) Abre a imagem original bmp  
    mov     rdi, [bmpFile]                  ; RDI -> endereço de memória para string com o nome da imagem original bmp
    mov     rsi, imageBuffer                ; RSI -> endereço do buffer que guardará os bytes lidos
    call    readImageFile
    mov     [newBmpBytes], rax              ; NewBmpBytes -> o numero de bytes a escrever na imagem modificada bmp


    ; 5) Le o cabecalho da imagem original bmp
    xor     eax, eax                             
    mov     eax, [imageBuffer + 10]         ; Agarra o valor de offset da imagem bmp
    mov     [imageOffset], eax
    mov     rbx, [imageOffset]              ; Guarda o valor do offset da imagem bmp
    xor     rcx, rcx                    
    xor     rdx, rdx                    
    
    ; 6) Agarra em cada caracter na mensagem original de texto
getCharByte:
    cmp     rcx, [eof]                      ; Caso RCX > EOF, significa que chegou ao fim da mensagem
    jg      writeNewBmpFile
    xor     ah, ah
    mov     al, [textBuffer + rcx]          ; Agarra um caracter
    inc     rcx                             ; Incrementa o numero de caracteres lidos 
    push    rcx                             ; Guarda o contador referido acima na pilha
    xor     rcx, rcx                    
    jmp     rolChar
    
    ; 7) Escreve no buffer guardado da imagem original bmp, a mesnagem original de texto com a rotacao r
rolChar:								
    cmp     ah, [key]                       ; Caso AH = Key, ja foram feitas as rotacoes pretendidas 
    je      printChar                   
    ror     al, 1                           ; Aplica o algoritmo de criptografia
    inc     ah
    jmp     rolChar    
printChar:                                  ; Divide o caractere por bits e distribui cada bit pelo buffer
	xor		ah, ah
    sal     al, 1                           ; Empurra o MSB de AL para o carry
    adc     ah, 0                           ; Adiciona o carry referido acima em AH
    
    and     byte [imageBuffer + rbx], 0xFE  ; Faz com que o LSB do byte do buffer seja 0         
    or      byte [imageBuffer + rbx], ah    ; Adiciona o bit do caracter ao bit do buffer
    xor     ah, ah
    
    add     rbx, 2                          ; Aumenta o indice do buffer a modificar
    inc     rcx                             ; Incrementa o numero de bits escritos do caractere
    cmp     rcx, 8                          ; Caso RCX = 8, ja escreveu todos os bits do caractere
    jne     printChar   
    pop     rcx                             ; Vai buscar a pilha o contador referido em 6)
    jmp     getCharByte 
    
    ; 8) Abre/Cria a imagem modificada bmp e ecreve o buffer modificado em 7) na mesma 
writeNewBmpFile:    
    mov     rdi, [newFile]                  ; RDI -> endereço de memória para a string com o nome da imagem modificada bmp
    mov     rsi, imageBuffer                ; RSI -> endereço do buffer que contém os bytes da imagem modificada a serem escritos
    mov     rdx, [newBmpBytes]              ; RDX -> quantidade de bytes do buffer para escrever no ficheiro
    call    writeImageFile
    jmp     terminate

;--------------------------------------------------------------------
; Rótulos auxiliares apenas para escrever mensagens de erro e terminar
;--------------------------------------------------------------------

errorTooManyArgs:
    mov     rdi, errorManyArgs
    call    printStrLn
    call    terminate
    
errorNotEnoughArgs:
    mov     rdi, errorFewArgs
    call    printStrLn
    call    terminate                                                  
