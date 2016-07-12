
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
	#include <stdlib.h>
	#include "command.h"
	#include <sys/types.h>
    #include <regex.h>
	#include <string.h>
	#include <dirent.h>
	#include <unistd.h>
	#include <stddef.h>
	#include <assert.h>
	#define MAXFILENAME 1024
	void yyerror(const char * s);
	int yylex();

	int compare_funct(const void *str1, const void *str2) 
	{ 
		const char **ia = (const char **)str1;
		const char **ib = (const char **)str2;
		return strcmp(*ia, *ib);
	} 
	char* removeTld(char *st) 
	{
		const char* tld = "~";
		char * repl = getenv("HOME");
		char * buffer = (char*) malloc(1024);
		char *ch;
		ch = strstr(st, tld);
		strncpy(buffer, st, ch-st);  
		buffer[ch-st] = 0;
		sprintf(buffer+(ch-st), "%s/%s", repl, ch+strlen(tld));
		return buffer;
	}	
	void stripBsl(char* str, char c)
	{
		char *src, *dst;
		char qt = c;
		for (src = dst = str; *src != '\0'; src++) 
		{
			*dst = *src;
			if (*dst != qt) 
				dst++;
		}
		*dst = '\0';
	}
	char* wildcardToRegex(char* arg)
	{
		//create space for regular expression
		char* reg = (char*)malloc( 2*strlen(arg)+10 ); 
		char* a = arg; // a= start of argument
		char* r = reg; //r= start of allocated space
		*(r++) = '^'; //denote beginning of regex
		while(*a) //go till end of argument
		{
			if (*a == '*') // * becomes .*
				{ *r='.'; r++; *r='*'; r++; }
			else if (*a == '?' ) // ? becomes .
				{*r= '.'; r++; }
			else if (*a == '.') // . becomes \.
				{*r= '\\'; r++; *r='.'; r++; }
			else 
				{*r = *a; r++; }
			a++;
		}
		*(r++)='$'; *r = 0; // mark end of string
		return reg;
	}
	void expandWildcard(char * prefix, char *suffix) //called expandWildcard("", wildcard)
	{ 
		if (suffix[0]== 0) 
		{ 
			// suffix is empty. Put prefix in argument. 
			Command::_currentSimpleCommand->insertArgument(strdup(prefix));
			return;
		} 
		// Obtain the next component in the suffix 
		// Also advance suffix.
		char * s = strchr(suffix, '/'); 
		char* component = (char*)malloc(MAXFILENAME*sizeof(char)); 
		if (s!=NULL)
		{ 
			// Copy up to the first "/" 
			strncpy(component,suffix, s-suffix); 
			suffix = s + 1; 
		} 
		else 
		{ 
			// Last part of path. Copy whole thing. 
			strcpy(component, suffix); 
			suffix = suffix + strlen(suffix); 
		}
		// Now we need to expand the component char 
		char* star = strchr(component, '*');
		char* qst = strchr(component, '?');		
		char newPrefix[MAXFILENAME]; 
		if( !star && !qst ) 
		{
			// component does not have wildcards 
			sprintf(newPrefix,"%s/%s", prefix, component); 
			expandWildcard(newPrefix, suffix); 
			return;
		} 
		// Component has wildcards 
		// Convert component to regular expression
		component = wildcardToRegex(component);
		regex_t re; 
		int expbuf = regcomp( &re, component, REG_EXTENDED|REG_NOSUB);
		char* dir; 
		// If prefix is empty then list current directory 
		const char* currentDir = ".";
		if (prefix[0] == 0) 
			dir = (char*)currentDir; 
		else 
			dir=prefix; 
		DIR * d=opendir(dir); 
		if (d==NULL) 
			return;
		// Now we need to check what entries match 
		struct dirent *ent;
		int maxEntries = 30;
		int nEntries = 0;
		char** array = (char**) malloc( maxEntries*sizeof(char*) );
		regmatch_t match;
		while( (ent=readdir(d)) != NULL )
		{
			if(ent->d_name[0] == '.')
				continue;
			if (regexec( &re, prefix, 1, &match, 0 ) == 0 )
			{
				if(nEntries == maxEntries)
				{
					maxEntries*=2;
					array = (char**)realloc( array, maxEntries*sizeof(char*) );
					assert(array != NULL);
				}
				char* path_name = strdup(prefix);
				stripBsl(path_name, '/');
				array[nEntries++] = ent->d_name;
				sprintf(newPrefix,"%s/%s", prefix, ent->d_name); 
				expandWildcard(newPrefix,suffix); 
			}
		}
		closedir(d);
		qsort(array, nEntries, sizeof(char *), compare_funct);
		for (int i = 0; i < nEntries; i++) 
			Command::_currentSimpleCommand->insertArgument( array[i] );
		free(array);	
		regfree(&re);	
	}

	void checkWildCard(char * arg)
	{
		char* star = strchr(arg, '*');
		char* qst = strchr(arg, '?');
		char* tld = strchr(arg, '~');
		if( !star && !qst ) // * or ? not present in argument
		{
			if(tld)
				arg = removeTld(arg);
			Command::_currentSimpleCommand->insertArgument( arg );
			return;
		}
		char* reg = wildcardToRegex(arg);
		regex_t temp; //needed to use regcomp
		int expbuf = regcomp( &temp, reg, REG_EXTENDED|REG_NOSUB);
		if(expbuf){ perror("regcomp failed\n"); return; }

		DIR* dir = opendir(".");
		if(!dir){ perror("open dir failed"); return; }

		struct dirent *ent;
		int maxEntries = 30;
		int nEntries = 0;
		char** array = (char**) malloc( maxEntries*sizeof(char*) );
		regmatch_t match;
		while( (ent=readdir(dir)) != NULL )
		{
			if(ent->d_name[0] == '.')
				continue;
			if (regexec( &temp, ent->d_name, 1, &match, 0 ) == 0 )
			{
				if(nEntries == maxEntries)
				{
					maxEntries*=2;
					array = (char**)realloc( array, maxEntries*sizeof(char*) );
					assert(array != NULL);
				}
				array[nEntries++] = strdup(ent->d_name);
			}
		}
		closedir(dir);
		qsort(array, nEntries, sizeof(char *), compare_funct);
		for (int i = 0; i < nEntries; i++) 
			Command::_currentSimpleCommand->insertArgument( array[i] );
		free(array);	
		regfree(&temp);	
	}
	
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
	pipe_list iomodifier_list background NEWLINE 
	{
		//printf("   Yacc: Execute command\n");
		Command::_currentCommand.execute();
	}
	| NEWLINE 
	{
		  Command::_currentCommand.prompt();
	}
	| error NEWLINE { yyerrok; }
	;

