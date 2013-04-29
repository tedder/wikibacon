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
use Data::Dumper;
use Encode;
use Getopt::Long;
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

die "old file, needs migration";

my $tb = TedderBot->new( userfile => $USERFILE, debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

my $page = $mw->get_page( { title => 'Wikipedia:Requests for page protection' } );

#print Dumper($page);
parse_rfpp($page->{'*'});

exit;

sub parse_rfpp {
  my ($contents) = @_;

  my $in_entry = 0;
  my $entry;
  my %entries;
  my $section = 'unk';
  foreach my $line (split(/[\r\n]/, $contents)) {
    if ($line =~ /==\b(.*)?\b==/) {
      my $title = $1;
      if ($title =~ /for protection/i) {
        $section = 'prot';
      }
      elsif ($title =~ /unprotection/i) {
        $section = 'unprot';
      }
      elsif ($title =~ /edits to a protected/i) {
        $section = 'edit';
      }
      elsif ($title =~ /fulfilled.*denied/i) {
        $section = 'old';
      }
    }

    if ($in_entry && $line =~ /^==/) {
      # beginning of an entry. Process previous entry out.
      debug("processing entry out, curr section: $section");
      push @{$entries{$section}}, $entry;
      undef $entry;
      $in_entry = 0;
    }

    if ($line =~ /====\s*(.*)?\s*====/) {
      # This is an entry. Processing is done by the above match.
      debug("found entry: $1");
      $in_entry = 1;
    }

    # not an "else", it needs to pick up the ==== line.
    if ($in_entry) { $entry .= $line . "\n"; }
    #debug("entry: $entry");
  }

  #print Dumper(\%entries);

}


sub debug {
  print @_, "\n";
}
