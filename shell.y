
/*
 * CS-252 Summer 2016
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * You must extend it to: 
 *
 * cmd [arg]* [ | cmd [arg]* ]* [ [> filename] [< filename] [ >& filename] [>> filename] [>>& filename] ]* [&]
 *
 */

%token	<string_val> WORD

%token 	NOTOKEN GREAT NEWLINE LESS GREATGREAT GREATAND PIPE AMPERSAND GREATGREATAND

%union	{ char   *string_val;	}

%{
	//#define yylex yylex
	#include <stdio.h>
	#include "command.h"
	void yyerror(const char * s);
	int yylex();
%}

%%

goal:	
	commands
	;

commands: 
	command
	| commands command 
	;

command: 
	simple_command
    ;

simple_command:	
	command_and_args iomodifier_opt NEWLINE 
	{
		printf("   Yacc: Execute command\n");
		Command::_currentCommand.execute();
	}
	| NEWLINE 
	| error NEWLINE { yyerrok; }
	;

command_and_args:
	command_word arg_list { Command::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand ); }
	;

arg_list:
	arg_list argument
	| /* empty */
	;

argument:
	WORD 
	{
        printf("   Yacc: insert argument \"%s\"\n", $1);
        Command::_currentSimpleCommand->insertArgument( $1 );\
	}
	;

command_word:
	WORD 
	{
		printf("   Yacc: insert command \"%s\"\n", $1);	       
	    Command::_currentSimpleCommand = new SimpleCommand();
	    Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

iomodifier_opt:
	GREATGREAT WORD
	| GREAT WORD 
	{
		printf("   Yacc: insert output \"%s\"\n", $2);
		Command::_currentCommand._outFile = $2;
	}
	| GREATGREATAND WORD
	| GREATAND WORD
	| LESS WORD 
	;

iomodifier_list:
	iomodifier_list iomodifier_opt
	|
	;

pipe_list:
	pipe_list PIPE command_and_args
	|	command_and_args
	;
background:
	AMPERSAND
	|
	;

%%

void
yyerror(const char * s)
{
	s = "pp";
	fprintf(stderr,"%s", s);
}

#if 0
main()
{
	yyparse();
}
#endif
