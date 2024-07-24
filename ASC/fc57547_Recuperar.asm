; fc57547

;********************************************************************
section .data
;********************************************************************
; definições úteis

LF                  equ     10
NULL                equ     0

; tamanhos máximos esperados
  
MAX_IMG_SIZE        equ     1048576         ; tamanho do buffer da imagem bmp    
newLine             db      LF, NULL 

; mensagens de erro
 
errorManyArgs       db      "Demasiados argumentos", LF, NULL
errorFewArgs        db      "Poucos argumentos", LF, NULL
    
;********************************************************************
section .bss
;********************************************************************

key                 resq    1               ; valor da rotacao R
character           resq    1               ; caracter ASCII a escrever
imageOffset         resq    1               ; offset da imagem bmp
readBuffer          resb    MAX_IMG_SIZE

;********************************************************************
section .text
;********************************************************************

extern terminate
extern printStr
extern printStrLn
extern readImageFile

global _start
_start:

    ; 1) Recebe os argumentos
    mov     rax, [rsp]                      ; RSP -> argc
    cmp     rax, 3                          ; Caso RAX < 3, ha argumentos a menos
    jb      errorNotEnoughArgs                 
    cmp     rax, 3                          ; Caso RAX > 3, ha argumentos a mais
    ja      errorTooManyArgs                
    
    mov     rcx, [rsp+16]                   ; RSP + 16 -> argv[1]
    mov     al, [rcx]                       ; Primeiro digito de R em AL
    mov     cl, [rcx + 1]                   ; Segundo digito de R em CL
    cmp     cl, 0                           ; Caso R >= 10 multiplicar AL por 10, caso contrario seguir em frente 
    je      setKey
    add     al, -0x30                       ; Traduzir AL de numero ASCII para numero Hex
    mov     ch, 10
    mul     byte ch          
setKey: 
    add     cl, -0x30                       ; Traduzir CL de numero ASCII para numero Hex
    add     cl, al                          ; Soma de CL com AL para ter o numero inteiro
    mov     [key], al                       ; Key -> valor da rotacao R   
    
    ; 2) Abre a imagem modificada bmp
    mov     rdi, [rsp+24]                   ; RSP + 24 -> argv[2], o nome da imagem modificada bmp
    mov     rsi, readBuffer                 ; RSI -> endereço do buffer que guardará os bytes lidos
    call    readImageFile

    ; 3) Le o cabecalho da imagem modificada bmp                      
    xor     rax, rax                    
    mov     rax, [readBuffer + 10]          ; Agarra o valor de offset da imagem bmp
    mov     [imageOffset], rax
    mov     rbx, [imageOffset]              ; Guarda o valor do offset da imagem bmp 
    xor     rdx, rdx

    ; 4) Agarra os LSB's dos pixeis da imagem modificada bmp ate formar um caracter ASCII
getByte:																
    cmp     edx, 8                          ; Caso EDX = 8, ja temos um caracter ASCII
    je      printCharacter   
    mov     al, [readBuffer + ebx]          ; Agarra o byte do pixel 
    add     ebx,2                           ; Aumenta o indice do buffer a ler
    call    addBit
    jmp     getByte
addBit:                                     ; Adiciona o LSB do pixel ate formar um caracter ASCII
    and     al, 0b1                         ; Faz com que o LSB do byte do pixel nao seja modificado 
    sal     ah, 1                           ; Abre espaco para um novo LSB em AH 
    sal     al, 8                           ; Empurra o LSB de AL para o carry
    adc     ah, 0                           ; Adiciona o carry referido acima em AH
    xor     al, al
    inc     edx                             ; Incrementa o numero de bits adicionados
    ret

    ; 5) Imprime um caracter no terminal de saída
printCharacter:
    cmp     ah, NULL                        ; Caso AH = NULL, chegamos ao fim da mensagem
    je      terminate   
rolChar:																
    cmp     al, [key]                       ; Caso AL = Key, ja foram feitas as rotacoes pretendidas
    je      printChar
    rol     ah, 1                           ; Aplica o algoritmo inverso de criptografia
    inc     al
    jmp     rolChar    
printChar:                                  
    mov     [character], ah                 ; Character -> caracter ASCII a escrever
    xor     rdi, rdi
    xor     ah, ah
    mov     rdi, character                  ; RDI -> endereço de memória para o caractere 
    call    printStr                        ; Escreve o caractere no stdout
    xor     edx,edx
    jmp     getByte                         ; Volta para 4) para buscar o proximo caractere a escrever
     
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
