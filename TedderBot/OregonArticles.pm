package TedderBot::OregonArticles;

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
use Time::ParseDate; #parsedate
use Time::CTime; # strftime
use MediaWiki::API;
use Storable;
use TedderBot;

# Inherit from TedderBot
our @ISA = 'TedderBot';

use constant EDIT_CUTOFF => parsedate("-90 days");

# Is the passed title part of the WikiProject Oregon constellation of pages?
#
# Harder than it seems, as we need to actually get the list of Oregon pages
# first.
#
sub isOregonArticle {
  my ($self, $title) = @_;

  $self->{alist} ||= $self->getLinks('Wikipedia:WikiProject Oregon/Admin');
  if ($self->{alist}{$title}) {
    return 1;
  }
  return undef;
}


sub getLinks {
  my ($self, $title) = @_;

  my %list;
  my $mw = $self->getMWAPI();

  # future: check uclimit to make sure we haven't gone over the
  #  permissible limit, tune down as necessary.
my $count = 0;
my $continue = '';
  my %param = (
    action => 'query',
    prop => 'links',
    titles => $title,
    pllimit =>'500', { max => 50000 }
    #pllimit =>'5', { max => 5 }
  );

  do {
    my $aret = $mw->api( \%param )
      || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

    # pick off our continue parameter.
    $param{plcontinue} = $aret->{'query-continue'}{links}{plcontinue};
#print Dumper($aret); exit;

    # Should only have one pageid there, so we'll just shift off the first one.
    my @id = keys %{$aret->{query}{pages}};
    my $alist = $aret->{query}{pages}{$id[0]}{links};
#print "alist: ", Dumper($alist); exit;
    foreach my $entry (@$alist) {
#print "entry: ", Dumper($entry);
      my $title = $entry->{title};
      $list{$title}++;
    }

  } while ($param{plcontinue});

#print "output: ", Dumper($alist), "\n";
#print "contribs: ", scalar @list, "\n";
  return \%list;
  #$self->_debug("number of contribs found: ", scalar @$alist, "\n");
}

sub evalUserContribs {
  my ($self, $user) = @_;

  my $mw = $self->getMWAPI();

  #my %param = (
  #  action => 'query',
  #  prop => 'usercontribs',
  #  ucuser => $user,
  #  uclimit =>'5',
  #
  #  { max => 50000 }
  #  #pllimit =>'5', { max => 5 }
  #);


  my $api_user = 'User:' . $user;
  if ($user =~ /^\d+\.\d+\.\d+\.\d+$/) { $api_user = $user; }
print "checking $api_user\n";
  my %param = (
    action => 'query',
    list => 'usercontribs',
    #ucuser => $user,
    ucuser => $api_user,
    uclimit =>'500',

    { max => 50000 }
  );

#print Dumper(\%param); 
  my $ret = {};


  do {
    my $aret = $mw->api( \%param )
      || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
    foreach my $contrib (@{$aret->{query}{usercontribs}}) {
      my $time = parsedate($contrib->{timestamp});
      my $month = strftime('%Y%m', gmtime($time));
      my $title = $contrib->{title};
    
      # most recent edit?
      $ret->{max} = $time > $ret->{max} ? $time : $ret->{max};
      # edits for our time period
      if ($time > EDIT_CUTOFF) { $ret->{edit}++; }
    
      # Okay, do some of the same things for our OREGON articles.
      if ($self->isOregonArticle($title)) {
        $ret->{ORmax} = $time > $ret->{ORmax} ? $time : $ret->{ORmax};
        if ($time > EDIT_CUTOFF) { $ret->{ORedit}++; }
      }

      #print "$time / $month / $title\n";
      #print Dumper($contrib);
      #last;
    } 

    # pick off our continue parameter.
    #print Dumper($ret->{"query-continue"}); exit;
    #$param{uccontinue} = $aret->{'query-continue'}{links}{plcontinue};
    #print Dumper($aret); exit;

        # Should only have one pageid there, so we'll just shift off the first one.
    my @id = keys %{$aret->{query}{pages}};
    #my $alist = $aret->{query}{pages}{$id[0]}{links};
#print "alist: ", Dumper($alist); exit;
    #foreach my $entry (@$alist) {
#print "entry: ", Dumper($entry);
      #my $title = $entry->{title};
      #$list{$title}++;
    #}
    #print "q-c: ", Dumper($aret->{"query-continue"}); exit;
    #print "ret return: ", Dumper($aret); exit;
    #print Dumper($ret->{"query-continue"}); exit;
    $param{uccontinue} = $aret->{'query-continue'}{links}{plcontinue};

  } while ($param{uccontinue});
#print Dumper($ret);
#print "ormax: ", scalar gmtime $ret->{ORmax}, "\n";
#print "max: ", scalar gmtime $ret->{max}, "\n";

#print "output: ", Dumper($alist), "\n";
#print "contribs: ", scalar @list, "\n";
  #return \%list;
  #$self->_debug("number of contribs found: ", scalar @$alist, "\n");

  return $ret;
}


1; # Like a good module should.
