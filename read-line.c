/*
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define MAX_BUFFER_LINE 2048
#define BACKSPACE 8
#define ESC 27

extern int debug_mode;

int line_length;
char line_buffer[MAX_BUFFER_LINE];
int history_index = 0;
char* history[30];
int history_length = sizeof(history)/sizeof(char *);
int position = 0;

void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?   :    Print usage\n"
    " Backspace :   Deletes last character\n"
    " up arrow   :  See last command in the history\n"
    " left arrow  key : Move the cursor to the left and allow insertion at " 
      "\tthat position. If the cursor is at the beginning of the line it does nothing.\n"
    " right arrow key: Move the cursor to the right and allow insertion at that position. "
      "\tIf the cursor is at the end  of the line it does nothing.\n"
    " delete key(ctrl-D): clear current line\n"
    " backspace (ctrl-H)key: Removes the character at the position before the cursor. "
      "\tThe characters in the right side are shifted to the left.\n"
    " Home key (or ctrl-A): The cursor moves to the beginning of the line\n"
    " End key (or ctrl-E): The cursor moves to the end of the line\n";
  write(1, usage, strlen(usage));
}

void clear_line() //clears current console line
{
    if(line_length > 0)
    {
        // Print backspaces
        if(position != line_length-1) // go to end of line
        {
        	int index = position;
            if(index < line_length && index > 0)
            {
                while(index != line_length && index > 0 )
                {
                    char ch = line_buffer[index];
                    write(1, &ch, 1);
                    index++;
                }
            } 
        }
        int i = 0;
        char ch;
        for (; i < line_length; i++) 
        {
            ch = BACKSPACE;
            write(1,&ch,1);
        }
        // Print spaces on top
        for (i =0; i < line_length; i++) 
        {
            ch = ' ';
            write(1,&ch,1);
        }
        // Print backspaces
        for (i =0; i < line_length; i++) 
        {
            ch = BACKSPACE;
            write(1,&ch,1);
        }
    }    
}
void delete_current_char()
{
	int i, k; 
	char ch;          
    if( position >= 0 && position < line_length)
    {
        clear_line();
        // modify line_buffer
        char new_line[MAX_BUFFER_LINE] = {0};
        
        if(debug_mode)
			fprintf(stderr, "position=%d\n", position);
			
        for(i = 0, k = 0; i < line_length; i++, k++)
		{
		 	if( i == position)
		 		new_line[k] = line_buffer[++i];
		 	else
		 		new_line[k] = line_buffer[i];
		}
		line_length--;
		//if(position > 0)
		//	position--;
		
		if(debug_mode)
			fprintf(stderr, "line_buff=%s\n", line_buffer);
			
		strncpy(line_buffer, new_line, strlen(new_line));
		line_buffer[line_length] = '\0';
		
		if(1 | debug_mode)
		{
			fprintf(stderr, "new_line=%s\n", new_line);
			fprintf(stderr, "line_buffer=%s\n", line_buffer);			
		}
			
			
        write(1, line_buffer, line_length);
        // reset cursor
        i = line_length - position;
  /*      while(i--)
        {
            ch = BACKSPACE;
            write(1, &ch, 1);
        }*/
    }
}
char * read_line() 
{
    int itr;
    if(debug_mode)
		for(itr = history_index; itr > 0; itr--)
      		fprintf(stderr, "\nhistory[%d]=%s", itr, history[itr]);

    // Set terminal in raw mode
    tty_raw_mode();
    line_length = 0;
    while (1) 
    {
      // Read one character in raw mode.
        char ch;
        read(0, &ch, 1);
        if (ch>=32 && ch != ESC && ch < 127 ) 
        {
            // It is a printable character. display it back
            write(1,&ch,1);
            // If max number of character reached return.
            if (line_length==MAX_BUFFER_LINE-2) 
              break; 
            // add char to buffer.
            line_buffer[line_length]=ch;
            line_length++;
            position++;
        }
        else if (ch==10) 
        {
            // <Enter> was typed. Return line. print newline
            write(1,&ch,1);
            break;
        }
        else if (ch == 31) 
        {
            // ctrl-?
            read_line_print_usage();
            line_buffer[0]=0;
            break;
        }
        else if (ch == BACKSPACE || ch==127) 
        {
            if(line_length>0)
            {
                // <backspace> or ctrl-H was typed. Remove previous character read.
                // Go back one character
                ch = BACKSPACE;
                write(1,&ch,1);
                // Write a space to erase the last character read
                ch = ' ';
                write(1,&ch,1);
                // Go back one character
                ch = BACKSPACE;
                write(1,&ch,1);
                // Remove one character from buffer
                line_length--;
                position--;
            }            
        }
        else if(ch == 4)
        {
            /* ctrl-D:  Removes the character at the cursor. 
               The characters in the right side are shifted to the left. */
            delete_current_char();                         
        }
        else if(ch == 1)
        {
            /*Home key (or ctrl-A): The cursor moves to the beginning of the line */
            if(position != 0 && position < line_length+1 && position > 0)
            {
                while(position != 0 )
                {
                    ch = BACKSPACE;
                    write(1, &ch, 1);
                    position--;
                }
            } 
        }
        else if(ch == 12)
        {
            /* Clear line (or ctrl-l): clear current line */
            clear_line();
        }
        else if(ch==5)
        {
            /*End key (or ctrl-E): The cursor moves to the end of the line */
            if(position != line_length-1 && position < line_length && position > 0)
            {
                while(position != line_length )
                {
                    ch = line_buffer[position];
                    write(1, &ch, 1);
                    position++;
                }
            }  
        }
        else if (ch==ESC)  // Esc. Read two chars more
        {
            char ch1; 
            char ch2;
            read(0, &ch1, 1);
            read(0, &ch2, 1);
            if (ch1==91 && ch2==65) // up
            {
                // Print previous line in history.
                // Erase old line
                clear_line();	
                // Copy line from history
               /* if(history_index > 0 && history[history_index] )
                {
                    strcpy(line_buffer, history[history_index]);
                    line_length = strlen(line_buffer);
                    position= line_length-1;
                    history_index--;
                    if(debug_mode)
                        fprintf(stderr, "history_index after <up>=%d\n", history_index);
                    // echo line
                    write(1, line_buffer, line_length);
                } */                   
            }
            else if(ch1==91 && ch2==66) //down 
            {
                // Shows the next command in the history list
                // Print next line in history.
                // Erase old line
                clear_line();
                // Copy line from history
               /* if(history_index > 0 && history_index < 30 && history[history_index])
                {
                    strcpy(line_buffer, history[history_index]);
                    line_length = strlen(line_buffer);
                    position= line_length-1;
                    history_index++;
                    if(debug_mode)
                        fprintf(stderr, "history_index=%d\n", history_index);
                    write(1, line_buffer, line_length);
                }*/
                    
            } 
            else if(ch1==91 && ch2==67) //right 
            {
                /* Move the cursor to the right and allow insertion at 
                that position. If the cursor is at the end  of the line it does nothing. */
                if(position <= line_length && line_length > 0 )
                {
                    ch= line_buffer[position];
                    write(1, &ch, 1);
                    position++;
                }
            } 
            else if(ch1==91 && ch2==68) //left 
            {
                /* Move the cursor to the left and allow insertion at that 
                position. If the cursor is at the beginning of the line it does nothing. */
                if(line_length != 0 || line_length < MAX_BUFFER_LINE)
                {
                    if(position > 0 && position < MAX_BUFFER_LINE)
                    {
                        ch=BACKSPACE;
                        write(1, &ch, 1);
                        position--;
                    }                    
                }
            }
            else if(ch1==91 && ch2==52) // <end>
            {
                //read char because end is ESC+91+52+126
                read(0, &ch1, 1);
                /* end key */
                if(position != line_length-1 && position < line_length && position > 0)
                {
                    while(position != line_length )
                    {
                        ch = line_buffer[position];
                        write(1, &ch, 1);
                        position++;
                    }
                }  
            }
            else if(ch1==91 && ch2==51) // <del>
            {
                //read char because del is ESC+91+51+126
                read(0, &ch1, 1);
                /* del key */   
                delete_current_char();
            }
            else if(ch1==91 && ch2==49) // <HOME>
            {
                //read char because home is ESC+91+49+126
                read(0, &ch1, 1);
                /* home key */
                if(position != 0 && position < line_length+1 && position > 0)
                {
                    while(position != 0 )
                    {
                        ch = BACKSPACE;
                        write(1, &ch, 1);
                        position--;
                    }
                }        
            }  
        }
    }
    // Add eol and null char at the end of string
    if(line_length < 0)
        return "";
    line_buffer[line_length]=10;
    if(line_length >0)
    {
        history[history_index] = strdup(line_buffer);
        if(history_index == 29)
            history_index = 0;
        else
            history_index++;
        
        if(debug_mode)
			for(itr = history_index; itr > 0; itr--)
          fprintf(stderr, "history[%d]=%s\n", itr, history[itr]);
    }  
    line_length++;
    line_buffer[line_length]=0; 
    return line_buffer;
}

