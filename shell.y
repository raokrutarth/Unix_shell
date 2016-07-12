
/*
 * CS-252 
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
	#include <string>
	#include <stdio.h>
	#include <pwd.h>
	#define MAXFILENAME 1024
	void yyerror(const char * s);
	int yylex();
	int maxEntries, nEntries;
	char** unsortedArgs;
	char* dir;

	int compare_funct(const void *str1, const void *str2) 
	{ 
		const char **ia = (const char **)str1;
		const char **ib = (const char **)str2;
		return strcmp(*ia, *ib);
	} 
	char* removeTld(char *path, char* location) //location = s
	{
		char * replaceWith = getenv("HOME");
		location++;
		if(*location && *location != '/')
		{
			char diff_usr[1024];
			char* bs = strchr(path, '/');
			if(!bs)
				bs = strchr(path, '\0');	
			strncpy(diff_usr, path+1, bs-path-1);
			replaceWith = strdup( getpwnam(diff_usr)->pw_dir);
			return replaceWith;
		}
		char * full_path = (char*) malloc(1024);
		const char* tld = "~";
		char *ch;
		ch = strstr(path, "~");
		strncpy(full_path, path, ch-path);  
		full_path[ch-path] = 0;
		sprintf(full_path+(ch-path), "%s/%s", replaceWith, ch+strlen(tld));
		return full_path;
	}	
	/*void stripBackslash(char* str)
	{
		char *src, *dst;
		char qt = '/';
		for (src = dst = str; *src != '\0'; src++) 
		{
			*dst = *src;
			if (*dst != qt) 
				dst++;
		}
		*dst = '\0';
	}*/
	void stripBackslash2(char* str)
	{
		char *ps;
		for( ps = str; *ps != '\0'; ps++)
    		*ps = *(ps+1);
		*ps = '\0';
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
	void addToArgArray(char * entry)
	{
		if(nEntries == maxEntries)
		{
			maxEntries*=2;
			unsortedArgs = (char**)realloc( unsortedArgs, maxEntries*sizeof(char*) );
			assert(unsortedArgs != NULL);
		}		
		unsortedArgs[nEntries++] = entry;	
	}
	void expandWildcard(char * prefix, char *suffix) //called expandWildcard("", wildcard)
	{ 
		if (!suffix[0] ) 
		{ 
			// suffix is empty. Put prefix in argument.
			char* nm = strdup(prefix);
			//stripBackslash2(nm);
			Command::_currentSimpleCommand->insertArgument( nm );			
			return;
		} 		 
		// Obtain the next component in the suffix 
		// Also advance suffix.		
		char * s = strchr(suffix, '/'); 
		char* component = (char*)calloc(MAXFILENAME, sizeof(char)); 
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
			fprintf(stderr, "[EMT_S]   prefix=%s   component=%s   suffix=%s\n" ,prefix, component, suffix);

		}
		
		// Now we need to expand the component char 	
		char newPrefix[MAXFILENAME] = {0}; 
		char* star = strchr(component, '*');
		char* qst = strchr(component, '?');	
		if( !star && !qst ) 
		{
			// component does not have wildcards 
			//if( prefix[0] == '/')
			//	sprintf(newPrefix,"%s/%s", prefix, component);
			//else
				 sprintf(newPrefix,"%s/%s", prefix, component);
		  		 fprintf(stderr, "[FST]   prefix=%s   component=%s   newPrefix=%s   suffix=%s\n" ,prefix, component, newPrefix, suffix);
			
			expandWildcard(newPrefix, suffix); 
			return;
		}
		//Component has wildcards 
		//Convert component to regular expression
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
		regmatch_t match;
		while( (ent=readdir(d)) != NULL )
		{
			if(ent->d_name[0] == '.')
				continue;			
			if (regexec( &re, ent->d_name, 1, &match, 0 ) == 0 )
			{
				fprintf(stderr, "[+] dir=%s   ent_name=%s   prefix=%s   component=%s   newPrefix=%s   suffix=%s\n",dir,  ent->d_name, prefix,component, newPrefix, suffix);
			
				char * match_name = strdup(prefix);
				match_name = (char*)realloc( match_name, MAXFILENAME );
				if( strcmp(dir, ".") ) //not current dir
					strcat(match_name, "/");
				strcat(match_name, ent->d_name);
				//addToArgArray(match_name);
				//if( prefix[0] == '/')
				//	sprintf(newPrefix,"%s%s", prefix, ent->d_name);
				//else
					sprintf(newPrefix,"%s/%s", prefix, ent->d_name);
				fprintf(stderr, "[-]   suffix=%s   ent_name=%s  newPrefix=%s\n\n", suffix, ent->d_name , newPrefix);

				expandWildcard(newPrefix,suffix); 
			}
		}
		closedir(d);
		regfree(&re);	
	}
	void expandWildcard2(char * arg)
	{
		char* star = strchr(arg, '*');
		char* qst = strchr(arg, '?');	
		if( !star && !qst) 
		{
			Command::_currentSimpleCommand->insertArgument(arg); 
			return;
		}
		maxEntries = 30, nEntries = 0;
		unsortedArgs = (char**) malloc( maxEntries*sizeof(char*) );
		const char* initial_prefix = "";
		expandWildcard( (char*)initial_prefix, arg);

		qsort(Command::_currentSimpleCommand->_arguments, nEntries, sizeof(char *), compare_funct);
		/*for (int i = 0; i < nEntries; i++)
		{
			//Command::_currentSimpleCommand->insertArgument( strdup(unsortedArgs[i]) );
			free(unsortedArgs[i]);
		} 			
		nEntries = 0;
		free(unsortedArgs);*/
	}

	void checkWildCard(char * arg)
	{
		char* star = strchr(arg, '*');
		char* qst = strchr(arg, '?');
		char* tld = strchr(arg, '~');
		if( !star && !qst ) // * or ? not present in argument
		{
			if(tld)
				arg = removeTld(arg, tld);
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
		char** unsortedArgs = (char**) malloc( maxEntries*sizeof(char*) );
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
					unsortedArgs = (char**)realloc( unsortedArgs, maxEntries*sizeof(char*) );
					assert(unsortedArgs != NULL);
				}
				unsortedArgs[nEntries++] = strdup(ent->d_name);
			}
		}
		closedir(dir);
		qsort(unsortedArgs, nEntries, sizeof(char *), compare_funct);
		for (int i = 0; i < nEntries; i++) 
			Command::_currentSimpleCommand->insertArgument( unsortedArgs[i] );
		free(unsortedArgs);	
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
		expandWildcard2($1);
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
