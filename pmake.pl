#!/usr/bin/perl
# Luke Shepherd lshepher@ucsc.edu 
# Taylor Futral tfutral@ucsc.edu
# $Id: cat.perl,v 1.1 2014-10-13 14:16:07-07 - - $

#
# NAME
#   pmake - cat files to the terminal
#
# SYNOPSIS
#    pmake [-d] [-n] [-f makefile] [target]
#
# DESCRIPTION
#    Cat files to the terminal.  If no files are given, cat STDIN.
#
# OPTIONS
# -d 
# -n

use strict;
use warnings;
use Getopt::Std;
use File::Find;

$0 =~ s|.*/||;
my $status = 0;
END { exit $status; }
$SIG{__WARN__} = sub {print STDERR "$0: @_"; $status = 1};
$SIG{__DIE__} = sub {warn @_; $status = 1; exit};

my %opts;
getopts('dnf:', \%opts);
my %strsignal = (
   0 => "Unknown signal 0",
   1 => "Hangup",
   2 => "Interrupt",
   3 => "Quit",
   4 => "Illegal instruction",
   5 => "Trace/breakpoint trap",
   6 => "Aborted",
   7 => "Bus error",
   8 => "Floating point exception",
   9 => "Killed",
   10 => "User defined signal 1",
   11 => "Segmentation fault",
   12 => "User defined signal 2",
   13 => "Broken pipe",
   14 => "Alarm clock",
   15 => "Terminated",
   16 => "Stack fault",
   17 => "Child exited",
   18 => "Continued",
   19 => "Stopped (signal)",
   20 => "Stopped",
   21 => "Stopped (tty input)",
   22 => "Stopped (tty output)",
   23 => "Urgent I/O condition",
   24 => "CPU time limit exceeded",
   25 => "File size limit exceeded",
   26 => "Virtual timer expired",
   27 => "Profiling timer expired",
   28 => "Window changed",
   29 => "I/O possible",
   30 => "Power failure",
   31 => "Bad system call",
   32 => "Unknown signal 32",
   33 => "Unknown signal 33",
);
my %macros;
my $makefile;
my $targ_table = {};

sub parse_dep ($) {
   my ($line) = @_;
   return undef unless $line =~ m/^(\S+)\s*:\s*(.*?)\s*$/; #^ starts the string and $ ends it
   my ($target, $dependency) = ($1, $2); #$1 is between first paren and $2 second
   my @dependencies = split m/\s+/, $dependency;
   return $target, \@dependencies;
}

# Takes a file and returns undef if it can't find file or
# timestamp if it does. 
sub mtime ($) {
   my ($filename) = @_;
   my @stat = stat $filename;
   return @stat ? $stat[9] : undef;
}

sub get_sub {
   my ($sub_name) = @_;
   if(defined $macros{$sub_name}) { return $macros{$sub_name} }
   else {return undef}
}

sub do_target_subs {
   my $more_subs = 1;
   while($more_subs) {

      #assume no more substitutions
      $more_subs = 0;
      for my $target (keys %$targ_table) {
         my $entry = $targ_table->{$target};
         $target =~ s/\$\$/\$/g;
         my $deps = $entry->{PREREQ};
         my $cmds = $entry->{CMDS};

         #check target
         if(($target =~ m/\${(\S+)}/) or $target =~ m/\$(\S)/ ) {
            my $new_targ_name = get_sub ($1);
            if(defined $new_targ_name) {

               #replace old target with new one
               delete $targ_table->{$target};
               $targ_table->{$new_targ_name} = {PREREQ => $deps, 
                  CMDS => $cmds};
               $more_subs = 1;
               last;
            }
            #error, substitution not found
            else { die "Error: $target substitution not found" }
         }
      }
   }
}

sub do_deps_subs {
   my $more_sub = 1;
   while($more_sub) {
      $more_sub = 0;
      for my $target (keys %$targ_table) {
         my $entry = $targ_table->{$target};
         my $deps = $entry->{PREREQ};

         #check depeendencies
         for (my $i = 0; $i <  @$deps; $i++) {
            my $dep = $deps->[$i];

            #do $$ substitution
            $deps =~ s/\$\$/\$/g;

            if(($dep =~ m/\${(\S+)}/) or $dep =~ m/\$(\w)/ ) {

               #print "sub dep is $dep\n";
               my $dep_sub = get_sub ($1);
               if(defined $dep_sub) {
                  #print "$dep_sub\n";
                  my @dep_arr = split m/\s+/, $dep_sub;
                  for my $new_dep (@dep_arr) {
                     push @$deps, $new_dep;

                  }
                  $more_sub = 1;

                  #remove old $SUB dependency
                  splice @$deps, $i, 1;
                  $entry->{PREREQ} = $deps; 
               }
               #error, sub not found
               else { die "Error: $dep substitution not found" }
            }
         }
      }
   }
}

