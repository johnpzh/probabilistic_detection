# This script is created by NSG2 beta1
# <http://wushoupong.googlepages.com/nsg>
# modified by Piglet

#===================================
#     Simulation parameters setup
#===================================
set opt(chan)   Channel/WirelessChannel    ;# channel type
set opt(prop)   Propagation/TwoRayGround   ;# radio-propagation model
#set opt(netif)  Phy/WirelessPhy/802_15_4  ;# network interface type
#set opt(mac)    Mac/802_15_4              ;# MAC type
set opt(netif)  Phy/WirelessPhy            ;# network interface type
set opt(mac)    Mac/802_11                 ;# MAC type
set opt(ifq)    Queue/DropTail/PriQueue    ;# interface queue type
set opt(ll)     LL                         ;# link layer type
set opt(ant)    Antenna/OmniAntenna        ;# antenna model
set opt(ifqlen) 50                         ;# max packet in ifq
set opt(rp)     DSDV                       ;# routing protocol
set opt(trace_file) "out.tr"
set opt(nam_file) "out.nam"
set tcl_precision 17;                       # Tcl variaty
# =====================================================================
set opt(normal) "normal.tcl";               # file for normal distribution
source $opt(normal)
set opt(x)      30                        ;# X dimension of topography
set opt(y)      30                        ;# Y dimension of topography
set opt(spot_x) [expr $opt(x) / 2.0];      # X coordinate of Target Spot
set opt(spot_y) [expr $opt(y) / 2.0];      # Y coordinate of Target Spot
set opt(stop)   1000                        ;# time of simulation end
set opt(nfnode) 5                        ;# number of fixed nodes
set opt(ntarget) 1;                        # number of targets
set opt(node_size) 1                       ;# Size of nodes
set opt(target_size) 2                     ;# Size of the target
set opt(time_click) 1;                      # Duration of a time slice
set opt(noise_avg) 0.01;                       # Noise average
set opt(noise_var) [expr 2 * $opt(noise_avg)]; # Noise variance
set opt(noise_std) [expr sqrt($opt(noise_var))]; # Noise standard deviation
set opt(S_0) 10;                             # Maximum of source singal
set opt(decay_factor) 2;                    # Decay factor
set opt(d_0) 5     ;# Distance threshold of Fixed nodes
set opt(sensitivity) 1;         # Factor for modifying lambda
#set opt(phi) 0.5;           # Threshold of System Sensing probability
set opt(PA) 0.05;         # Target Appearance probability
set opt(target_on) 0;     # Flag of target's presence
set opt(true_alarm) 0;   # Number of true alarms
set opt(false_alarm) 0;   # Number of false alarms
set opt(detection_proba) 0; # Detection Probability
set opt(false_proba) 0;     # False Alarm Probability
set opt(radius_range_lower) 0;    # Lower Times of radius
set opt(radius_range_upper) 3;    # Upper Times of radius
set opt(closest_index) -1;   # Index of closest sensor
if {0 < $argc} {
    set opt(nfnode) [lindex $argv 0]
    set opt(result_file) [lindex $argv 1]
}
set opt(nn) [expr $opt(ntarget) + $opt(nfnode)] ;# sum of nodes
#===================================
#        Initialization
#===================================
#Create a ns simulator
set ns [new Simulator]

#Setup topography object
set topo [new Topography]
$topo load_flatgrid $opt(x) $opt(y)
create-god $opt(nn)

#Open the NS trace file
set tracefile [open $opt(trace_file) w]
$ns trace-all $tracefile

#Open the NAM trace file
set namfile [open $opt(nam_file) w]
$ns namtrace-all $namfile
$ns namtrace-all-wireless $namfile $opt(x) $opt(y)

#===================================
#     Node parameter setup
#===================================
$ns node-config -adhocRouting  $opt(rp) \
                -llType        $opt(ll) \
                -macType       $opt(mac) \
                -ifqType       $opt(ifq) \
                -ifqLen        $opt(ifqlen) \
                -antType       $opt(ant) \
                -propInstance  [new $opt(prop)] \
                -phyType       $opt(netif) \
                -channel       [new $opt(chan)] \
                -topoInstance  $topo \
                -agentTrace    OFF \
                -routerTrace   OFF \
                -macTrace      OFF \
                -movementTrace OFF

