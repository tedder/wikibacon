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


use MediaWiki::API;
use strict;

print "hello world!\n";

  my $mw = MediaWiki::API->new();
  $mw->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';


# process the first 400 articles in the main namespace in the category "Surnames".
# get 100 at a time, with a max of 4 and pass each 100 to our hook.

my $count  = 0;

# TODO: check uclimit to make sure we haven't gone over the permissible,
# tune down as necessary.
$mw->list ( { action => 'query',
              list => 'usercontribs',
              ucuser => 'Tedder',
              uclimit =>'50',
              ucprop => 'ids|title|timestamp', 
              ucdir => 'newer',  },
            { max => 1, hook => \&print_articles } )
|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

exit;

# print the name of each article
sub print_articles {
  my ($ref) = @_;

  # ns is namespace: 0 for articles
  foreach (@$ref) {
    print $count++, " title: $_->{title}\n";
    print " timestamp: $_->{timestamp}\n";
    print " ns: $_->{ns}\n";
    #print join(' ', keys %$_), "\n\n";
    print "\n";
  }

}


