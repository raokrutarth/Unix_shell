
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

%type <string_val> pipe_list 
%type <string_val> command_and_args

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
	pipe_list iomodifier_list background NEWLINE 
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
	{
		printf("	Yacc: append output \"%s\"\n", $2);
		//This will not append. It will replace output file data
		Command::_currentCommand._outFile = $2; 
	}
	| GREAT WORD /*redirect stdout to file */
	{
		printf("   Yacc: insert output \"%s\"\n", $2);
		Command::_currentCommand._outFile = $2;
	}
	| GREATGREATAND WORD /*append output to file */
	{
		printf("	Yacc: append error and output \"%s\"\n", $2);
		//This will not append. It will replace output & err file data
		Command::_currentCommand._outFile = $2; 
		Command::_currentCommand._errFile = $2; 
	}
	| GREATAND WORD /* redirect std out and stderr to file */
	{
		printf("	Yacc: insert error and output \"%s\"\n", $2);
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = $2; 
	}
	| LESS WORD /* get input from file */
	{
		printf("	Yacc: insert input: \"%s\"\n", $2);
		Command::_currentCommand._inputFile = $2;
	}
	;

iomodifier_list:
	iomodifier_list iomodifier_opt
	|
	;

pipe_list:
	pipe_list PIPE command_and_args
	{
		printf("	Yacc: pipe"); //    \"%s\" to \"%s\"\n", $1, $2
	}
	| command_and_args
	;
background:
	AMPERSAND
	{
		printf("	Yacc: background: \"%d\"\n", 1);
		Command::_currentCommand._background = 1;
	}
	|
	;

%%

void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

#if 0
main()
{
	yyparse();
}
#endif
