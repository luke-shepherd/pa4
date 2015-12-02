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

$0 =~ s|.*/||;
my $status = 0;
END { exit $status; }
$SIG{__WARN__} = sub {print STDERR "$0: @_"; $status = 1};
$SIG{__DIE__} = sub {warn @_; $status = 1; exit};

my %opts;
getopts('dnf:', \%opts);

=pod
my @inputs = (
   "all : hello",
   "hello : main.o hello.o",
   "main.o : main.c hello.h",
   "hello.o : hello.c hello.h",
   "ci : Makefile main.c hello.c hello.h",
   "test : hello",
   "clean : ",
   "spotless : clean",
);
=cut
=pod
my %graph;
for my $input (@inputs) {
   my ($target, $deps) = parse_dep $input;
   print "$0: syntax error: $input\n" and next unless defined $target;
   $graph{$target} = $deps;
}
for my $target (keys %graph) {
   print "\"$target\"";
   my $deps = $graph{$target};
   if (not @$deps) {
      print " has no dependencies";
   }else {
      print " depends on";
      print " \"$_\"" for @$deps;
   }
   print "\n";
}
=cut
#push @ARGV, "-" unless @ARGV;

my %macros;
my $makefile;
my %deps; #key is target and val is array of deps
my $targ_commands; #key is target and val is array of commands
my $targ_table = {};

sub parse_dep ($) {
   my ($line) = @_;
   return undef unless $line =~ m/^(\S+)\s*:\s*(.*?)\s*$/; #^ starts the string and $ ends it
   my ($target, $dependency) = ($1, $2); #$1 is between first paren and $2 second
   my @dependencies = split m/\s+/, $dependency;
   return $target, \@dependencies;
}


if(scalar(@ARGV) > 1) {
   print STDERR "$0: Too many args\n";
   exit 1;
}

#print "$ARGV[0]\n";

if($opts{f}) {
   open $makefile, "<$opts{f}" or die "\"$opts{f}\": No such file";
} else {
   open $makefile, "<Makefile" or die "No Makefile";
}

my $currTarget;

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
      $targ_table->{$target} = $table_entry;
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
   # if (defined $currTarget) {print "current target is $currTarget\n"};
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
if($opts{n}) {
   print "$opts{n}\n";
}

#get target from cmdline, use to run/print commands


#open $file, "<$ARGV[0]" or warn "$ARG: $!\n" and next;
#close $file;