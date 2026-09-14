//=====================================================================
// pmem_pkg.v —— DPI-C 接口声明
//
// 为什么要单独放一个 package：
//   DPI 的 import 是"按模块"生效的。如果在 fetch.v 和 mem.v 里各写一遍
//   import "DPI-C" function int pmem_read(...); 会报
//     %Error: Duplicate declaration of function: 'pmem_read'
//   所以统一在这里声明一次，用到的模块 import pmem_pkg::*; 即可。
//
// C 侧实现在 csrc/dpi_pmem.cpp，签名必须一致：
//   int  pmem_read (int raddr)
//   void pmem_write(int waddr, int wdata, byte wmask)
//
// set_finish_flag 没放这儿，它只有 execute.v 用，就地声明在那边了
// （声明两遍会报 Duplicate declaration）。
//=====================================================================
package pmem_pkg;

import "DPI-C" function int  pmem_read (input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);
import "DPI-C" function void uart_putchar(input int wdata);

endpackage
