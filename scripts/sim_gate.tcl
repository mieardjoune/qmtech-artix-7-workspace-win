#  Copyright 2026 M. I. E. ARDJOUNE
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
set prj_dir     [file normalize [lindex $argv 0]]
set top         [lindex $argv 1]
set vivado_base [lindex $argv 2]

cd $prj_dir/sim

if {![file exists post_route_netlist.v]} {
    puts "CRITICAL ERROR: post_route_netlist.v not found in $prj_dir/sim."
    puts "HINT: Run './make.cmd build <project>' first -- this file is written by build.tcl."
    exit 1
}

# Distinct filename from RTL sim's waveform.vcd -- both write to the same
# sim/ directory, and reusing one name lets a stale RTL-sim artifact be
# mistaken for fresh gate-level output if this step fails early.
set fp [open "xsim_cfg.tcl" w]
puts $fp "open_vcd waveform_gate.vcd\ncatch {log_vcd \[get_objects -r /${top}_tb/*\]}\nrun 500ns\nclose_vcd\nexit"
close $fp

set fh [open post_route_netlist.v r]
set lines [split [read $fh] "\n"]
close $fh
set clean {}
set lineno 0
foreach l $lines {
    incr lineno
    if {$lineno <= 20 && [regexp {^[A-Z_][A-Z_]*="?[^"]*$} $l]} { continue }
    lappend clean $l
}
set fh [open post_route_netlist.v w]
puts $fh [join $clean "\n"]
close $fh

# Every exec is wrapped: Tcl's exec raises on a nonzero child exit code, and
# an uncaught error here does not reliably translate into a nonzero process
# exit code for Vivado batch mode (see AMD UG835's guidance on using catch).
proc run_step {name script} {
    if {[catch {uplevel 1 $script} err]} {
        puts "CRITICAL ERROR: $name failed: $err"
        exit 1
    }
}

run_step "Primitive/netlist compile" {
    exec >@stdout xvlog $vivado_base/data/verilog/src/glbl.v post_route_netlist.v
}

set sv_tbs [glob -nocomplain $prj_dir/tb/*.sv]

if { [llength $sv_tbs] > 0 } {
    puts "--> Compiling SystemVerilog Testbench..."
    foreach f [glob -nocomplain $prj_dir/src/*pkg.sv $prj_dir/tb/*pkg.sv] {
        run_step "SystemVerilog package compile ($f)" [list exec >@stdout xvlog -sv -d GATE_SIM $f]
    }
    foreach f $sv_tbs {
        if {![string match "*pkg.sv" $f]} {
            run_step "SystemVerilog testbench compile ($f)" [list exec >@stdout xvlog -sv -d GATE_SIM $f]
        }
    }
} else {
    puts "--> Compiling VHDL Testbench..."
    foreach f [glob -nocomplain $prj_dir/tb/*.vhd] {
        run_step "VHDL testbench compile ($f)" [list exec >@stdout xvhdl -2008 $f]
    }
}

puts "--> Elaborating Design with SDF Timing Annotation..."
run_step "Elaboration" {
    exec >@stdout xelab -debug typical -sdfmax /${top}_tb/uut=post_route.sdf -L simprims_ver -L unisims_ver -L unimacro_ver -L secureip work.${top}_tb work.glbl -s gate_sim
}

puts "--> Running Timing Simulation..."
run_step "Timing simulation" {
    exec >@stdout xsim gate_sim -tclbatch xsim_cfg.tcl
}

puts "--> Gate-level simulation completed successfully!"
exit 0
