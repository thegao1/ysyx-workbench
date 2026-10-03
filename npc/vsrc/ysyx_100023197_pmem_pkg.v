package pmem_pkg;

import "DPI-C" function int  pmem_read (input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);
import "DPI-C" function void uart_putchar(input int wdata);
import "DPI-C" function int uart_status();
import "DPI-C" function longint get_time();

endpackage