sub do_commands_sub {
   my $more_subs = 1;
   while ($more_subs) {
      #check commands
      $more_subs = 0;

      my $break_loop = 0;
      for my $target (keys %$targ_table) {
         my $entry = $targ_table->{$target};
         my $cmds = $entry->{CMDS};
         my $deps = $entry->{PREREQ};

         for (my $i = 0; $i < scalar (@$cmds); $i++) {
            my $cmd = $cmds->[$i];
            if($cmd =~ m/.*\${(\S+)}.*/) {  #or 
               #$cmd =~ m/.*\s+\$(\w)\s+.*/) {
               my $cmd_sub = get_sub ($1);
               if(defined $cmd_sub) {
                  my $new_cmd = $cmd;
                  $new_cmd =~ s/\${$1}/$cmd_sub/;
                  $cmds->[$i] = $new_cmd;
                  $more_subs = 1;
                  last;
               }
               #error, sub not found
               else { die "Error: $cmd substitution not found"}
            }

            #do $< substitution 
            my $first_file = undef;
            for(my $j = 0; $j < @$deps; $j++) {
               my $file = $deps->[$j];
               my $ttime = mtime ($file);
               if(defined $ttime) { $first_file = $file; last; }
            }

            if(defined $first_file) {
               if($cmd =~ m/.*\$\<.*/) {
                  $cmd =~ s/\$\</$first_file/g;
                  $cmds->[$i] = $cmd;
                  last;
               }
            }

            # $$ substitution
            $cmd =~ s/\$\$/\$/g;
            $cmds->[$i] = $cmd;

         }
      }
   }
}

sub run_commands {

   my $dash_exit = 0;
   my ($targ) = @_;
   my $entry = $targ_table->{$targ};
   unless(defined $entry) { return }
   my $deps = $entry->{PREREQ};
   my $cmds = $entry->{CMDS};

   for my $dep (@$deps) {
      run_commands ($dep);
   }

   #just print commands
   if($opts{n}) {
      for my $cmd (@$cmds) {
         if($cmd =~ m/\-\s+.*/) { 
            $cmd =~ s/\-//;
            $cmd =~ s/^\s+//;
            $dash_exit = 1;
         }
         print "$cmd\n";
      }
   } else {
      #run commands
      for my $cmd (@$cmds) {
         if($cmd =~ m/\-\s+.*/) { 
            $cmd =~ s/\-//;
            $cmd =~ s/^\s+//;
            $dash_exit = 1;
         }
         print "$cmd\n";
	 system "$cmd";
	 if($? > 0 or $? < 0) { 
	    printf STDERR "$strsignal{$?}\n";
	    unless($dash_exit) {exit $?;}
	    else {exit 0}
	 }
      }
   }

}

# recursive subroutine that determines whether files should be run
# Return true if commands should be run
# false if otherwise
sub timeCheck {
   my($target_time, $curr_target) = @_;
   my $curr_time = mtime $curr_target;
   unless (defined $curr_time) { 

      #if $target is a target
      my $targ_ent = $targ_table->{$curr_target};
      unless (defined $targ_ent) {
         #error, target is not in target table


      } else {
         #else go through target's dependencies
         my $deps = $targ_ent->{PREREQ};
         for my $dep (@$deps) { 
            if (timeCheck ($target_time, $dep)) {
               return 1; 
            }
         }
      }
   } else {

      #if target is newer we don't need to do anything
      if($target_time > $curr_time) { return 0; }

      #if it is older we need to do the commands
      else {return 1;}
   }
   return 0; 
}   

#start of "main"
if(scalar(@ARGV) > 1) {
   print STDERR "$0: Too many args\n";
   exit 1;
}


if($opts{f}) {
   open $makefile, "<$opts{f}" or die "\"$opts{f}\": No such file";
} else {
   open $makefile, "<Makefile" or die "No Makefile";
}


my $currTarget;
my $firstTarget;

