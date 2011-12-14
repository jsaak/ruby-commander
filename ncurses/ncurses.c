#include <ncurses.h>

/* === Global Variables === */
WINDOW *my_wins; /* bordered window with box outline */
WINDOW *my_subwins; /* inside window where content will be
                     * displayed.  */

WINDOW *CreateWin(int height, int width,  int starty, int startx, int dobox)
{
   WINDOW *local_win;

   /* Allocate a new window */
   local_win = newwin(height, width, starty, startx);

   /* If requested, draw a box around it. */
   if (dobox)
      box(local_win, 0, 0);

   /* Update the window’s virtual structure. */
   wrefresh(local_win);
   return local_win;
}

int main()
{
   int ch;

   /* Initialize ncurses */
   initscr();
   cbreak();
   noecho();

   my_wins = CreateWin(LINES, COLS, 0, 0, 1);
   my_subwins = CreateWin(LINES - 2, COLS - 2, 1, 1, 0);
   keypad(my_subwins, TRUE);

   /* Print something in the window. */
   mvwprintw(my_subwins, 0, 0, "Hello World!");
   mvwprintw(my_subwins, 1, 0, "Press F1 to quit.");

   /* Force window updates. */
   doupdate();

   /* Scan for input.  Only the folder subwindow accepts input. */
   while ((ch = wgetch(my_subwins)) != KEY_F(1)) {
      /* Do nothing, just wait for the F1 to exit. */
   }

   /* Free up our ncurses allocated storage */
   endwin();

   /* Exit gracefully */
   return 0;
}
