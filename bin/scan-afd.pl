#!/usr/bin/perl

###############################################################################
#
# Copyright (c) 2009 Ted Timmons  <ted-bacon@perljam.net>
# This software is released under the MIT license, cited below.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
###############################################################################


use strict;

use constant TITLE => 'Wikipedia:Articles for deletion/Ciaran Buckley';
use Time::ParseDate;
use Data::Dumper;
use Encode;
use Getopt::Long;
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

my $page = $mw->get_page( { title => TITLE } );

#delete $page->{'*'}; print Dumper($page); exit;
my $first_sig = find_first_date($page->{'*'});
my $create = get_create_date($mw, TITLE);
print "FFD timestamp: $first_sig / ", scalar gmtime($first_sig), "\n";
print "GCD timestamp: $create / ", scalar gmtime($create), "\n";
my $create_delta = abs($create-$first_sig);
my $hours = sprintf('%.2f', $create_delta / 3600);
my $days = sprintf('%.2f', $create_delta / 3600 / 24);
print "create delta: $create_delta seconds / $hours hours / $days days\n";

exit;

sub get_create_date {
  my ($mw, $title) = @_;

  print "hello gcd, |$title|\n";
  my $ret = $mw->api( {
    action => 'query',
    prop   => 'revisions',
    titles => $title,
    rvdir => 'newer',
    rvlimit => 1,
    rvprop => 'timestamp|user|size'
  } );

  my @pages = keys %{$ret->{query}{pages}};
  my $timestamp = parsedate($ret->{query}{pages}{$pages[0]}{revisions}[0]{timestamp});
  print "gcd final timestamp: $timestamp\n";
  return $timestamp;
}

sub find_first_date {
  my ($contents) = @_;

  my $date;
  foreach my $line (split(/[\r\n]/, $contents)) {
    print "line: $line\n";
    if (my $d = parsedate($line)) {
      if ($d < $date || ! $date) {
        $date = $d;
        print "FFD $d / ", scalar gmtime($d), "\n";
      }
    }

    if ($line =~ /(\d+:\d+)\D+(\d+\s*\w+\s*\d+)/) {
      my $time = $1 . ' ' . $2;
      if (my $d = parsedate($time)) {
        if ($d < $date || ! $date) {
          $date = $d;
          print "FFD $d / $time / ", scalar gmtime($d), "\n";
        }
      }
    }
    #if ($line =~ 
  }

  print "FFD date: ", scalar gmtime ($date), "\n";
  return $date;
}


sub debug {
  print @_, "\n";
}