#===================================
#        Collection of Random
#===================================
# Return a coordinate X
proc get_a_x {{min 0} {max -1}} {
    global opt
    if {$max == -1} {
        set max $opt(x)
    }
    set rd [new RNG]
    $rd seed 0
    return [$rd uniform $min $max]
}

# Return a coordinate Y
proc get_a_y {{min 0} {max -1}} {
    global opt
    if {$max == -1} {
        set max $opt(y)
    }
    return [get_a_x $min $max]
}

#===================================
#        Utilities
#===================================

# Target appears
proc target_appear {time_stamp} {
    global opt target
    set opt(target_on) 1
    $target color "red"
}

# Target is absent
proc target_miss {time_stamp} {
    global opt target
    set opt(target_on) 0
    $target color "black"
}

# Compute the Cumulative Probability of Standard Normal Distribution
proc normal_CDF {x mean sd} {
    global normal
    set y [expr 1.0 * ($x - $mean) / $sd]
    if {$y < 0} {
        set minus 1
        set y [expr abs($y)]
    } else {
        set minus 0
    }
    if {$y > 4.99} {
        set y 4.99
    } elseif {$y < 0.001} {
        set y 0.001
    }
    if {[string length $y] > 4} {
        set t [string range $y 4 4]
        if {$t >= 5} {
            #set y [expr [string range $y 0 3] + 0.01]
            set y [expr $y + 0.01]
            set y [string range $y 0 3]
        } else {
            set y [string range $y 0 3]
        }
    } elseif {[string length $y] == 3} {
        append y "0"
    } elseif {[string length $y] == 1} {
        append y ".00"
    }
    set value $normal($y)
    if {$minus} {
        set value [expr 1.0 - $value]
    }
    return $value
}

# Compute local detection probability
proc get_local_detec_proba {threshold dist time_stamp} {
    global opt
    if {$dist > $opt(d_0)} {
        set decay [expr pow((double($dist) / $opt(d_0)), $opt(decay_factor))]
        set e_s [expr double($opt(S_0)) / $decay]
    } else {
        set e_s $opt(S_0)
    }
    set mean [expr $e_s + $opt(noise_avg)]
    set value [normal_CDF $threshold $mean $opt(noise_std)]
    set local_proba [expr 1.0 - $value]
    return $local_proba
}

# Compute false alarm probability
proc get_false_alarm_rate {threshold time_stamp} {
    global opt
    set mean [expr $opt(noise_avg)]
    set value [normal_CDF $threshold $mean $opt(noise_std)]
    set false_rate [expr 1.0 - $value]
    return $false_rate
}

# Get a sensor's signal measurement
proc signal_measurement {dist time_stamp} {
    global opt
    # Source intensity
    if {$opt(target_on)} {
        if {$dist > $opt(d_0)} {
            set decay [expr pow((double($dist) / $opt(d_0)), $opt(decay_factor))]
            set e_s [expr double($opt(S_0)) / $decay]
        } else {
            set e_s $opt(S_0)
        }
    } else {
        set e_s 0
    }
    # Noise intensity
    set rd [new RNG]
    $rd seed 0
    set e_n [$rd normal $opt(noise_avg) $opt(noise_std)]
    # Signal Measurement
    set e_i [expr $e_s + $e_n]
    return $e_i
}

# Fixed sensors detect
proc fixed_sensors_detect {time_stamp} {
    global opt fnode fdists lambda
    $fnode($opt(closest_index)) color "black"
    set is_alert 0
    set dist $fdists($opt(closest_index))
    set signal [signal_measurement $dist $time_stamp]
    if {$signal >= $lambda($opt(closest_index))} {
        set is_alert 1
        $fnode($opt(closest_index)) color "green"
    }
    if {$is_alert} {
        if {$opt(target_on)} {
            incr opt(true_alarm)
        } else {
            incr opt(false_alarm)
        }
    }
}

#===================================
#        Nodes Definition
#===================================
# Get the distance based on coordinates
proc distance_xy {sx sy tx ty} {
    set dx [expr $sx - $tx]
    set dy [expr $sy - $ty]
    set dist [expr sqrt($dx * $dx + $dy * $dy)]
    return $dist
}

