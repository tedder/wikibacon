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

my $user1 = 'Tedder';
my $user2 = 'Peteforsyth';

my $tb = TedderBot::UserContribs->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );

$tb->getMWAPI();

my $contrib1 = $tb->getContribs( user => $user1 );
my $contrib2 = $tb->getContribs( user => $user2 );
my $int = $tb->preScoreContribs($contrib1, $contrib2);
#print join(", ", keys %$int), "\n";
$tb->scoreContribs($int);

my $newText = '';

$newText .= '==Wikibacon: ' . join(', ', sort($user1, $user2)) . "==\n";
my $summary = 'Wikibacon results between ' . join(', ', sort($user1, $user2));

# working, turn off for now.
$newText .= qq(\n===Close edits===\nThis is the "time distance" between the two users. In other words, this shows collaboration or edit wars between the users.\n);
$newText .= $tb->showCloseEdits($int, 5);


#$tb->firstEdits($int);
$newText .= qq(\n===First edits===\nThis shows the first time a user edited in articles the other user has already edited in. This shows when the user's paths first crossed.\n);
$newText .= $tb->showFirstEdits($int, 5);

# Sign the post.
$newText .= "~~~~\n";

$tb->appendPage('User:TedderBot/Bacon Results', $newText, $summary);
