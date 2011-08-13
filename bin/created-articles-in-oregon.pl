#!/usr/bin/perl

###############################################################################
#
# Copyright (c) 2011 Ted Timmons  <ted-bacon@perljam.net>
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
use Time::ParseDate;
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

while(my $line = <>) {
  chomp $line;
#<li><a href="http://en.wikipedia.org/wiki/Onondaga_Hill_Middle_School">Onondaga_Hill_Middle_School</a></li>

  if ($line =~ m#^<li><a href=.*>(.*)<\/a><\/li>#) {
    my $title = $1;
    #next unless $title =~ /Oregon/i;
    #print "haz $title\n";
    my $page = $mw->get_page( { title => $title } );
    my $talk = $mw->get_page( { title => 'Talk:' . $title } );

    if ($page->{'*'} =~ /Oregon/i || $talk->{'*'} =~ /Oregon/i) {
      print "* [[$title]]\n";
    } else {
      #print "no match: $title\n$page\n$talk\n";
    }

    #last;
  }

}


exit;

