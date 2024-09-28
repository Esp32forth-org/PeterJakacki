+------------------------------+
|     ESP32forth -Tachyon      |
+------------------------------+

This is ESP32forth v7.0.7.15 which is being modified to be more like Tachyon Forth so
that I can port whatever tools I need to develop Tachyon Forth for RISC-V, and also
because this interactive interface should be smarter and more productive.

* USE Espressif ESP32 V2 board manager libs *
This is being tested on an ESP32-C3 XIAO module using the older V2.0.17 Espressif ESP32 board manager libraries in Arduino 2.3.2
Note: Espressif V3 libs do not work

* Editing and compiling *
I am editing the files in VS Code and running a terminal in minicom in a separate window, although you can use the Arduino 2 IDE edit and terminal of course.
When I make a change I disengage the minicom terminal with a ^A P which brings up the coms parameter window and this permits the coms port to be used by the Arduino uploader.
Then I toggle to the Arduino window and hit ^U to compile and upload.
Once it is done I go back to the minicom window and hit escape to cancel the coms parameter window, and not the terminal is ready to use.

I set minicom to 921600 baud with zero delays and there is an EXTEND.FTH file that I am also using at present.

--------------------------------------------------------------------
NEW:
--------------------------------------------------------------------
DEBUG
* Formatted dumps such as
  DUMP hex plus ASCII
  DUMPW eight 16-bit words/line
  DUMPL eight 32-bit longs/line
  DUMPA 64 ASCII characters/line
  DUMPB ( addr cnt blksiz -- ) - dump memory as a byte/block where the byte is an average
  .L 	Print as 8 digit hex
  .B 	print byte as 2 digit hex
  .L_ print as 8 digit hex 6C00_1400
  .h ( n cnt -- )	Print hex digits
  LAP - capture ms-ticks into lap latch (save old lap)
  .LAP - Print the timing difference between last and previous LAP
  CWORDS - list words in color
    plain = colon defs
    red = immediate
    green = constants/values
    yellow = variables
    magenta =
    blue = unknown
  .WORDS - detail one/line list of words with address etc

NUMBERS
* Allow quoted characters such as '?' as a "number" ( no need for [CHAR] or CHAR )
* Add % as binary number prefix
* Allow , and _ and . within numbers (useful digit group separator) 1,234,567 $6000_C240 etc
   ( careful - _ or ... will produce a 0 :) - tiny bug to fix later )
* Stack retained on errors - it won't reset the stack just because you made a mistake
* .S now prints each item on a new line from top to bottom as hex, ascii, and decimal

CONSOLE
* prompt - only displays fixed size stack depth, base symbol, and arrow. - revector via _prompt
* ANSI colors used to distinguish prompts, user, response, and errors.
    PEN ( n -- ) - set foreground color  black red green yellow blue magenta cyan white
    PAPER ( n -- ) - setbackground color
    PLAIN
    BOLD
    UL
    BLINKING
    REVERSE
    CURSOR ( on/off -- )
    WRAP ( on/off -- )
    HOME
    CLS
    XY ( x y -- )


* Control keys - now you can use control keys for shortcuts and even add your own at runtime
    ^Q Query Stack
    ^S Stack init
    ^W WORDS list
    ^L Clear screen with boot message and reset stack
    ^Z cause an exception - clears EXTEND etc
    See ^ctrl in EXTEND for more options
    Unused control keys are discarded (no errors)
    Use your own custom ctrl keys  - default is ' ^ctrls is ?ctrls
    ( NOTE: moving this to EXTEND for easy edits )

BATCH LOAD
ESP32 - The keyword ESP32 will place the console into non-echo mode only reflecting line numbers and errors.
   - this also ensures that this source file is designed for the ESP32
*END* - ends batch mode and reports download stats.

STRUCTURES
* DO: LOOP: is a very fast do loop with its own loop stack - as fast as for next
  DO: push index and limit and current IP onto loop stack
  LOOP: increment index and loop with saved IP if <> limit - else unloop
  I: loop stack index



AUX STACK
@A ( -- a ) - address of A in A stack
A! ( n -- ) - store n in A (top of A stack)
A ( -- n ) - top of A stack value
>A ( n -- ) - Push n onto A stack
A> ( -- n ) - Pop A stack
PUSHA ( <n> cnt -- ) - push cnt values onto the A stack
POPA ( cnt -- <n> ) - Pop cnt values from the A stack
A@+ ( -- n )  Read long from pointer in A and increment A by 4
AW@+ ( -- n )  Read 16-bit word from pointer in A and increment A by 2
B ( -- n ) - Read B = second A stack item

OPERATORS:
~ ( addr -- )	- clear the cell to zeros
~~ ( addr -- ) - set the cell to ones (-1)
++ ( addr -- ) - increment variable
-- ( addr -- ) - decrement variable
>< ( n min max -- f ) - within inclusive
MASK ( bit -- mask )
[^] - to compile the control key value of an ascii character

FUNCTIONS:
LOOKDOWN ( ch str cnt -- index+1|0 )
LOOKUP ( index str cnt -- byte )
CSIKEY ( -- keycode ) - return with ascii or compressed CSI code
HIGH ( pin -- ) - make the pin an output and set high
LOW ( pin -- ) - make the pin an output and set low
INP ( pin -- ) - make the pin an input
ON ( -- 1 )
OFF ( -- 0 )


KERNEL MODS:
Reassign HIGH and LOW as functions ( simpler and faster )
Added ON and OFF as true and false values ( very general constants )


--------------------------------------------------------------------
CHANGES:
--------------------------------------------------------------------
renamed prompt to eol because it is an end of line action
made eol and prompt revectorable within code for batch loader
renamed ?arrow. to prompt because that is what it is - also _prompt is the variable
added --- separator on the same line when the return is pressed
added stack underflow and reset check (the only time I want it to reset on an error)
add in ANSI colors and apply to console prompts etc and words list
--------------------------------------------------------------------
TO DO:
--------------------------------------------------------------------
Make ?ctrls into a user table of vectors - perhaps in EXTEND
Add escape to cancel the current accept line
Add history buffer to tib - use ^R to recall (or arrow up if CSI keys added)
Check system timer operation


Have fun!
Peter Jakacki


--------------------------------------------------------------------
NOTES:
--------------------------------------------------------------------
Linux users may use the send script from the VSCode terminal
while the minicom terminal window is still active (no need to close etc)
If your ESP32 creates an ACM0 port for instance:
./send EXTEND ACM0 3

where send is
ascii-xfr -s -n -l $3 $1.FTH > /dev/tty$2

minicom color:
Here is a script which I name as tty to easily open a minicom terminal with color etc
minicom --color=on -w -b 921600 -D /dev/tty$1
usage: ./tty ACM0



