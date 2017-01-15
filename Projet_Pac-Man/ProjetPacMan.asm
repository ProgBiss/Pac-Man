;;===========================================================================;;
;;= MODÈLE DE PROGRAMME ASSEMBLEUR 6502 POUR NINTENDO ENTERTAINEMENT SYSTEM =;;
;;======================= Produit par François Allard =======================;;
;;====================== Cégep de Drummondville - 2014 ======================;;
;;===========================================================================;;
;;
;; $0000-0800 - Mémoire vive interne, puce de 2KB dans la NES
;; $2000-2007 - Ports d'accès du PPU
;; $4000-4017 - Ports d'accès de l'APU
;; $6000-7FFF - WRAM optionnelle dans la ROM
;; $8000-FFFF - ROM du programme
;;
;; Contrôle du PPU ($2000)
;; 76543210
;; ||||||||
;; ||||||++- Adresse de base de la table de noms
;; ||||||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
;; ||||||
;; |||||+--- Incrément de l'adresse en VRAM à chaque écriture du CPU
;; |||||     (0: incrément par 1; 1: incrément par 32 (ou -1))
;; |||||
;; ||||+---- Adresse pour les motifs de sprites (0: $0000; 1: $1000)
;; ||||
;; |||+----- Adresse pour les motifs de tuiles (0: $0000; 1: $1000)
;; |||
;; ||+------ Taille des sprites (0: 8x8; 1: 8x16)
;; ||
;; |+------- Inutilisé
;; |
;; +-------- Générer un NMI à chaque VBlank (0: off; 1: on)
;;
;; Masque du PPU ($2001)
;; 76543210
;; ||||||||
;; |||||||+- Nuances de gris (0: couleur normale; 1: couleurs désaturées)
;; |||||||   Notez que l'intensité des couleurs agit après cette valeur!
;; |||||||
;; ||||||+-- Désactiver le clipping des tuiles dans les 8 pixels de gauche
;; ||||||
;; |||||+--- Désactiver le clipping des sprites dans les 8 pixels de gauche
;; |||||
;; ||||+---- Activer l'affichage des tuiles
;; ||||
;; |||+----- Activer l'affichage des sprites
;; |||
;; ||+------ Augmenter l'intensité des rouges
;; ||
;; |+------- Augmenter l'intensité des verts
;; |
;; +-------- Augmenter l'intensité des bleus
;;
;;===========================================================================;;
;;=============================== Déclarations ==============================;;
;;===========================================================================;;

	.inesprg 1		; Banque de 1x 16KB de code PRG
	.ineschr 1		; Banque de 1x 8KB de données CHR
	.inesmap 0		; Aucune échange de banques
	.inesmir 1		; Mirroir du background

;;===========================================================================;;
;;============================== Initialisation =============================;;
;;===========================================================================;;

	.bank 0			; Banque 0
	.org $8000		; L'écriture commence à l'adresse $8000
	.code			; Début du programme
		
;;---------------------------------------------------------------------------;;
;;------ Reset: Initialise le PPU et le APU au démarrage du programme -------;;
;;---------------------------------------------------------------------------;;
Reset:
	SEI				; Désactive l'IRQ
	CLD				; Désactive le mode décimal
	LDX #%01000000	; Charge %01000000 (64) dans X
	STX $4017		; Place X dans $4017 et désactive le métronome du APU
	LDX #$FF		; Charge $FF (255) dans X
	TXS				; Initialise la pile à 255
	INX				; Incrémente X
	STX $2000		; Place X dans $2000 et désactive le NMI
	STX $2001		; Place X dans $2001 et désactive l'affichage
	STX $4010		; Place X dans $4010 et désactive le DMC
	JSR VBlank

