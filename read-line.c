/*
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define MAX_BUFFER_LINE 2048
extern int debug_mode;

int line_length;
char line_buffer[MAX_BUFFER_LINE];
int history_index = 0;
int maxHistory = 30;
char** history;
int history_length = sizeof(history)/sizeof(char *);

void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?       Print usage\n"
    " Backspace    Deletes last character\n"
    " up arrow     See last command in the history\n"
    " left arrow  key: Move the cursor to the left and allow insertion at " 
      "that position. If the cursor is at the beginning of the line it does nothing.\n"
    " right arrow key: Move the cursor to the right and allow insertion at that position. "
      "If the cursor is at the end  of the line it does nothing.\n"
    " delete key(ctrl-D): Removes the character at the cursor. The characters in the right "
      "side are shifted to the left.\n"
    " backspace (ctrl-H)key: Removes the character at the position before the cursor. "
      "The characters in the right side are shifted to the left.\n"
    " Home key (or ctrl-A): The cursor moves to the beginning of the line\n"
    " End key (or ctrl-E): The cursor moves to the end of the line\n";
  write(1, usage, strlen(usage));
}
char * read_line() 
{
    history = (char**) calloc( maxHistory*sizeof(char*), sizeof(char*) );
    int itr;
    for(itr = maxHistory; itr > 0; itr--)
      history[itr] = (char*)calloc(MAX_BUFFER_LINE, sizeof(char) );
    // Set terminal in raw mode
    tty_raw_mode();
    line_length = 0;
    // Read one line until enter is typed
    while (1) 
    {
      // Read one character in raw mode.
      char ch;
      read(0, &ch, 1);
      if (ch>=32 && ch < 127) 
      {
        // It is a printable character. display it back
        write(1,&ch,1);
        // If max number of character reached return.
        if (line_length==MAX_BUFFER_LINE-2) 
          break; 
        // add char to buffer.
        line_buffer[line_length]=ch;
        line_length++;
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
      else if (ch == 8 || ch==127) 
      {
        // <backspace> or ctrl-H was typed. Remove previous character read.
        // Go back one character
        ch = 8;
        write(1,&ch,1);
        // Write a space to erase the last character read
        ch = ' ';
        write(1,&ch,1);
        // Go back one character
        ch = 8;
        write(1,&ch,1);
        // Remove one character from buffer
        line_length--;
      }
      else if(ch == 4)
      {
        /*ctrl-D): Removes the character at the cursor. 
        The characters in the right side are shifted to the left. */
      }
      else if(ch == 1)
      {
        /*Home key (or ctrl-A): The cursor moves to the beginning of the line */
      }
      else if(ch==5)
      {
        /*End key (or ctrl-E): The cursor moves to the end of the line */
      }
        else if (ch==27) 
        {
            // Esc. Read two chars more
            char ch1; 
            char ch2;
            read(0, &ch1, 1);
            read(0, &ch2, 1);
            if (ch1==91 && ch2==65) // up
            {
                // Print next line in history.
                // Erase old line
                // Print backspaces
                int i = 0;
                for (i =0; i < line_length; i++) 
                {
                    ch = 8;
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
                    ch = 8;
                    write(1,&ch,1);
                }	
                // Copy line from history
                if(history_index > 0)
                strcpy(line_buffer, history[history_index]);
                line_length = strlen(line_buffer);
                history_index=(history_index+1)%history_length;
                // echo line
                write(1, line_buffer, line_length);
            }
            else if(ch1==91 && ch2==66) //down 
            {
              //Shows the next command in the history list
            } 
            else if(ch1==91 && ch2==67) //right 
            {
              /* Move the cursor to the right and allow insertion at 
              that position. If the cursor is at the end  of the line it does nothing. */
              
            } 
            else if(ch1==91 && ch2==68) //left 
            {
              /* Move the cursor to the left and allow insertion at that 
              position. If the cursor is at the beginning of the line it does nothing. */
              
            }
            else if(ch1==91 && ch2==52) // <end>
            {
              //read char because end is 27+91+52+126
              /* end key */
              
            }
            else if(ch1==91 && ch2==49) // <HOME>
            {
              //read char because home is 27+91+49+126
              /* home key */        
            }  
        }
    }
    // Add eol and null char at the end of string
    line_buffer[line_length]=10;
    line_length++;
    line_buffer[line_length]=0;
    return line_buffer;
}

