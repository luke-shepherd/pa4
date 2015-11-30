#tfutral lshepher
#!/usr/bin/perl
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

push @ARGV, "-" unless @ARGV;

for my $filename (@ARGV) {
   open my $file, "<$filename" or warn "$filename: $!\n" and next;
   print ":"x32, "\n", "$filename\n", ":"x32, "\n" if $opts{'n'};
   while (defined (my $line = <$file>)) {
      chomp $line;
      printf "%6d  ", $. if $opts{'n'};
      printf "%s\n", $line;
   }
   close $file;
}