;;---------------------------------------------------------------------------;;
;;-------------------- Clear: Remet la mémoire RAM à zéro -------------------;;
;;---------------------------------------------------------------------------;;
Clear:
	LDA #$00		; Charge $00 (0) dans A
	STA $0000, x	; Place A dans $00XX
	STA $0100, x	; Place A dans $01XX
	STA $0300, x	; Place A dans $03XX
	STA $0400, x	; Place A dans $04XX
	STA $0500, x	; Place A dans $05XX
	STA $0600, x	; Place A dans $06XX
	STA $0700, x	; Place A dans $07XX
	LDA #$FF		; Charge $FF (255) dans A
	STA $0200, x	; Place A dans $02XX
	INX				; Incrémente X
	BNE Clear		; Recommence Clear si X n'est pas 0
	
	
	;;-- Initialisation des variables --;;
	LDX #10
	STX directionFantome1
	LDX #20
	STX directionFantome2
	LDX #30
	STX directionFantome3
	LDX #40
	STX directionFantome4
	LDX #40
	STX directionPacMan
	LDX #1
	STX fantomeChoisi
	LDX #0
	STX timerBouche
	LDX #1
	STX boucheOuverte
	
	
	JSR VBlank		; Attend un chargement d'image complet avant de continuer
	JSR PPUInit		; Initialise le PPU avant de charger le reste
	
;;---------------------------------------------------------------------------;;
;;--------- LoadPalettes: Charge les palettes de couleur en mémoire ---------;;
;;---------------------------------------------------------------------------;;
LoadPalettes:
	LDA $2002		; Lis l'état du PPU pour réinitialiser son latch
	LDA #$3F		; Charge l'octet le plus significatif ($3F) dans A
	STA $2006		; Place A dans $2006
	LDA #$00		; Charge l'octet le moins significatif ($00) dans A
	STA $2006		; Place A dans $2006
	LDY #$00		; Charge $00 (0) dans Y

;;---------------------------------------------------------------------------;;
;;----------- LoadPalettesLoop: Boucle de chargement des palettes -----------;;
;;---------------------------------------------------------------------------;;
LoadPalettesLoop:
	LDA Palette, y	; Charge le premier octet de la Palette (+ Y) dans A
	STA $2007		; Place A dans $2007
	INY				; Incrémente Y
	CPY #$20		; Compare Y avec $20 (32)
	BNE LoadPalettesLoop	; Recommence LoadPalettesLoop si Y < 32
  
;;---------------------------------------------------------------------------;;
;;--------------- LoadSprites: Charge les sprites en mémoire ----------------;;
;;---------------------------------------------------------------------------;;
LoadSprites:
	LDY #$00		; Charge $00 (0) dans Y

;;---------------------------------------------------------------------------;;
;;------------ LoadSpritesLoop: Boucle de chargement des sprites ------------;;
;;---------------------------------------------------------------------------;;
LoadSpritesLoop:
	LDA Sprites, y	; Charge le premier octet des Sprites (+ Y) dans A
	STA $0200, y	; Place A dans $02YY
	INY				; Incrémente Y
	CPY #$64		; Compare Y avec $64
	BNE LoadSpritesLoop		; Recommence LoadSpritesLoop si Y < 4
	JSR PPUInit		; Appelle l'initialisation du PPU

;;===========================================================================;;
;;=================================== Code ==================================;;
;;===========================================================================;;	



;;---------------------------------------------------------------------------;;
;;------------------- Forever: Boucle infinie du programme ------------------;;
;;---------------------------------------------------------------------------;;
Forever:
	JMP Forever		; Recommence Forever jusqu'à la prochaine interruption

;;---------------------------------------------------------------------------;;
;;------------ NMI: Code d'affichage à chaque image du programme ------------;;
;;---------------------------------------------------------------------------;;
NMI:
;;############################# Votre code ici ##############################;;

	LDA #$01
	STA $4016
	LDA #00
	STA $4016	
	
	LDA $4016 ;A
	LDA $4016 ;B
	LDA $4016 ;Select
	LDA $4016 ;Start
	LDA $4016 ;Haut
	AND #1
	BNE RelaisPacHaut1
	LDA $4016 ;Bas
	AND #1
	BNE RelaisPacBas1
	LDA $4016 ;Gauche
	AND #1
	BNE RelaisPacGauche1
	LDA $4016 ;Droite
	AND #1
	BNE RelaisPacDroite1
	JMP ContinuerPacMan
	
RelaisPacDroite1:
	JMP PacDroite

RelaisPacGauche1:
	JMP PacGauche

RelaisPacHaut1:
	JMP PacHaut
	
