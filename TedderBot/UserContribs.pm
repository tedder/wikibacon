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
use Storable;
use TedderBot;

# Inherit from TedderBot
our @ISA = 'TedderBot';


# Get a user's contribs via the API. Many hardcoded bits in here will
# probably be parameters later, but it serves our needs.
sub getContribs {
  my ($self, %opt) = @_;

  return { error => 'no user given' } unless $opt{user};

  ## see if we have a local cache of the user's data.
  my $lcuser = lc $opt{user};
  $lcuser =~ s/\s/_/g
  # filename will be blank unless we pass a taint check.
  my $filename;

  # basic taint check
  $self->_debug("lcuser: $lcuser\n");
  if ($lcuser =~ /^([a-z0-9\s]+)$/) {
    $filename = '/tmp/tedderbot-usercontribs-' . $lcuser;
  }
  else {
    $self->_debug("user taint check failed: $lcuser\n");
  }

  # Do we have a filename? Does Storable return something? Great!
  # That saves us some calls.
  if ($filename && -e $filename) {
    my $contribs = Storable::retrieve($filename);
    if ($contribs) { return $contribs; }
  }

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

  # Do we have a filename for Storable? If so, store out our contribs
  # before returning so we can use it in future calls.
  if ($filename) {
    $self->_debug("attempting to store uclist at $filename\n");
    Storable::store($uclist, $filename);
  }

  return $uclist;
}

# preScoreContribs:
#
# Set up our contribution lists to be ready for scoring. This means we'll
# find the intersection of the two lists, and also collect the timestamps
# for each editor.
#
sub preScoreContribs {
  my ($self, $list1, $list2) = @_;

  my $intersection = {};
  # populate the intersection with both user lists.
  $self->_populateIntersection($intersection, $list1, 1);
  $self->_debug("intersection size after first list: ", scalar keys %$intersection, "\n");

  $self->_populateIntersection($intersection, $list2, 2);
  $self->_debug("intersection size after both lists: ", scalar keys %$intersection, "\n");

  # loop through the intersection. Remove entries that haven't
  # been edited by both users.
  # If this is too slow, it might be faster to create a new list.
  while (my ($name, $r) = each %$intersection) {
    # Both hashes should exist to prove both users have edited the same article.
    unless (exists $r->{user1_timestamps} &&
            exists $r->{user2_timestamps}) {
      delete $intersection->{$name};
    }
  }
  $self->_debug("intersection size after deletion: ", scalar keys %$intersection, "\n");

  #my %intersection;
  # loop through list2, make a second hash with articles in list1 hash
  #foreach my $article (@$list2) {
    #my $articleName = $article->{'title'};

    # does this article also appear on list1?
    #if ($list1articles{$articleName}) {
      #$intersection{$articleName} = 1;
    #}
  #}

  #$self->_debug("articles in intersection: ", scalar keys %intersection, "\n");

  return $intersection;
}

# Create a complex hash with all articles from the list, as well as all edit
# times by this user.
#
# Returns intersection, even though it's modifying the ref version.
sub _populateIntersection {
  my ($self, $intersection, $list, $usern) = @_;

  foreach my $article (@$list) {
    my $name = $article->{'title'};
    my $time = $article->{'timestamp'};

    # This $user could probably be optimized away, because it won't change
    # for all of $list1 or all of $list2.
    # 
    # (round 2- not using "user", just calling it "user1" and "user2".
    #my $user = $article->{'user'};

    my $usern_tag = "user" . $usern . "_timestamps";
    push @{$intersection->{$name}{$usern_tag}}, $time;
  }

  return $intersection;
}

1; # Like a good module should.
