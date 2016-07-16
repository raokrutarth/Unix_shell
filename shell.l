
/* 
 * shell.l: lexical analyzer for shell
 */

%{

#include <string.h>
#include "y.tab.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
int debug_md = 0;
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
	if(debug_md)
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
		if(debug_md)
			fprintf(stderr, "*ex=%c new_str=%s\n", *ex, new_str);
    }
	new_str[i]= '\0';
	return new_str;
}
void subshell(char* cmd)
{

}

%}

%%

\n 	{ return NEWLINE; }

[ \t] 	{ /* Discard spaces and tabs */ }	

">>&"   { return GREATGREATAND; }
">>"	{ return GREATGREAT; }
">&"	{ return GREATAND; 	}
">" 	{ return GREAT;	}
"<"		{ return LESS;	}
"|"		{ return PIPE;	}
"&"		{ return AMPERSAND;	}

`[^\n`]*`  {
	char* sub_cmd = strdup(yytext);
	//if(debug_md)
		fprintf(stderr, "sub_cmd=%s\n", sub_cmd);
}

[A-Za-z0-9\-][A-Za-z0-9\-]*  {
	yylval.string_val = strdup(yytext);
	if(debug_md)
		fprintf(stderr,"regular_word=%s\n", yylval.string_val);
	return WORD;
}
[^ \t\n]*(\\[^\s])[^ \t\n]* {
	char* word = strdup(yytext);
	if(debug_md)
		fprintf(stderr, "wordWithBackslash=%s\n", word);
	char* old_word = word;	
	yylval.string_val = stripChar(word, '\\');
	free(old_word);
	return WORD;
}
[^ `\t\n][^ `\t\n]*  {
	
	yylval.string_val = strdup(yytext);
	if(debug_md)
		fprintf(stderr,"Wildcard=%s\n", yylval.string_val);
	return WORD;
}
\"(\\.|[^\"]*)*\"  {
	
	if(debug_md)
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