RelaisPacBas1:
	JMP PacBas

ContinuerPacMan:
	LDA directionPacMan
	CMP #10
	BEQ RelaisPacHaut2
	CMP #20
	BEQ RelaisPacBas2
	CMP #30
	BEQ RelaisPacGauche2
	CMP #40
	BEQ RelaisPacDroite2
	
RelaisPacDroite2:
	JMP PacDroite

RelaisPacGauche2:
	JMP PacGauche

RelaisPacHaut2:
	JMP PacHaut
	
RelaisPacBas2:
	JMP PacBas
	
PacHaut:
	LDA #%10000000
	STA $202
	STA $206
	STA $20A
	STA $20E
	LDA #$09
	STA $201
	LDA #$0A
	STA $205
	LDA #$07
	STA $209
	LDA #$08
	STA $20D
	DEC $200
	DEC $204
	DEC $208
	DEC $20C
	LDA #10
	STA directionPacMan
	JMP FinPacMan

PacBas:
	LDA #%00000000
	STA $202
	STA $206
	STA $20A
	STA $20E
	LDA #$07
	STA $201
	LDA #$08
	STA $205
	LDA #$09
	STA $209
	LDA #$0A
	STA $20D
	INC $200
	INC $204
	INC $208
	INC $20C
	LDA #20
	STA directionPacMan
	JMP FinPacMan

PacGauche:
	LDA #%01000000
	STA $202
	STA $206
	STA $20A
	STA $20E
	LDA #$00
	STA $205
	LDA #$01
	STA $201
	LDA #$02
	STA $20D
	LDA #$03
	STA $209
	DEC $203
	DEC $207
	DEC $20B
	DEC $20F
	LDA #30
	STA directionPacMan
	JMP FinPacMan

PacDroite:
	LDA #%00000000
	STA $202
	STA $206
	STA $20A
	STA $20E
	LDA #$00
	STA $201
	LDA #$01
	STA $205
	LDA #$02
	STA $209
	LDA #$03
	STA $20D
	INC $203
	INC $207
	INC $20B
	INC $20F
	LDA #40
	STA directionPacMan
	JMP FinPacMan

FinPacMan:
	JMP Fantomes

Fantomes:	
	LDA $4017 ;A
	AND #1
	BNE SelectionFantome1 ;Switch au Jaune
	LDA $4017 ;B
	AND #1
	BNE SelectionFantome2 ;Switch au Bleu
	LDA $4017 ;Select
	AND #1
	BNE SelectionFantome3 ;Switch au Orange
	LDA $4017 ;Start
	AND #1
	BNE SelectionFantome4 ;Switch au Rouge
	LDA $4017 ;Haut
	AND #1
	BNE RelaisDirectionHaut
	LDA $4017 ;Bas
	AND #1
	BNE RelaisDirectionBas
	LDA $4017 ;Gauche
	AND #1
	BNE RelaisDirectionGauche
	LDA $4017 ;Droite
	AND #1
	BNE RelaisDirectionDroite
	JMP ContinuerFantome1
	
RelaisDirectionHaut:
	JMP SelectionDirectionHaut
	
RelaisDirectionBas:
	JMP SelectionDirectionBas
	
RelaisDirectionGauche:
	JMP SelectionDirectionGauche
	
RelaisDirectionDroite:
	JMP	SelectionDirectionDroite
	
SelectionFantome1:
	LDA #1
	STA fantomeChoisi
	JMP ContinuerFantome1

SelectionFantome2:
	LDA #2
	STA fantomeChoisi
	JMP ContinuerFantome1
	
SelectionFantome3:
	LDA #3
	STA fantomeChoisi
	JMP ContinuerFantome1
	
SelectionFantome4:
	LDA #4
	STA fantomeChoisi
	JMP ContinuerFantome1
	
SelectionDirectionHaut:
	LDA fantomeChoisi
	CMP #1
	BEQ Relais1Haut
	CMP #2
	BEQ Relais2Haut
	CMP #3
	BEQ Relais3Haut
	CMP #4
	BEQ Relais4Haut
	
Relais1Haut:
	LDA #10
	STA directionFantome1
	JMP ContinuerFantome1

