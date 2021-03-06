
/* 
 * shell.l: lexical analyzer for shell
 */

%{

#include <string.h>
#include "y.tab.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio_ext.h>

#define MAX_CMD 2048
extern "C" int debug_mode;
extern "C" char * read_line();

int mygetc(FILE * f) 
{
	static char *p;
	char ch;
	if (!isatty(0))  //not reading from console
		return getc(f);
	if (p==NULL || *p == 0) //reading from console
	{
		char * s = read_line();
		p = s;
	}
	ch = *(p++);
	return ch;
}
#undef getc
#define getc(f) mygetc(f)


static  void yyunput (int c,char *buf_ptr  );
void myunputc(int c) 
{
    unput(c);
}
void removeQts(char* str, char c)
{
	char* dst, *src;
	for( src=dst=str; *src != '\0'; src++)
	{
		*dst=*src;
		if(*dst != c)
			dst++;
	}
	*dst='\0';
}
char* stripChar(char* str, char c)
{
	if(debug_mode)
			fprintf(stderr, "str=%s\n", str);
 	char* new_str = (char*)calloc(strlen(str)+1, sizeof(char) );
	char* ex;
	int i=0;
    for (ex = str; *(ex+1); ex++) 
    {
        if ( *ex==c && *(ex+1)==c ) 
			new_str[i++] = *(ex++);
		else if (*ex==c && *(ex+1)!= c)
			new_str[i++] = *(++ex);
		else if(*ex != c)
			new_str[i++] = *ex;		
		if(debug_mode)
			fprintf(stderr, "[removing \\ in stripChar()] *ex=%c new_str=%s\n", *ex, new_str);
    }
	new_str[i]= '\0';
	return new_str;
}
void subshell(char* cmd)
{
	char* sub_cmd = (char*)calloc(MAX_CMD, sizeof(char));
	char* sp = cmd;
	int i = 0;
	while(*sp)
	{
		if(*sp != '`')
			sub_cmd[i++] = *sp;
		sp++;
	}
	sp=NULL; //dangling pointer fix		
	if(debug_mode)
		fprintf(stderr, "sub_cmd in subshell()=%s\n", sub_cmd);

	int child2parent[2], parent2child[2];
	if(pipe(child2parent) < 0 | pipe(parent2child) < 0 )
	{
		perror("[-] pipe creation in subshell failed\n");
		return;
	}

	int ret = fork();
	if(!ret) //in child
	{
		if(debug_mode)
			fprintf(stderr, "[c] In subshell child with cmd=<%s>\n", sub_cmd);

		dup2(child2parent[1], 1); //stdout to parent
		dup2(parent2child[0], 0); //stdin from parent
		close(child2parent[1]);
		close(parent2child[0]);
		close(child2parent[0]);
		close(parent2child[1]);

		if(debug_mode)
			fprintf(stderr, "[c] child IO redirected\n");		
		_flushlbf(); //flush  buffers
		const char* shell = "/proc/self/exe";
		execvp(shell, NULL);
		fprintf(stderr, "child exec() failed\n");
		_exit(1);
	}
	else //in parent
	{
		close(child2parent[1]);
		close(parent2child[0]);

		if(debug_mode)
			fprintf(stderr, "[p] In subshell parent after stdio redirection\n");

		sp=NULL;		
		sp=sub_cmd;
		while(*sp) //pass the subshell arg to child
		{
			write(parent2child[1], sp, sizeof(char) );
			if(0 & debug_mode)
				fprintf(stderr, "[p] wrote <%c> to pipe\n", *sp);
			sp++;
		}
		if(debug_mode)
			fprintf(stderr, "[p] finished writing command to child input\n");

		const char* end_child = "\nexit\n";
		write(parent2child[1], end_child, strlen(end_child));
		_flushlbf(); //flush writing buffers
		close(parent2child[1]); //finished writing to child

		if(debug_mode)
			fprintf(stderr, "[p] wrote exit to child\n");

		waitpid(ret, NULL, 0); //waiting for child to finish execution
		if(debug_mode)
			fprintf(stderr, "[p] child exited\n");

		char* child_output = (char*)calloc(MAX_CMD*2, sizeof(char) );
		char c;		
		int out_counter=0;
		while( read(child2parent[0], &c, sizeof(char) ) > 0)
		{
			if( out_counter > (MAX_CMD*2) )
			{
				perror("[-] subshell output overflow\n");
				return;
			}
			if(0 & debug_mode)
				fprintf(stderr, "[p] read <%c> from child\n", c);
			child_output[out_counter++] = c;
		}
		close(child2parent[0]); //finished reading from child

		if(debug_mode)
			fprintf(stderr, "[p0] child_output=%s", child_output);
		
		out_counter -= 1;
		while(out_counter >=0 )
		{
			char kl = child_output[out_counter--];
			if(kl == '\n')
				myunputc( ' ');
			else
				myunputc(kl);
		}
		return;
	}
}

%}

%%

\n 	{ 	
	//perror("newline dectected\n"); 
	return NEWLINE; }

[ \t] 	{ /* Discard spaces and tabs */ }	

">>&"   { return GREATGREATAND; }
">>"	{ return GREATGREAT; }
">&"	{ return GREATAND; 	}
">" 	{ return GREAT;	}
"<"		{ return LESS;	}
"|"		{ return PIPE;	}
"&"		{ return AMPERSAND;	}

`[^\n\t`]*`  {
	char* sub_cmd = strdup(yytext);
	if(debug_mode)
		fprintf(stderr, "sub_cmd=%s\n", sub_cmd);
	subshell(sub_cmd);
}

[A-Za-z0-9\-][A-Za-z0-9\-]*  {
	yylval.string_val = strdup(yytext);
	if(debug_mode)
		fprintf(stderr,"regular_word=%s\n", yylval.string_val);
	return WORD;
}
[^ \t\n]*(\\[^\s])[^ \t\n]* {
	char* word = strdup(yytext);
	if(debug_mode)
		fprintf(stderr, "wordWithBackslash=%s\n", word);
	char* old_word = word;	
	yylval.string_val = stripChar(word, '\\');
	free(old_word);
	return WORD;
}
[^ `\t\n|<&>][^ `\t\n|<&>]*  {
	
	yylval.string_val = strdup(yytext);
	if(debug_mode)
		fprintf(stderr,"Wildcard=%s\n", yylval.string_val);
	return WORD;
}
\"(\\.|[^\"]*)*\"  {
	
	if(debug_mode)
		fprintf(stderr,"in quote stripper\n");
	char* word = strdup(yytext);
	removeQts(word, '"');	
	yylval.string_val = word;
	return WORD;
}
. { 
	perror("[-] notoken invoked in lex file\n");
	return NOTOKEN;	 
}
%%

