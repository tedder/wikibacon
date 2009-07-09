package MediaWiki::List;

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

sub new {
  my ($package, %in) = @_;

  # Create and bless new object
  my $self = {};
  bless $self, $package;

  # Bail if either of these don't succeed
  return undef unless $self->_init_globals(%in);
  return undef unless $self->_init(%in);

  return $self;
}


# This method is overridden if any _init work needs to be done.
sub _init {
  return 1;
}

# _init_globals: used for DB connections, for instance.
sub _init_globals {
  #my ($self, %in) = @_;
  return 1;
}




1; # Like a good module should.