Relais2Haut:
	LDA #10
	STA directionFantome2
	JMP ContinuerFantome1

Relais3Haut:
	LDA #10
	STA directionFantome3
	JMP ContinuerFantome1

Relais4Haut:
	LDA #10
	STA directionFantome4
	JMP ContinuerFantome1
	
SelectionDirectionBas:
	LDA fantomeChoisi
	CMP #1
	BEQ Relais1Bas
	CMP #2
	BEQ Relais2Bas
	CMP #3
	BEQ Relais3Bas
	CMP #4
	BEQ Relais4Bas
	
Relais1Bas:
	LDA #20
	STA directionFantome1
	JMP ContinuerFantome1

Relais2Bas:
	LDA #20
	STA directionFantome2
	JMP ContinuerFantome1

Relais3Bas:
	LDA #20
	STA directionFantome3
	JMP ContinuerFantome1

Relais4Bas:
	LDA #20
	STA directionFantome4
	JMP ContinuerFantome1
	
SelectionDirectionGauche:
	LDA fantomeChoisi
	CMP #1
	BEQ Relais1Gauche
	CMP #2
	BEQ Relais2Gauche
	CMP #3
	BEQ Relais3Gauche
	CMP #4
	BEQ Relais4Gauche
	
Relais1Gauche:
	LDA #30
	STA directionFantome1
	JMP ContinuerFantome1

Relais2Gauche:
	LDA #30
	STA directionFantome2
	JMP ContinuerFantome1

Relais3Gauche:
	LDA #30
	STA directionFantome3
	JMP ContinuerFantome1

Relais4Gauche:
	LDA #30
	STA directionFantome4
	JMP ContinuerFantome1

SelectionDirectionDroite
	LDA fantomeChoisi
	CMP #1
	BEQ Relais1Droite
	CMP #2
	BEQ Relais2Droite
	CMP #3
	BEQ Relais3Droite
	CMP #4
	BEQ Relais4Droite
	
Relais1Droite:
	LDA #40
	STA directionFantome1
	JMP ContinuerFantome1

Relais2Droite:
	LDA #40
	STA directionFantome2
	JMP ContinuerFantome1

Relais3Droite:
	LDA #40
	STA directionFantome3
	JMP ContinuerFantome1

Relais4Droite:
	LDA #40
	STA directionFantome4
	JMP ContinuerFantome1
	
ContinuerFantome1:	;Jaune
	LDA directionFantome1
	CMP #10
	BEQ Fantome1Haut
	CMP #20
	BEQ Fantome1Bas
	CMP #30
	BEQ Fantome1Gauche
	CMP #40
	BEQ Fantome1Droite

Fantome1Haut: 	;Jaune
	DEC $210
	DEC $214
	DEC $218
	DEC $21C
	LDA #10
	STA directionFantome1
	JMP ContinuerFantome2

Fantome1Bas: 	;Jaune
	INC $210
	INC $214
	INC $218
	INC $21C
	LDA #20
	STA directionFantome1
	JMP ContinuerFantome2
	
Fantome1Gauche:	;Jaune
	DEC $213
	DEC $217
	DEC $21B
	DEC $21F
	LDA #30
	STA directionFantome1
	JMP ContinuerFantome2
	
Fantome1Droite: ;Jaune
	INC $213
	INC $217
	INC $21B
	INC $21F
	LDA #40
	STA directionFantome1
	JMP ContinuerFantome2
	
ContinuerFantome2:	;Bleu
	LDA directionFantome2
	CMP #10
	BEQ Fantome2Haut
	CMP #20
	BEQ Fantome2Bas
	CMP #30
	BEQ Fantome2Gauche
	CMP #40
	BEQ Fantome2Droite

Fantome2Haut:	;Bleu
	DEC $220
	DEC $224
	DEC $228
	DEC $22C
	LDA #10
	STA directionFantome2
	JMP ContinuerFantome3
	
Fantome2Bas:	;Bleu
	INC $220
	INC $224
	INC $228
	INC $22C
	LDA #20
	STA directionFantome2
	JMP ContinuerFantome3
	
