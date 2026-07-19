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
# ==============================================================================
# Project Mode Synthesis & Implementation Script
# Target: QMTECH Artix-7 (xc7a100tfgg676-1)
# ==============================================================================
set prj_dir    [file normalize [lindex $argv 0]]
set top_module [lindex $argv 1]

set part      "xc7a100tfgg676-1"
set output_dir ${prj_dir}/build
set report_dir ${prj_dir}/reports
set proj_dir   ${prj_dir}/vivado_project
set proj_name  "vivado_proj"

set_param general.maxThreads 8

# Recreate the project fresh on every build so stale settings from a
# previous run (top, generics, added sources) can never leak into this one.
if {[file exists $proj_dir]} { file delete -force $proj_dir }
create_project $proj_name $proj_dir -part $part -force

set src_files [glob -nocomplain ${prj_dir}/src/*.v ${prj_dir}/src/*.sv ${prj_dir}/src/*.vhd ${prj_dir}/src/*.vhdl]
if {[llength $src_files] > 0} {
    add_files -norecurse $src_files
}
foreach f [glob -nocomplain ${prj_dir}/src/*.vhd ${prj_dir}/src/*.vhdl] {
    set_property FILE_TYPE {VHDL 2008} [get_files $f]
}

set xdc_files [glob -nocomplain ${prj_dir}/constraints/*.xdc]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
}

set_property top $top_module [current_fileset]

# Generics: one name=value per line in params.txt
if {[file exists ${prj_dir}/params.txt]} {
    set fp [open ${prj_dir}/params.txt r]
    set generic_strs {}
    foreach line [split [read $fp] "\n"] {
        set trimmed [string trim $line]
        if {$trimmed != ""} { lappend generic_strs $trimmed }
    }
    close $fp
    if {[llength $generic_strs] > 0} {
        set_property generic $generic_strs [current_fileset]
    }
}

set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "CRITICAL ERROR: Synthesis (synth_1) did not complete."
    puts "HINT: See $proj_dir/$proj_name.runs/synth_1/runme.log"
    exit 1
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    puts "CRITICAL ERROR: Implementation (impl_1) did not complete."
    puts "HINT: See $proj_dir/$proj_name.runs/impl_1/runme.log"
    exit 1
}

open_run impl_1

# Strict Timing Check (Fail Fast)
set timing_paths [get_timing_paths -delay_type min_max -max_paths 1]
if { [llength $timing_paths] > 0 } {
    set wns [get_property SLACK $timing_paths]
    puts "Worst Negative Slack (WNS): $wns ns"
    if { $wns < 0.0 } {
        puts "CRITICAL WARNING: Timing constraints violated (WNS = $wns ns). Design will fail on hardware!"
        exit 1
    }
} else {
    puts "INFO: No internal constrained timing paths found. Skipping WNS verification."
}

set run_dir [get_property DIRECTORY [get_runs impl_1]]
if {[catch {
    file copy -force $run_dir/${top_module}.bit $output_dir/${top_module}.bit
    if {[file exists $run_dir/${top_module}.bin]} {
        file copy -force $run_dir/${top_module}.bin $output_dir/${top_module}.bin
    }
} err]} {
    puts "CRITICAL ERROR: Could not collect bitstream from $run_dir: $err"
    exit 1
}

# Export Verilog Netlist & Standard Delay Format (SDF) for accurate Gate-Level Simulation
if {[catch {
    write_verilog -mode timesim -sdf_anno true -force ${prj_dir}/sim/post_route_netlist.v
    write_sdf -mode timesim -force ${prj_dir}/sim/post_route.sdf
} err]} {
    puts "CRITICAL ERROR: Timing netlist extraction failed: $err"
    exit 1
}

# Comprehensive Reporting
report_timing_summary -file $report_dir/timing_summary.txt
report_utilization -file $report_dir/utilization.txt
report_power -file $report_dir/power.txt
report_methodology -file $report_dir/methodology.txt
exit 0
