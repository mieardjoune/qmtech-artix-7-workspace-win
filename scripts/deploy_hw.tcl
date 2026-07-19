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
# Programs the QMTECH Artix-7 over JTAG via Vivado's Hardware Manager.
# Invoked via: ./make.cmd deploy <project>
set bit_file [lindex $argv 0]

if {![file exists $bit_file]} {
    puts "CRITICAL ERROR: Bitstream not found: $bit_file"
    puts "HINT: Run './make.cmd build <project>' first."
    exit 1
}

if {[catch {
    open_hw_manager
    connect_hw_server
    open_hw_target
} err]} {
    puts "CRITICAL ERROR: Could not connect to hardware: $err"
    exit 1
}

set hw_device [lindex [get_hw_devices] 0]
if {$hw_device eq ""} {
    puts "CRITICAL ERROR: No JTAG device detected."
    puts "HINT: Check the Platform Cable USB II is plugged in and powered."
    exit 1
}

if {[catch {
    current_hw_device $hw_device
    refresh_hw_device -update_hw_probes false $hw_device
    set_property PROGRAM.FILE $bit_file $hw_device
    puts "--> Programming $hw_device with $bit_file ..."
    program_hw_devices $hw_device
} err]} {
    puts "CRITICAL ERROR: Programming failed: $err"
    exit 1
}
puts "--> SUCCESS: board programmed."

close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