Fantome2Gauche:	;Bleu
	DEC $223
	DEC $227
	DEC $22B
	DEC $22F
	LDA #30
	STA directionFantome2
	JMP ContinuerFantome3
	
Fantome2Droite:	;Bleu
	INC $223
	INC $227
	INC $22B
	INC $22F
	LDA #40
	STA directionFantome2
	JMP ContinuerFantome3
	
ContinuerFantome3:	;Orange
	LDA directionFantome3
	CMP #10
	BEQ Fantome3Haut
	CMP #20
	BEQ Fantome3Bas
	CMP #30
	BEQ Fantome3Gauche
	CMP #40
	BEQ Fantome3Droite
	
Fantome3Haut:	;Orange
	DEC $230
	DEC $234
	DEC $238
	DEC $23C
	LDA #10
	STA directionFantome3
	JMP ContinuerFantome4
	
Fantome3Bas:	;Orange
	INC $230
	INC $234
	INC $238
	INC $23C
	LDA #20
	STA directionFantome3
	JMP ContinuerFantome4
	
Fantome3Gauche:	;Orange
	DEC $233
	DEC $237
	DEC $23B
	DEC $23F
	LDA #30
	STA directionFantome3
	JMP ContinuerFantome4
	
Fantome3Droite:	;Orange
	INC $233
	INC $237
	INC $23B
	INC $23F
	LDA #40
	STA directionFantome3
	JMP ContinuerFantome4
	
ContinuerFantome4:	;Rouge
	LDA directionFantome4
	CMP #10
	BEQ Fantome4Haut
	CMP #20
	BEQ Fantome4Bas
	CMP #30
	BEQ Fantome4Gauche
	CMP #40
	BEQ Fantome4Droite
	
Fantome4Haut:	;Rouge
	DEC $240
	DEC $244
	DEC $248
	DEC $24C
	LDA #10
	STA directionFantome4
	JMP End
	
Fantome4Bas:	;Rouge
	INC $240
	INC $244
	INC $248
	INC $24C
	LDA #20
	STA directionFantome4
	JMP End
	
Fantome4Gauche:	;Rouge
	DEC $243
	DEC $247
	DEC $24B
	DEC $24F
	LDA #30
	STA directionFantome4
	JMP End
	
Fantome4Droite:	;Rouge
	INC $243
	INC $247
	INC $24B
	INC $24F
	LDA #40
	STA directionFantome4
	JMP End

;;---------------------------------------------------------------------------;;
;;------------------ End: Fin du NMI et retour au Forever -------------------;;
;;---------------------------------------------------------------------------;;
End:
	LDA #$02
	STA $4014
	LDA #$01
	STA $4016
	RTI				; Retourne au Forever à la fin du NMI

;;---------------------------------------------------------------------------;;
;;---------- PPUInit: Code d'affichage à chaque image du programme ----------;;
;;---------------------------------------------------------------------------;;
PPUInit:
	LDA #$00		; Charge $00 (0) dans A
	STA $2003		; Place A, l'octet le moins significatif ($00) dans $2003
	LDA #$02		; Charge $02 (2) dans A
	STA $4014		; Place A, l'octet le plus significatif ($02) dans $4014. 
					; Cela initie le transfert de l'adresse $0200 pour la RAM
	LDA #%10001000	; Charge les informations de contrôle du PPU dans A
	STA $2000		; Place A dans $2000
	LDA #%00011110	; Charge les informations de masque du PPU dans A
	STA $2001		; Place A dans $2001
	RTS				; Retourne à l'exécution parent
	
;;---------------------------------------------------------------------------;;
;;---------------- CancelScroll: Désactive le scroll du PPU -----------------;;
;;---------------------------------------------------------------------------;;
CancelScroll:
	LDA $2002		; Lis l'état du PPU pour réinitialiser son latch
	LDA #$00		; Charge $00 (0) dans A
	STA $2000		; Place A dans $2000 (Scroll X précis)
	STA $2006		; Place A dans $2006 (Scroll Y précis)
	STA $2005		; Place A dans $2005 (Table de tuiles)
	STA $2005		; Place A dans $2005 (Scroll Y grossier)
	STA $2006		; Place A dans $2006 (Scroll X grossier)
	
