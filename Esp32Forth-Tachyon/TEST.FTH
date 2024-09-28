( testing )
FORGET *EXTEND* : *EXTEND*	."  TachyonESP extensions 240922-2200 " cr ;
( very simple batch header - WIP - ./send EXTEND ACM0 3 )
variable batch 	variable line# 		internals
: .LINE# 	line# @ 4 U.R SPACE ; : PROMPTL $0D EMIT line# ++ .line# ;
: ESP32 	HERE batch ! echo ~  ['] noop to _eol
		['] PROMPTL to _prompt line# ~ !SP Forth ;
: *END*
    echo ~~ ['] eolok to _eol !prompt
    CR ." Batch load completed - "
    HERE batch @ - ABS . ." bytes over " .LINE# ." lines"
    ;
    
( -------------------------------------------------------------------------------------- )
ESP32	( enter batch mode for ESP32 )
forth

\ multi-line block comment up to a matching nested }
: { 	1 BEGIN KEY DUP '{' = IF DROP 1+
	ELSE [CHAR] } = IF 1- THEN THEN DUP 0= UNTIL DROP ;
	IMMEDIATE
\ my prefered comment separates and doesn't look like a maths operator (maybe --)
: ---		10 parse drop drop ; immediate

{
EXTEND is mainly designed for the ESP32-C3 and for compatibility with Tachyon tools
but should work fine on any system.
}


	( ALIASES )


: pri : ;	--- private def that can be stripped from the dictionary during a reclaim
: pub : ;	--- public def - left intact during a reclaim


( Tachyon ALIAS operators to symbols, and symbols to function names )
: <<			lshift ;
: >>			rshift ;
: &			AND ;
: |			OR ;
: ^			XOR ;
: &!			INVERT & ;
( convert bit to bitmask )
: |< ( b -- bm )	1 SWAP << ;
( convert bitmask to bit )
: >| ( bm -- b ) 	-1 SWAP BEGIN ?DUP WHILE 1 >> SWAP 1+ SWAP REPEAT ;
: PRINT"		postpone s" state @ if postpone type else type then ; immediate
: "			postpone s" state @ if postpone drop else drop then ; immediate
: :=			constant ;
: ms@			ms-ticks ;

: KB ( KB -- bytes )	10 << ;
: C@+ 			dup 1+ swap c@ ;
: C~			0 swap C! ;
: C++			dup C@ 1+ swap C! ;
: C--			dup C@ 1- swap C! ;

internals
: ?emit		?echo ;
forth

( null term strings )
: len$ ( adr -- cnt )	dup begin c@+ 0= until swap - 1- ;
: type$ ( addr -- )	begin C@+ ?dup while emit repeat drop ;	

( WITHIN - INCLUSIVE )
: >< ( n min max -- f )	ROT SWAP ( min n max ) 1+ OVER > ( min n f ) -ROT 1+ < & ;



( DATASPACE )
variable @org
: org			@org ! ;
HERE org  4 KB ALLOT
@org @			:= org0
: !org			org0 org ;
--- align org if needed
: &org ( n -- )		1- @org @ OVER + SWAP &! org ; 

: bytes			@org @ constant @org +! ;
: byte			1 bytes ;
( align longs to cell boundary )
: longs			cell &org cells bytes ;
: long			1 longs ;


	( AUX STACK )
{
simple aux stack - 16 levels - won't error on over or underflow
Also manipulate the tos via @A such as @A ++
Can also be used as a locals stack - use A B C - no need to pop either
}

16 		longs @A
@A CELL+	:= @B
@B CELL+	:= @C
@C CELL+	:= @D

: A!		@A ! ;
: A		@A @ ;
: B		@B @ ;
: C		@C @ ;
: D		@D @ ;
: >A		@A @B 60 CMOVE> A! ;
: DROPA		@B @A 60 CMOVE ;
: A> 		A DROPA ;

( so rather than use the return stack for temps - just push and pop multiples using aux stack )
: PUSHA ( <n> cnt -- ) 	1- FOR >A NEXT ;
: POPA ( cnt -- <n> )	1- FOR A> NEXT ;
( AUX STACK EXTRAS )
: A@+		A @ CELL @A +! ;
: AW@+ ( -- w )	A UW@ 2 @A +! ;





	( TIMING TOOLS )

long lap1  long lap2
: LAP			ms@ lap1 @ lap2 ! lap1 ! ;
: .LAP			lap1 @ lap2 @ - ABS . PRINT" ms" ;


: .ADDR			CR .L ." :  "  ;

( dump words )
: DUMPW ( addr cnt -- )
   over $0F & if over .ADDR then
   2/ for aft
     dup $0F & 0= if dup .addr then
     dup @ .W space 2 +
   then next drop cr
;

	( MEMORY MAP VIEWER )

: DUMPB ( addr cnt blksiz -- )
	-ROT BOUNDS DO
	  I OVER 4 << 1- & 0= IF CR I .L ." : " THEN
	  I OVER BOUNDS 0 -ROT DO I C@ + LOOP
	OVER / .B SPACE DUP +LOOP DROP
;

: DUMPC ( addr cnt -- )
	>A
	1- FOR A .ADDR A@+ .L NEXT
;

{
--- LOCAL VARIABLES VERSION 
: DUMPW ( A:addr B:cnt -- )
   2 PUSHA
   A $0F & if A .ADDR then
   B 2/ for aft
     A $0F & 0= if A .addr then
     AW@+ .W space
   then next cr
;

: DUMPB ( addr cnt blksiz -- )
	>A BOUNDS DO
	  I A 4 << 1- & 0= IF CR I .L ." : " THEN
	  0 I A BOUNDS DO I C@ + LOOP
	A / .B SPACE A +LOOP 
;

}

( colors: black red green yellow blue magenta cyan white )


: .COLOR ( xt -- xt )
	plain blue pen DUP CELL - C@ ?DUP
	IF
	  DUP 1 = IF bold red pen DROP ELSE IF magenta pen THEN THEN	\ a flag?  immediate red or else blue
	ELSE
	  DUP @ ['] red @ = IF green pen THEN	\ green constants
	  DUP @ ['] lap1 @ = IF yellow pen THEN	\ yellow variables
	  DUP @ ['] LAP @ = IF plain THEN	\ cyan colon defs
	THEN
	;


: .words
    cr
    context @ @
    BEGIN  DUP
    WHILE plain ( ?ins. ) DUP .ADDR DUP @ .L 2 SPACES
      .COLOR
      DUP >NAME TYPE >link
    REPEAT
    DROP cr
;

long _xpos long _xmax

: ?WRAP ( cnt -- )	DUP _xpos @ + 2 + _xmax @ > if cr _xpos ~ then 1+ _xpos +! ;

: cwords ( [from] -- )
    _xpos ~
    cr bl parse find ?DUP 0= IF context @ @ THEN
    BEGIN DUP
    WHILE plain ( ?ins. ) .COLOR DUP >NAME DUP ?WRAP TYPE SPACE >link
    REPEAT
    DROP plain bold yellow pen cr
;


: words cwords ;


	( LOOKUP & LOOKDOWN string )
{
 Simple lookdown - finds the matching character in the string and returns with the index +1
 or 0 if not found (assumes string address > 512 and string length < 512 )
 The return value can also be used as a simple flag where any non-zero value indicates a match
Usage: $5A s" 0123456789:@ABCDEFGHIJKLMNOPQRSTUVWXYZ[~" LOOKDOWN
: DEMO s" 0123456789:@ABCDEFGHIJKLMNOPQRSTUVWXYZ[~" LOOKDOWN .L ;
}
: LOOKDOWN ( ch str cnt -- index+1|0 )
 	ROT >A 0 DO DUP I + C@ A = IF DROP I 1+ LEAVE THEN LOOP
	A> DROP DUP $200 > IF DROP 0 THEN
;

{
Simple lookup - translate an index value to a character using the string as the lookup table
}

: LOOKUP ( index str cnt -- byte ) ROT 2DUP > IF NIP + C@ ELSE DROP 2DROP 0 THEN ;


	( STACK PRINT )
	
\ Enhanced stack print in top to bottom multi-mode format
: ..s	cr over . 2 spaces dup .l 2 spaces dup aemit 2 spaces . ;
: .s  	depth if sp@ >A 1 begin A sp0 >
	while A @ ..s -4 @A +! 1+ repeat
	A> 2drop else ."  empty " then ;

	( SIMPLE SWITCH CASE )

long _?
: ?! ( n -- )		_? ! ;
: ?@ ( -- n )		_? @ ;
: ?= ( n -- f )		?@ = ;
: ?>< ( min max -- f )	?@ -ROT >< ;


	( CONSOLE ENHANCEMENTS )


--- timeout if no key pressed
: ?KEY ( ms -- key|0 )	ms@ + BEGIN KEY? 0= WHILE DUP ms@ = IF DROP 0 EXIT THEN REPEAT DROP KEY ;

--- wait for key input and getnum - terminate on timeout or invalid key
: ?NUM ( ms -- n )
    0 BEGIN OVER ?KEY DUP '0' '9' ><
    WHILE '0' - SWAP 10 * +
    REPEAT DROP NIP
;
	( ANSI SETUP )

--- ESC[6n 	request cursor position (reports as ESC[#;#R)
: XY@ ( -- x y )
    ESC[ '6' EMIT 'n' EMIT
    5 ?KEY $1B = IF 5 ?KEY DROP 5 ?NUM 5 ?NUM SWAP ELSE 0 0 THEN
;
--- if ANSI, the terminal will respond to this with its window size - otherwise 0 0
: ANSI@ ( -- xmax ymax )
    XY@ 999 999 XY XY@ >R >R XY R> R>
    ;
--- Check ANSI support and set line-width else disable ANSI
: ?ANSI		1 to _ansi ANSI@ DROP ?DUP 0= IF 0 to _ansi 80 THEN _xmax ! ;

( read a CSI sequence and abbreviate to 32-bits )
: CSIKEY ( --- code )
    KEY DUP $1B =
    IF  ms@ SWAP
      BEGIN KEY?
\                ignore ;      else merge to code       update timeout
        IF KEY DUP ';' = IF DROP ELSE SWAP 8 << OR THEN   NIP ms@ SWAP THEN
\     timeout after 3ms of inactivity - must be end of sequence
        OVER ms@ - ABS 5 >
      UNTIL NIP
    THEN ; 


: .BOOT		?ANSI cls plain bold green pen reverse *EXTEND* plain ok plain ;


	( CONSOLE EDIT & HISTORY )
: syspen		plain blue pen ;
: usrpen		plain bold yellow pen space 8 emit ;
: uprompt    		$0d emit syspen depth str type '#' emit '>' emit space usrpen  ;




8 	:= #hists
128	:= tibmax

tibmax #hists * bytes historys  ( single level for testing )

long adr : adr@ adr @ ;
--- note: cnt,aflg,hist#, are part of a cell and can be cleared with one operation
byte cnt : cnt@ cnt C@ ;	--- accept cnt (mainly write index)
byte aflg 
byte hist#
byte mx

			\ copy selected history                                 to tib               and set cnt
: history>		historys  tibmax hist# C@ #hists MIN DUP IF 1- THEN * +  adr@ tibmax cmove adr@ len$ cnt C! ;
			\ if new line    then push historys down                             and copy buffer to latest history
: >history		hist# C@ 0= IF historys  historys tibmax + tibmax #hists 1- * CMOVE> adr@ historys tibmax cmove THEN ;
: reprompt		$0D emit _xmax C@ 20 max 128 min spaces uprompt ;
: clrtib		adr@ tibmax erase cnt C~ ;
: retype		reprompt adr@ type$ ;
: gethist		history>   retype ;
: .tib 			uprompt adr@ type$   XY@ NIP cnt@ 5 + swap XY ;
			\ retype line if modified
: =CR			cnt@ adr@ len$ <> IF retype THEN    syspen ."  --- "  plain hist# C~    ;
: =UP			hist# C++ gethist ;
: ?INS			aflg C@ 1 & if adr@ cnt@ + dup 1+ over len$ cmove> then .tib ;
: =CH			?INS ?@ dup ?emit adr@ cnt@ + C! cnt C++ ;
\ 123456789
	( key handlers )
: ?keys
    ?!
    $20 $7E ?>< cnt@ mx C@ < & if =CH exit then
    ^M ?= ( CR )	if >history =CR exit then
    ^H ?= ( BS )	if cnt@ if cnt C-- 8 ?emit bl ?emit 8 ?emit then then
    ^Q ?= ( .S ) 	if .s cr uprompt then
    ^S ?= ( !SP )	if !sp uprompt then 
    ^W ?= ( WORDS )	if cwords uprompt then
    ^L ?= ( cls )	if ^L emit .BOOT !sp then
    ^Z ?= ( ZAP )	if 0 CALL then 
    ^? ?= ( QUERY )	if ok then
    ^X ?= ( execute )	if =UP =CR $0D ?! then
    ^[ ?= ( esc )	if clrtib reprompt then 
    ( ANSI KEYS )
    $1B5B41 ?= ( UP )	if =UP then
    $1B5B42 ?= ( DN )	if hist# C@ if hist# C-- hist# C@ if gethist exit then then clrtib reprompt then
    $1B5B43 ?= ( R )	if cnt@ adr@ len$ < if cnt C++ .tib then then
    $1B5B44 ?= ( L )	if cnt@ IF cnt C-- .tib then then
    $1B5B40 ?= ( INS )	if aflg C++ then
    $1B5B48 ?= ( home )	if cnt C~ .tib then
    $1B4F46 ?= ( end )	if adr@ len$ cnt C! .tib then
    $1B7F ?=		if adr@ cnt@ + dup 1+ swap over len$ 1+ cmove reprompt .tib then 
;
forth


: accept2 ( adr max -- cnt )
   2dup erase cnt ~ mx C! adr ! 
   usrpen begin csikey ?keys ?@ $0d = until
   adr@ len$
;


	( BOOT TIME )

: EXTEND			200 ms !SP ['] accept2 to _accept .BOOT ;

\ disable while testing
\ remember startup: EXTEND
 
*END*
EXTEND



