# UNIX compatible shell - k_shell #

__A shell implemented in C/C++. Intended to obtain a better understanding of:__

+ UNIX CLI
+ Process creation and handeling
+ Lex
+ Yacc

***
# Project layout #
**Makefile:** run "make" in and it  will create an executable called "shell"
	**cat_grep.cc** : A C program to create an executable that works like "cat file | grep word > outfile"
	**command.cc** : C++ class implementation for a command in the shell. Also holds the main method
	**command.h** : guess
	**ks** : Bash script to kill all instances of the shell in case of shell hanging. Debugging tool
	**read-line.c** : C implementation for the line editor for the shell
	**regular.cc** : test program to use regexec
	**shell.l** : Lex file. Also includes implementation for subshell
	**shell.y** : Yacc file. Also includes wildcard implementation
	**tty-raw-mode.c** : helper for line editor
	**printErr.c** : program to test read/write IO

***

# Working features (somewhat similar to csh) #
- IO Redirection between commands
- Pipes between commands
- Background and Zombie process handling
- Environment vairables
- Words and special chars
- cd command
- Wildcarding
- Quotes and escape chars
- Ctrl-C handeling (exit command) 
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


# TODO (For the motivated) #
- Line editor
	+ history (unstable. history is recorded correctly.
		set if(...) statement to if(1) in read-line.c:164 to see recorded history )