;;---------------------------------------------------------------------------;;
;;------------ VBlank: Attend la fin de l'affichage d'une image -------------;;
;;---------------------------------------------------------------------------;;
VBlank:
	BIT $2002		; Vérifie le 7e bit (PPU loaded) de l'adresse $2002
	BPL VBlank		; Recommence VBlank si l'image n'est pas chargée au complet
	RTS				; Retourne à l'exécution parent

;;===========================================================================;;
;;================================ Affichage ================================;;
;;===========================================================================;;

	.bank 1			; Banque 1
	.org $E000		; L'écriture commence à l'adresse $E000
	
;;---------------------------------------------------------------------------;;
;;----------- Palette: Palette de couleur du fond et des sprites ------------;;
;;---------------------------------------------------------------------------;;
Palette:
	.db $FE,$20,$11,$15, $FE,$05,$15,$25, $FE,$08,$18,$28, $FE,$0A,$1A,$2A
	; Les couleurs du fond se lisent comme suis: 
	; [Couleur de fond, Couleur 1, Couleur 2, Couleur 3], [...], ...
	.db $FE,$28,$3E,$20, $FE,$12,$3E,$20, $FE,$27,$3E,$20, $FE,$16,$3E,$20
	; Les couleurs des sprites se lisent comme suis: 
	; [Couleur de transparence, Couleur 1, Couleur 2, Couleur 3], [...], ...
	
;;---------------------------------------------------------------------------;;
;;---------- Sprites: Position et attribut des sprites de départ ------------;;
;;---------------------------------------------------------------------------;;
Sprites:  
  .db $80, $00, %00000000, $88  ; 200, 201, 202, 203
  .db $80, $01, %00000000, $80	; 204, 205, 206, 207
  .db $88, $02, %00000000, $88	; 208, 209, 20A, 20B
  .db $88, $03, %00000000, $80	; 20C, 20D, 20E, 20F
  
  .db $50, $04, %00000000, $58
  .db $50, $05, %00000000, $50
  .db $58, $06, %00000000, $58
  .db $58, $06, %01000000, $50
  
  .db $60, $04, %00000001, $68
  .db $60, $05, %00000001, $60
  .db $68, $06, %00000001, $68
  .db $68, $06, %01000001, $60
  
  .db $40, $04, %00000010, $48
  .db $40, $05, %00000010, $40
  .db $48, $06, %00000010, $48
  .db $48, $06, %01000010, $40
  
  .db $30, $04, %00000011, $38
  .db $30, $05, %00000011, $30
  .db $38, $06, %00000011, $38
  .db $38, $06, %01000011, $30
  ; Les propriétés des sprites se lisent comme suit:
  ; [Position Y, Index du sprite, Attributs, Position X]

;;===========================================================================;;
;;============================== Interruptions ==============================;;
;;===========================================================================;;

	.org $FFFA		; L'écriture commence à l'adresse $FFFA
	.dw NMI			; Lance la sous-méthode NMI lorsque le NMI survient
	.dw Reset		; Lance la sous-méthode Reset au démarrage du processeur
	.dw 0			; Ne lance rien lorsque la commande BRK survient

;;===========================================================================;;
;;=============================== Background ================================;;
;;===========================================================================;;

	.bank 2			; Banque 1
	.org $0000		; L'écriture commence à l'adresse $0000
	
Tuile:
	.db %11111111
	.db %11111111
	.db %11000011
	.db %10010101
	.db %10011101
	.db %10010101
	.db %11000011
	.db %11111111
	
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %01111110
	.db %11111111
	.db %11101010
	.db %11100011
	.db %11101010
	.db %11111111
	.db %01111110
	
	; Les pixels représentés ici sont les bits les plus significatifs

;;===========================================================================;;
;;================================ Sprites ==================================;;
;;===========================================================================;;
	
	.org $1000		; L'écriture commence à l'adresse $1000
	