#fill hashes
while (defined (my $line = <$makefile>)) {
   if ($line =~ m/^(#.*)$/) {}
   elsif ($line =~ m/^(\S+)\s*=\s*(.*?)\s*$/) {
      my ($macro, $value) = ($1, $2);
      $macros{$macro} = $value;
      #print "found macro $macro with value $value\n";
   }
   elsif ($line =~ m/^(\S+)\s*:\s*(.*?)\s*$/) {
      my ($target, $deps) = parse_dep $line;
      my $table_entry = {PREREQ => $deps, CMDS => []}; 
      unless (defined $targ_table->{$target}){ 
         $targ_table->{$target} = $table_entry;
      } else {
         my $clearEntry = $targ_table->{$target};
         if ($target =~ m/\%.(\S+)\s*/){
            $clearEntry->{CMDS} = []; 
         }
      }   

      unless(defined $firstTarget){$firstTarget = $target}

      $currTarget = $target;
   }
   elsif ($line =~ m/^\t(.+)\s*$/) {
      if (defined $currTarget) {
         my $table_entry = $targ_table->{$currTarget};
         my ($cmd) = ($1);

         my $currcmds = $table_entry->{CMDS};
         push @$currcmds, $cmd;
         # $targ_commands->{$currTarget} = @currcmds;
         #print "command $cmd\n";
      }
      else {
         warn "line $.: Undefined commands";
      }

   }         

}       

#if($opts{n}) {
#    print "$opts{n}\n";
#}

#do % substitution
for my $target (keys %$targ_table) {
   my $entry = $targ_table->{$target};
   if($target =~ m/\%.(\S+)\s*/) {

      #get suffix of target
      my ($suf1) = ($1);
      my $suf2;
      my $deps = $entry->{PREREQ};

      #look for %.suffix2 in dependencies
      for my $depname (@$deps) {
         if($depname =~ m/\%.(\S+)\s*/) {
            $suf2 = $1;
         }
      }

      #collect files that match the dep suffix
      my @file_list = glob("*.$suf2");
      if($opts{d}) {
         for my $file (@file_list) {print "$file\n"}
      }

      #for each dep file, see if a new target should be added
      #to the table
      for my $filename (@file_list) {
         my $new_targ = $filename;
         $new_targ =~ s/.$suf2//;
         $new_targ = $new_targ.'.';
         $new_targ = $new_targ.$suf1;
         my @new_req;
         push @new_req, $filename;

         my @cmds2;
         my $orig_cmds = $entry->{CMDS};
         for my $cmd (@$orig_cmds) {
            push @cmds2, $cmd;
         }

         my $new_entry = {PREREQ => \@new_req, CMDS => \@cmds2};

   unless (defined $targ_table->{$new_targ}) {
      $targ_table->{$new_targ} = $new_entry; 
   } else {
      my $old_entry = $targ_table->{$new_targ};
      my $old_cmds = $old_entry->{CMDS};
      my $new_cmds = $entry->{CMDS};
      unless(@$old_cmds > 0) { $old_entry->{CMDS} = $new_cmds;} 
   }      
}   
}
}
#do $substitutions
do_target_subs();
do_deps_subs();
do_commands_sub();


#print tables
if($opts{d}) {

   for my $mac (keys %macros) {
      print "MACRO $mac = VAL $macros{$mac}\n";
   }
   while (my ($target, $entry) = each(%$targ_table)) {
      print "\"$target\" depends on:"; 
      my $deps = $entry->{PREREQ};
      if(not @$deps) {print " no dependencies"}
      else { for my $dep (@$deps) {print " $dep"}}
      print "\n";
      my $cmnds = $entry->{CMDS};
      if(not @$cmnds) {print "--No commands\n"}
      else { for my $cmd (@$cmnds) {print "+- $cmd\n"}}
      print "\n";
   }
}


#get target from cmdline, use to run/print commands
my $inputTarget;
if(@ARGV){
   $inputTarget = $ARGV[0];
}else{
   $inputTarget = $firstTarget;
}

#make sure target is in table
unless(defined $targ_table->{$inputTarget}){
   die "error: no such target";
}

#check times
my $in_target_time = mtime $inputTarget;

#target is a file
if(defined $in_target_time) {
   my $entry = $targ_table->{$inputTarget};
   my $deps = $entry->{PREREQ};
   my $do_commands = 0;
   for my $dep_targ (@$deps) {
      if(timeCheck ($in_target_time, $dep_targ)) {
         $do_commands = 1;
      }
   }

   if($do_commands) {run_commands ($inputTarget)}
   else {print "pmake: \'$inputTarget\' is up to date\n"}
}
#target is just a target, so do it
else {
   run_commands ($inputTarget);
}




