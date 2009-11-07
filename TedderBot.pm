package TedderBot;

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
  my ($self, %opt) = @_;
  $self->{config}{api_url} = $opt{mw_api_url} || 'http://en.wikipedia.org/w/api.php';
  $self->{DEBUG} = $opt{debug} || 0;

  if ($opt{userfile}) {
    $self->readUserfile($opt{userfile});
  }

  $self->_debug("_init details: ", Dumper($self->{config}));

  return 1;
}

# quick function to read in our username and password from a file, so we
# don't store them in our repository. Leaving it generic so we can store
# other configuration information there too.
sub readUserfile {
  my ($self, $file) = @_;

  return undef unless (-e $file);

  open(USERFILE, $file) || die "can't open $file for reading: $!";
  while (my $line = <USERFILE>) {
    chomp $line;

    # read in entries.
    if ($line =~ /^\s*(.*?):\s*(.*)$/) {
      $self->{config}{$1} = $2;
    }
  }
  close USERFILE;

  # success!
  return 1;
}

# _init_globals: used for DB connections, for instance.
sub _init_globals {
  #my ($self, %in) = @_;
  return 1;
}

# Return our MediaWiki::API object. Instantiate if we haven't already.
sub getMWAPI {
  my ($self) = @_;

  if ($self->{mw}) {
    return $self->{mw};
  } # else


  # Okay, we don't have one. Create it, log in.
  my $mw = MediaWiki::API->new( { api_url => $self->{config}{api_url} } );

  # Should we log in?
  if ($self->{config}{mw_user} && $self->{config}{mw_pass}) {
    my $result = $mw->login( { lgname => $self->{config}{mw_user},
                               lgpassword => $self->{config}{mw_pass} } )
      || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
    $self->_debug("login details: ", Dumper($result));
  }


  # Assign it into ourselves.
  $self->{mw} = $mw;

  return $self->{mw};
}


# internal debug method to print debugging information only when enabled.
sub _debug {
  my ($self) = shift; # shift off so we can print the rest.
  return undef unless $self->{DEBUG};

  print STDERR @_;
}

# appendPage: edit a page on Wikipedia and append content.
# Wrapper for mw->edit with some extra goodies.
sub appendPage {
  my ($self, $articleName, $text, $summary) = @_;

  my $mw = $self->getMWAPI();
  my $ref = $mw->get_page( { title => $articleName } );
  unless ( $ref->{missing} ) {
    my $timestamp = $ref->{timestamp};
    $mw->edit( {
      action => 'edit',
      summary => $summary,
      section => 'new',
      title => $articleName,
      basetimestamp => $timestamp, # to avoid edit conflicts
      bot  => 1,
      text => $text } )
      || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
  }

  return 1;
}

# replace: edit a page on Wikipedia and replace content.
# Wrapper for mw->edit with some extra goodies.
# Returns 1 on success.
sub replacePage {
  my ($self, $articleName, $text, $summary) = @_;

  my $mw = $self->getMWAPI();
  my $ref = $mw->get_page( { title => $articleName } );
  #print STDERR "updating page: $articleName. ref: ", Dumper($ref), "\n";
  unless ( $ref->{missing} ) {
    my $timestamp = $ref->{timestamp};
    my $ret = $mw->edit( {
      action => 'edit',
      summary => $summary,
      title => $articleName,
      basetimestamp => $timestamp, # to avoid edit conflicts
      bot  => 1,
      text => $text } )
      || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

    #print STDERR "mw edit ret: ", Dumper($ret), "\n";
    # return true on success.
    if ($ret && ref $ret eq 'HASH'
      && ref $ret->{edit} eq 'HASH'
      && $ret->{edit}{result} eq 'Success') {
      return 1;
    }
  }

  return 0;
}

#
# checks User:TedderBot/Bot status to make sure we are allowed to run.
sub okayToRun {
  my ($self, $runpage) = @_;

  $runpage ||= 'User:TedderBot/Bot status';
  my $mw = $self->getMWAPI();
  my $ret = $mw->get_page( { title => $runpage } );
  #print Dumper($ret);

  # check for success and runnable status.
  if ($ret && ref $ret eq 'HASH' && $ret->{'*'} =~ m#^status: run\b#i) {
    return 1;
  }

  # anything else is a failure.
  return 0;
}

1; # Like a good module should.
