# UNIX compatible shell

__A shell implemented in C/C++. Intended to obtain a better understanding of:__

+ UNIX CLI
+ Process creation and handeling
+ Lex
+ Yacc

***

# Working features #
- IO Redirection between commands
- Pipes between commands
- Background and Zombie process handling
- Environment vairables
- Words and special chars
- cd command
- Wildcarding
- Quotes and escape chars
- Ctrl-C
- Robustness (limiting the no. of crashes)
- subshell
- tilde expansion
- Line editor
- left
	* right
	* backspace
	* home
	* end
	* Ctrl+?
	* Ctrl+e
	* Ctrl+a
	* Ctrl+d
	* del

# Extra features #
- "debug" command : enter "debug on" and see dubugging information for the shell.
- Line editor
	+ Ctrl+l : clears current line
	+ ks : (debugging tool) bash script to kill all instances of the shell if it hangs


# Not working #
- Line editor
	+ history (unstable. history is recorded correctly.
		set if(...) statement to if(1) in read-line.c:164 to see recorded history )


