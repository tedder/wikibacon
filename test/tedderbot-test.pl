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
use Getopt::Long;
use lib '/home/tedt/git/wikibacon/';
use TedderBot::UserContribs;

# commandline options with defaults.
my $user1;
my $user2;
my $userfile = '/home/tedt/.wiki-userinfo';
my $debug = 0;
my $test = 0;
my $help = 0;

GetOptions ("user1=s"    => \$user1,
            "user2=s"    => \$user2,
            "userfile=s" => \$userfile,
            "debug"      => \$debug,
            "test"       => \$test,
            "help"       => \$help);

if ($help) {
  showUsage();
  exit;
}

unless (-e $userfile) {
  print "Userfile is required for login info.\n";
  showUsage();
  exit;
}

unless ($user1 && $user2) {
  print "must specify both user1 and user2.\n";
  showUsage();
  exit;
}

my $tb = TedderBot::UserContribs->new( userfile => $userfile, debug => $debug );

my $contrib1 = $tb->getContribs( user => $user1 );
my $contrib2 = $tb->getContribs( user => $user2 );
$tb->preScoreContribs($contrib1, $contrib2);
#print join(", ", keys %$int), "\n";
$tb->scoreContribs();

my $newText = "\n\n==Wikibacon: " . join(', ', sort($user1, $user2)) . "==\n";
my $summary = 'Wikibacon results between ' . join(', ', sort($user1, $user2));

my $numArticles = $tb->getUniqueArticles();
$newText .= qq(\nUser [[User:$user1|$user1]] and [[User:$user2|$user2]] have edited $numArticles unique articles together.\n);

# don't bother showing results if they haven't edited articles together.
if ($numArticles) {
  $newText .= qq(\n===Close edits===\nThis is the "time distance" between the two users. In other words, this shows collaboration or edit wars between the users.\n);
  $newText .= $tb->showCloseEdits(5);

  $newText .= qq(\n===First edits===\nThis shows the first time a user edited in articles the other user has already edited in. This shows when the user's paths first crossed.\n);
  $newText .= $tb->showFirstEdits(5);
}

# Sign the post.
$newText .= "~~~~\n\n";

if ($test) {
  print "output:\n$newText\n";
} else {
  $tb->appendPage('User:TedderBot/Bacon Results', $newText, $summary);
}

exit;

sub showUsage {
  # TODO
  print qq(PLACEHOLDER TODO TODO\n);
}