command_and_args:
	command_word arg_list 
	{ 
		Command::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand ); 
	}
	;

arg_list:
	arg_list argument
	| /* no arguments */
	;

argument:
	WORD 
	{
        //printf("   Yacc: insert argument \"%s\"\n", $1);
        //Command::_currentSimpleCommand->insertArgument( $1 );
		//checkWildCard($1);
		const char* initial_prefix = "";
		expandWildcard( (char*)initial_prefix, $1);
	}
	;

command_word:
	WORD 
	{
		//printf("   Yacc: insert command \"%s\"\n", $1);	       
	    Command::_currentSimpleCommand = new SimpleCommand();
	    Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

iomodifier_opt:
	GREATGREATAND WORD /*append output to file */
	{
		//printf("   Yacc: append error and output \"%s\"\n", $2);
		//This will not append. It will replace output & err file data
		Command::_currentCommand._outFile = $2; 
		Command::_currentCommand._errFile = $2;
		Command::_currentCommand._append = 1; 
	}
	| GREATGREAT WORD
	{
		//printf("   Yacc: append output \"%s\"\n", $2);
		//This will not append. It will replace output file data
		Command::_currentCommand._outFile = $2; 
		Command::_currentCommand._append = 1;
	}
	| GREATAND WORD /* redirect std out and stderr to file */
	{
		//printf("   Yacc: insert error and output \"%s\"\n", $2);
		if( Command::_currentCommand._outFile )
			fprintf(stdout, "Ambiguous output redirect\n");
		else
		{
			Command::_currentCommand._outFile = $2;
			Command::_currentCommand._errFile = $2; 
		}		
	}
	| GREAT WORD /*redirect stdout to file */
	{
		//printf("   Yacc: insert output \"%s\"\n", $2);
		if( Command::_currentCommand._outFile )
			printf("Ambiguous output redirect");
		else
			Command::_currentCommand._outFile = $2; 
	}
	| LESS WORD /* get input from file */
	{
		//printf("   Yacc: insert input: \"%s\"\n", $2);
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
		//printf("   Yacc: pipe\n"); //    \"%s\" to \"%s\"\n", $1, $2
	}
	| command_and_args
	;
background:
	AMPERSAND
	{
		//printf("   Yacc: background: \"%d\"\n", 1);
		Command::_currentCommand._background = 1;
	}
	|
	;

%%

void yyerror(const char * s)
{
	//fprintf(stderr,"%s", s);
}

#if 0
main()
{
	yyparse();
}
#endif
