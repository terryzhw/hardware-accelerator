@echo off
rem Compile and run one testbench with Vivado's simulator (xsim).
rem Usage, from the repo folder:   tb\run_sim.bat nn_core_tb
set VIVADO_BIN=C:\AMDDesignTools\2026.1\Vivado\bin
if not exist sim_build mkdir sim_build
cd sim_build
call %VIVADO_BIN%\xvlog -sv ..\rtl\mac.sv ..\rtl\nn_core.sv ..\rtl\uart_rx.sv ..\rtl\uart_tx.sv ..\rtl\nn_top.sv ..\rtl\seven_seg.sv ..\tb\%1.sv || goto end
call %VIVADO_BIN%\xelab %1 -s %1_sim || goto end
call %VIVADO_BIN%\xsim %1_sim -R
:end
cd ..
