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

sub run_commands {
   my $targ = @_;
   print "Running commands for target $targ\n";
}

# recursive subroutine that determines whether files should be run
# Return true if commands should be run
# false if otherwise
sub timeCheck {
   my($target_time, $curr_target, $target_table) = @_;
   my $curr_time = mtime $curr_target;
   unless (defined $curr_time) { 

      #if $target is a target
      my $targ_ent = $target_table{$curr_target};
      unless (defined $targ_ent) {
         #error

      } else {
         my $deps = $targ_ent->{PREREQ};
         for my $dep (@$deps) { 
            if (timeCheck ($target_time, $dep, $target_table)) {
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
while (my ($target, $entry) = each(%$targ_table)) {
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

         my $new_entry = {PREREQ => \@new_req, CMDS => ($entry->{CMDS})};

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

#print tables
if($opts{d}) { 
   for my $mac (keys %macros) {
      print "MACRO $mac = VAL $macros{$mac}\n";
   }
   while (my ($target, $entry) = each(%$targ_table)) {
      print "TARGET $target depends on:"; 
      my $deps = $entry->{PREREQ};
      if(not @$deps) {print " no dependencies"}
      else { for my $dep (@$deps) {print " $dep"}}
      print "\n";
      my $cmnds = $entry->{CMDS};
      if(not @$cmnds) {print "--No commands\n"}
      else { for my $cmd (@$cmnds) {print "+- $cmd\n"}}


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
   my $entry = $targ_table{$inputTarget};
   my $deps = $entry->{PREREQ};
   my $do_commands = 0;
   for $dep_targ (@$deps) {
      if(timeCheck ($in_target_time, $dep_targ, $targ_table)) {
         $do_commands = 1;
      }
   }

   if($do_commands) {run_commands ($inputTarget)}
   else print "Nothing to be done for \"$inputTarget\"\n"
}
#target is just a target, so do it
else {
   run_commands ($inputTarget);
}




