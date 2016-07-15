
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
	int debug_mode = 0;

	int compare_funct(const void *str1, const void *str2) 
	{ 
		const char **ia = (const char **)str1;
		const char **ib = (const char **)str2;
		return strcmp(*ia, *ib);
	} 		
	void stripAllBackslash(char* str)
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
	}
	void removeLeadingBackslash(char* str)
	{
		char *ps;
		for( ps = str; *ps != '\0'; ps++)
    		*ps = *(ps+1);
		*ps = '\0';
	}
	char* wildcardToRegex(char* arg)
	{
		//create space for regular expression
		char* reg = (char*)calloc( 2*strlen(arg)+10, sizeof(char) ); 
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
		r = a = 0;
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
		//[eg] expandWildcard("", "/u*/*")
		if (!suffix[0] ) 
		{ 
			// suffix is empty. Put prefix in argument.
			char* toAdd = strdup(prefix);
			removeLeadingBackslash(toAdd);
			addToArgArray(toAdd);			
			return;
		} 		 
		// Obtain the next component in the suffix 
		// Also advance suffix.		
		char* slash = strchr(suffix, '/'); 
		char* component = (char*)calloc(MAXFILENAME, sizeof(char)); 
		if (slash!=NULL)
		{ 
			// Copy up to the first "/"
			//[eg] component = ""
			strncpy(component,suffix, slash-suffix); 
			//[eg] suffix = u*/*
			suffix = slash + 1; 
		} 
		else 
		{ 
			// Last part of path. Copy whole thing. 
			strncpy(component, suffix, strlen(suffix) ); 
			suffix = suffix + strlen(suffix); //suffix = 0??
			if(debug_mode)
				fprintf(stderr, "[EMT_S] prefix=%s   component=%s   suffix=%s\n" ,prefix, component, suffix);
		}		
		// Now we need to expand the component char 	
		char* newPrefix = (char*)calloc(MAXFILENAME, sizeof(char) ); 
		char* star = strchr(component, '*');
		char* qst = strchr(component, '?');	
		if( !star && !qst ) 
		{
			// component does not have wildcards 
			//if( prefix[0] == '/')
			//	sprintf(newPrefix,"%s/%s", prefix, component);
			//else
			sprintf(newPrefix,"%s/%s", prefix, component);
			if(debug_mode)
				fprintf(stderr, "[FST] prefix=%s   component=%s   newPrefix=%s   suffix=%s\n",
			  		prefix, component, newPrefix, suffix);						
			expandWildcard(newPrefix, suffix); 
			return;
		}
		//Component has wildcards 
		//Convert component to regular expression
		char* old_cmp = component;
		component = wildcardToRegex(component);
		free(old_cmp);
		regex_t re; 
		//[eg] compile * as a regex
		int expbuf = regcomp( &re, component, REG_EXTENDED|REG_NOSUB);
		char* dir; 
		// If prefix is empty then list current directory 
		const char* currentDir = ".";
		if (prefix[0] == 0) 
			dir = (char*)currentDir; 
		else 
			dir=prefix;
		if(debug_mode)
			fprintf(stderr, "[AFT_DR] prefix = %s\n", prefix);
			
		DIR * d=opendir(dir); 
		if (d==NULL && strlen(prefix) > 0)
		{
			//tried to open /x but failed
			//try to open x as a directory
			char* dir2 = strdup(prefix+1);
			d=opendir(dir2);
			if(!d)
				return; //no directory present in current call
		} 			
		// check what entries match 
		struct dirent *ent;		
		regmatch_t match;
		while( (ent=readdir(d)) != NULL )
		{
			char * dir_name = strdup(ent->d_name);						
			if (regexec( &re, dir_name, 1, &match, 0 ) == 0 )
			{
				if(dir_name[0] == '.' &&component[2] != '.' )
				 	continue;
				if(debug_mode)
					fprintf(stderr, "[RGX_S] dir=%s   ent_name=%s   prefix=%s   component=%s"   
						"newPrefix=%s   suffix=%s\n", dir,  dir_name, 
							prefix,component, newPrefix, suffix);			
				sprintf(newPrefix,"%s/%s", prefix, dir_name);
				if(debug_mode)
					fprintf(stderr, "[RGX_E] suffix=%s   ent_name=%s  newPrefix=%s\n\n", 
						suffix, dir_name , newPrefix);
				expandWildcard(newPrefix,suffix); 
			}
			free(dir_name);
		}
		closedir(d);
		regfree(&re);	
	}
	char* replaceTld(char* path, char* location)
	{
		char * default_home = strdup(getenv("HOME"));
		location++;
		//char *ch = strstr(path, "~");
		if(debug_mode)
			fprintf(stderr, "[1a] path=%s\n", path);
		if(*location && *location != '/') //in case where ~uname/etc
		{
			char* diff_usr = (char*)calloc(MAXFILENAME, sizeof(char) );
			if(debug_mode)
				fprintf(stderr, "[1b] path=%s diff_usr=%s\n", path, diff_usr);
			char* backslash = strchr(path, '/');
			if(!backslash)
				backslash = strchr(path, '\0');	
			// copy uname
			strncat(diff_usr, location, backslash-path-1);
			if(debug_mode)
				fprintf(stderr, "[2] path=%s diff_usr=%s\n", path, diff_usr);

			char* usr_home = strdup( getpwnam(diff_usr)->pw_dir);
			free(diff_usr);
			if(!(*backslash))
				return usr_home; //returns value for just ~uname
			char * full_path = (char*) calloc(MAXFILENAME*2, sizeof(char) );	
			int cpy_len = backslash-path;
			//add path for ~uname	
			strncat(full_path, usr_home, strlen(usr_home));
			//add everything after "/" i.e /etc
			strncat(full_path, backslash, sizeof(full_path) );
			if(debug_mode)
				fprintf(stderr, "[3] full_path=%s\n", full_path); 
			free(usr_home);
			return full_path;
		}
		char * full_path = (char*) calloc(MAXFILENAME*2, sizeof(char));
		const char* tld = "~";		
		strncat(full_path, path, location-path);  
		//full_path[ch-path] = 0;
		sprintf(full_path+(location-path), "%s%s", default_home, location+strlen(tld));		
		return full_path;
	}
	char* replaceWithEnv(char* arg)
	{
		char* withBraces = arg;
		char* envt_var = (char*)calloc(MAXFILENAME, sizeof(char));
		int i =0;
		while(*withBraces)
		{
			if( *withBraces != '$' && *withBraces != '{' && *withBraces != '}')
				envt_var[i++] = *withBraces;
			if(*withBraces == '}')
				break;
			withBraces++;
		}
		if(debug_mode)
			fprintf(stderr, "envt_var=%s\n", envt_var);
		char * envt_var_val = strdup(getenv(envt_var));
		return 	envt_var_val;
	}
	void expandWildcardCaller(char * arg)
	{
		if(debug_mode)
			fprintf(stderr, "[START_OF_WCCALLER] arg=%s", arg);
		char* star = strchr(arg, '*');
		char* qst = strchr(arg, '?');
		char* tld = strchr(arg, '~');
		char* env_expand = strstr(arg, "${");
		if(tld)
		{
			char * path = strdup(arg);
			arg = replaceTld( path, tld );
		}
		while(env_expand)
		{
			char* envt_end = strstr(arg, "}");
			char* envt_var = replaceWithEnv(env_expand);
			if(!envt_var)
			{
				perror("invalid variable requested!\nUsage:${<var>}\n");
				return;
			}
			char* new_arg = (char*)calloc(MAXFILENAME, sizeof(char));
			strncat(new_arg, arg, env_expand-arg); //concat till the env starts
			strncat(new_arg, envt_var, strlen(envt_var)); //concat the envt_var
			strcat(new_arg, envt_end+1 ); //cat rest of the arg
			char* old_arg = arg;
			arg = new_arg;
			free(old_arg);
			free(envt_var);
			env_expand = strstr(arg, "${");
		}				
		if( !star && !qst) 
		{
			Command::_currentSimpleCommand->insertArgument(arg); 
			return;
		}
		maxEntries = 30, nEntries = 0;
		unsortedArgs = (char**) malloc( maxEntries*sizeof(char*) );
		const char* initial_prefix = "";
		expandWildcard( (char*)initial_prefix, arg);
		assert(unsortedArgs != NULL);
		qsort(unsortedArgs, nEntries, sizeof(char *), compare_funct);
		for (int i = 0; i < nEntries; i++)
		{
			Command::_currentSimpleCommand->insertArgument( strdup(unsortedArgs[i]) );
			free(unsortedArgs[i]);
		} 			
		nEntries = 0;
		free(unsortedArgs);
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
		//Valgrind: invalid read
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
		expandWildcardCaller($1);
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