proc compute_lambda {dist} {
    global opt

    if {$dist > $opt(d_0)} {
        set decay [expr pow((double($dist) / $opt(d_0)), $opt(decay_factor))]
        set e_s [expr double($opt(S_0)) / $decay]
    } else {
        set e_s $opt(S_0)
    }
    set mu $opt(noise_avg)
    set sigma2 $opt(noise_std)
    set lambda [expr $e_s + $mu - $opt(sensitivity) * $sigma2]
    return $lambda
}

# Deploy sensors within certain range
proc deploy_sensor {x_ y_} {
    global opt
    upvar 1 $x_ x
    upvar 1 $y_ y

    set dist [distance_xy $x $y $opt(spot_x) $opt(spot_y)]
    set lower [expr $opt(radius_range_lower) * $opt(d_0)]
    set upper [expr $opt(radius_range_upper) * $opt(d_0)]
    while {$dist > $upper || $dist < $lower} {
        set x [get_a_x]
        set y [get_a_y]
        set dist [distance_xy $x $y $opt(spot_x) $opt(spot_y)]
    }
    return $dist
}

# Create Fixed nodes
set dist_min InF
for {set i 0} {$i < $opt(nfnode)} {incr i} {
    set fnode($i) [$ns node]
    set xf [get_a_x]
    set yf [get_a_y]
    set dist [deploy_sensor xf yf]
    set fdists($i) $dist
    set lambda($i) [compute_lambda $dist]
    if {$dist < $dist_min} {
        set dist_min $dist
        set opt(closest_index) $i
    }
    $fnode($i) set X_ $xf
    $fnode($i) set Y_ $yf
    $fnode($i) set Z_ 0
    $fnode($i) random-motion 0
    $ns initial_node_pos $fnode($i) $opt(node_size)
    $fnode($i) color "black"
    $fnode($i) shape "circle"
}

# Create the Target
set target [$ns node]
$target set X_ $opt(spot_x)
$target set Y_ $opt(spot_y)
$target set Z_ 0
$target random-motion 0
$ns initial_node_pos $target $opt(target_size)
$target color "black"

#===================================
#        Schedule
#===================================
# Target's schedule
set rd [new RNG]
$rd seed 0
set count [expr int($opt(stop) * $opt(PA))]; # Number of target presence
if {$count == 0} {
    set count 1
}
for {set i 0} {$i < $opt(stop)} {incr i} {
    set click($i) 0
}
# Randomly set target presence up to count times
for {set i 0} {$i < $count} {incr i} {
    set t [$rd integer $opt(stop)]
    while {$click($t) == 1} {
        set t [$rd integer $opt(stop)]
    }
    set click($t) 1
}
# Set target schedule
for {set t 0} {$t < $opt(stop)} {incr t} {
    if {$click($t)} {
        $ns at $t "target_appear $t"
    } else {
        $ns at $t "target_miss $t"
    }
}

# Sensors' schedule
set time_line 0
while {$time_line < $opt(stop)} {
    $ns at $time_line "fixed_sensors_detect $time_line"
    incr time_line $opt(time_click)
}

#===================================
#        Termination
#===================================
# Calculate Detection Probability and False Alarm Probability
proc system_probas {} {
    global opt
    set presences [expr $opt(PA) * $opt(stop)]
    set absences [expr $opt(stop) - $presences]
    set opt(detection_proba) [expr $opt(true_alarm) / $presences]
    set opt(false_proba) [expr 1.0 * $opt(false_alarm) / $absences]
}

# Calculate the results
proc getting_results {} {
    system_probas
}

# Define a 'finish' procedure
proc output_file {} {
    global ns opt
    set result_file [open $opt(result_file) a]
    puts $result_file \
         "$opt(nfnode) \
          $opt(detection_proba) \
          $opt(false_proba)"
    close $result_file
}
proc finish {} {
    global ns tracefile namfile opt argc
    getting_results
    #puts "detection_proba: $opt(detection_proba)"
    #puts "false_proba: $opt(false_proba)"
    $ns flush-trace
    if {0 < $argc} {
        output_file
    }
    $ns at $opt(stop) "$ns nam-end-wireless $opt(stop)"
    close $tracefile
    close $namfile
    # exec nam out.nam
    exit 0
}

# Reset nodes
$ns at $opt(stop) "$target reset"
for {set i 0} {$i < $opt(nfnode)} {incr i} {
    $ns at $opt(stop) "$fnode($i) reset"
}

# Finish
$ns at $opt(stop) "finish"
$ns at $opt(stop) "puts \"Done.\"; $ns halt"
$ns run
