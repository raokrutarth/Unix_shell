
/*
 *
 * CS-252
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"
int debug_md = 1;
static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}
void stripChar(char* str, char c)
{
 	char* new_str = (char*)calloc(strlen(str)+1, 0);
	char* ex;
	int i=0;
    for (ex = str; *(ex+1); ex++) 
    {
        if ( (*ex==c && *(ex+1)==c) ) 
			new_str[i++] = *ex;
		else if (*ex != c)
			new_str[i++] = *ex;		
		if(debug_md)
			fprintf(stderr, "*ex=%c *new_str[i]=%c\n", *ex, new_str[i]);
    }
	new_str[i]= '\0';
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


[A-Za-z0-9\-][A-Za-z0-9\-]*  {
	yylval.string_val = strdup(yytext);
	//fprintf(stderr,"in regular word\n");
	return WORD;
}
[^ \t\n]*(\\[^\s])[^ \t\n]* {
	char* word = strdup(yytext);
	//fprintf(stderr, "word=%s\n", word);
	stripChar(word, '\\');
	yylval.string_val = word;
	return WORD;
}
[^ \t\n|\>\<\>>\>&\>>&][^ \t\n|\>\<\>>\>&\>>&]*  {
	
	yylval.string_val = strdup(yytext);
	//fprintf(stderr,"in regular word\n");
	return WORD;
}
\"(\\.|[^\\"])*\"  {
	//fprintf(stderr,"in quote stripper\n");
	char* word = strdup(yytext);
	stripChar(word, '"');
	yylval.string_val = word;
	return WORD;
}

. { 
	perror("notoken invoked");
	return NOTOKEN;	 
}
%%

