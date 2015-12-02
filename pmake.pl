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

# recursive subroutine that determines whether files should be run
sub timeCheck {
	#my(
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


#get target from cmdline, use to run/print commands
my $inputTarget;
if(@ARGV){
    $inputTarget = $ARGV[0];
}else{
    $inputTarget = $firstTarget;
}
my $checkTarget;
if(defined $targ_table->{$inputTarget}){
    $checkTarget = $targ_table->{$inputTarget};
}else{
    print"error: no such target";
    exit 1;
}

#do % substitution
while (my ($target, $entry) = each(%$targ_table)) {
    if($target =~ m/\%.(\S+)\s*/) {
	
	#suf1
	my ($suf1) = ($1);
        my $suf2;
        my $deps = $entry->{PREREQ};
	for my $depname (@$deps) {
            if($depname =~ m/\%.(\S+)\s*/) {
	        $suf2 = $1;
	    }
	}

        my @file_list = glob("*.$suf2");
	if($opts{d}) {
	   for my $file (@file_list) {print "$file\n"}
        }

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

	      #add commands to old target
	      #unless (@$old_cmds){
	      #  for (my $i = 0; $i < @$new_cmds; $i++) { 
	      #    push @$old_cmds, $new_cmds->[$i];
	      #  } 
	      #}
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


