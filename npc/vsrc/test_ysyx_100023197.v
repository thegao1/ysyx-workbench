// iverilog 用的顶层测试台。
// 用法：vvp build/sim_top.vvp +img=<程序镜像.bin>
//   不写 +img= 就默认载入当前目录下的 hello.bin。
//   镜像就是 AM 编出来的 .bin（microbench、cpu-tests 的 dummy/hello… 都行），
//   路径相对于"你敲 vvp 命令时所在的目录"。
//
// 程序跑完时（AM 的 halt() 发 ebreak），exu.v 里的 $finish 会停掉仿真；
// 这里再在 final 块里把指令数/拍数/ipc 打出来。
module icarus_top;
    reg clock = 0;
    reg reset = 1;

    reg [1023:0] img_path;    // +img= 传进来的镜像路径
    integer      cycles = 0;  // 时钟拍数
    integer      insts  = 0;  // 退休指令数

    ysyx_100023197 cpu (
        .clock(clock),
        .reset(reset)
        // led, pc, inst, rd_data, gpr_dump, status, lsu_status 不接就悬空
    );

    always #5 clock = ~clock;

    initial begin
        // $value$plusargs 把命令行上 "+img=xxx" 里的 xxx 抠出来放进 img_path。
        // 返回 0 表示命令行上没写这个 +img=，那就用默认的 hello.bin。
        if (!$value$plusargs("img=%s", img_path))
            img_path = "hello.bin";
        $display("[icarus] 载入镜像 %0s", img_path);
        $load_bin(img_path);
        #10 reset = 0;
    end

    // commit 是 CPU 的"这一拍退休了一条指令"，拿它数指令；
    // 拍数就直接数时钟。复位期间清零，保证和 Verilator 那边的口径一样。
    //
    // $tick_time 是 VPI 侧的 refresh_time()：Verilator 靠 difftest 主循环
    // 每提交一条指令调一次，计时器才往前走；iverilog 没有主循环，
    // 不在这里补上的话 $get_time_lo/hi 会一直返回 0（程序读到的 uptime 恒为 0）。
    always @(posedge clock) begin
        if (reset) begin
            cycles = 0;
            insts  = 0;
        end else begin
            cycles = cycles + 1;
            if (cpu.commit) begin
                insts = insts + 1;
                $tick_time();
            end
        end
    end

    // $finish 之后执行（Verilog 的"收尾"块）
    final begin
        $display("[icarus] 指令 %0d 拍 %0d ipc %f", insts, cycles,
                 (cycles == 0) ? 0.0 : insts * 1.0 / cycles);
    end
endmodule