SpritePacManHautDroit:
	.db %00000000        
	.db %11100000        
	.db %11111000        
	.db %11111100        
	.db %11111110       
	.db %11111000        
	.db %11100000        
	.db %10000000       
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %11100000
	.db %00011000
	.db %00000100
	.db %00000010
	.db %00000001
	.db %00000110
	.db %00011000
	.db %01100000
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpritePacManHautGauche:
	.db %00000000
	.db %00000111
	.db %00011111
	.db %00111111
	.db %00111111
	.db %01111111
	.db %01111111
	.db %01111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000111
	.db %00011000
	.db %00100000
	.db %01000000
	.db %01000000
	.db %10000000
	.db %10000000
	.db %10000000
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpritePacManBasDroit:
	.db %11100000
	.db %11111000
	.db %11111110
	.db %11111100
	.db %11111000
	.db %11100000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00011000
	.db %00000110
	.db %00000001
	.db %00000010
	.db %00000100
	.db %00011000
	.db %11100000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpritePacManBasGauche:
	.db %01111111
	.db %01111111
	.db %00111111
	.db %00111111
	.db %00011111
	.db %00000111
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %10000000
	.db %10000000
	.db %01000000
	.db %01000000
	.db %00100000
	.db %00011000
	.db %00000111
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpriteFantomeHautDroit:
	.db %00000000
	.db %11000000
	.db %11110000
	.db %11111000
	.db %11111100
	.db %11011100
	.db %11111100
	.db %11111100
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %11000000
	.db %00110000
	.db %00001000
	.db %01100100
	.db %01100010
	.db %01100010
	.db %00000010
	.db %00000011
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpriteFantomeHautGauche:
	.db %00000000
	.db %00000011
	.db %00001111
	.db %00011111
	.db %00111111
	.db %00111101
	.db %00111111
	.db %01111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000011
	.db %00001100
	.db %00010000
	.db %00100110
	.db %01000110
	.db %01000110
	.db %01000000
	.db %10000000
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpriteFantomeBas:
	.db %11111110
	.db %11111110
	.db %11111110
	.db %11111110
	.db %11011100
	.db %10001000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000001
	.db %00000001
	.db %00000001
	.db %00000001
	.db %00100011
	.db %01010101
	.db %10001001
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

;;== Sprites PacMan regarde vers bas ==;;
	
SpritePacManHautDroitRB:
	.db %00000000        
	.db %11000000        
	.db %11110000        
	.db %11111000        
	.db %11111000       
	.db %11111100        
	.db %11111100        
	.db %11111100       
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %11000000        
	.db %00110000        
	.db %00001000        
	.db %00000100        
	.db %00000100       
	.db %00000010        
	.db %00000010        
	.db %00000010
	
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpritePacManHautGaucheRB:
	.db %00000000
	.db %00000111
	.db %00011111
	.db %00111111
	.db %00111111
	.db %01111111
	.db %01111111
	.db %01111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000111
	.db %00011000
	.db %00100000
	.db %01000000
	.db %01000000
	.db %10000000
	.db %10000000
	.db %10000000
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpritePacManBasDroitRB:
	.db %11111100
	.db %11111100
	.db %11111100
	.db %01111000
	.db %01111000
	.db %00110000
	.db %00100000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000010
	.db %00000010
	.db %00000010
	.db %10000100
	.db %10000100
	.db %01001000
	.db %01010000
	.db %00100000
	; Les pixels représentés ici sont les bits les plus significatifs
	
SpritePacManBasGaucheRB:
	.db %01111111
	.db %01111110
	.db %01111110
	.db %00111100
	.db %00111100
	.db %00011000
	.db %00001000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %10000000
	.db %10000001
	.db %10000001
	.db %01000010
	.db %01000010
	.db %00100100
	.db %00010100
	.db %00001000
	; Les pixels représentés ici sont les bits les plus significatifs

	
;;===========================================================================;;
;;=============================== VARIABLES =================================;;
;;===========================================================================;;	
	
	.bank 0
	.zp
	.org $0000
	
	directionPacMan: .ds 1
	directionFantome1: .ds 1
	directionFantome2: .ds 1
	directionFantome3: .ds 1
	directionFantome4: .ds 1
	fantomeChoisi: .ds 1
	boucheOuverte: .ds 1
	timerBouche: .ds 1
	
;;===========================================================================;;
;;============================== END OF FILE ================================;;
;;===========================================================================;;