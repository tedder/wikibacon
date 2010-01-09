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
use lib '/home/tedt/git/wikibacon/';
use TedderBot::UserContribs;

print "hello world!\n";

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 1 );
my $mw = $tb->getMWAPI();


# test query:
# http://en.wikipedia.org/w/api.php?action=query&list=allpages&apprefix=Possibly%20unfree%20images&apnamespace=4&aplimit=5
my $backlist = $mw->list ( { action => 'query',
  list => 'allpages',
  apprefix => 'Possibly unfree images',
  apnamespace => 4, # Wikimedia: prefix
  aplimit => 500,
  #ucprop => 'ids|title|timestamp',
  { max => 2, }
  #hook => &process_article
 } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

my $count = 0;
foreach my $entry (@$backlist) {
  my $namespace = $entry->{ns};
  my $title = $entry->{title};
  ++$count;

  #process_article($ref);
  process_article($title);
  #print "title: $title, namespace: $namespace\n";

}


print "count: $count\n";

exit;

sub process_article {
  my ($title) = @_;

  print "PA title: $title\n";

}

