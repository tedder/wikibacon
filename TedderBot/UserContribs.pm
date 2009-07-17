package TedderBot::UserContribs;

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
use Data::Dumper; # TODO: probably temporary for debugging/implementation
use MediaWiki::API;
use TedderBot;

# Inherit from TedderBot
our @ISA = 'TedderBot';


# Get a user's contribs via the API. Many hardcoded bits in here will
# probably be parameters later, but it serves our needs.
sub getContribs {
  my ($self, %opt) = @_;

  return { error => 'no user given' } unless $opt{user};

  my $mw = $self->getMWAPI();

  # future: check uclimit to make sure we haven't gone over the
  #  permissible limit, tune down as necessary.
  my $uclist = $mw->list ( { action => 'query',
                list => 'usercontribs',
                ucuser => $opt{user},
                uclimit =>'500',
                ucprop => 'ids|title|timestamp',
                ucdir => 'newer',  },
              { max => 10000,
                # not using a hook, we want the raw list
                #hook => \&print_articles
              } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};


  $self->_debug("number of contribs found: ", scalar @$uclist, "\n");

  return $uclist;
}


1; # Like a good module should.
