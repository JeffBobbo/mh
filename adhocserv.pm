#!/usr/bin/perl

package BobboBot::adhocserv;

use warnings;
use strict;

use BobboBot::users;
use Switch;
use POSIX qw(:errno_h mkfifo);
use Fcntl;

my $lookup = {
  ULES00318 => 'MHF',
  ULES00851 => 'MHF2',
  ULUS10391 => 'MHFU',
  ULES01213 => 'MHFU',
  ULJM05800 => 'MHP3rd'
};

my $path = "../AdhocServerPro/pipe";
my $pd;

sub openPipe
{
  mkfifo($path, 0666);
  sysopen($pd, $path, O_NONBLOCK|O_RDONLY) or die __FILE__ . ':' . __LINE__ . " Can't open pipe: $!\n";
}

sub closePipe
{
  close($pd);
}

sub readPipe
{
  my $buf;
  my $bytes = sysread($pd, $buf, 1024);
  if (!defined $bytes)
  {
    if ($! != EAGAIN)
    {
      $main::irc->yield('privmsg', '#bottest', "ERROR: Pipe read failed: $!");
    }
  }
  else
  {
    my @queue = split("\0", $buf);
    foreach my $message (@queue)
    {
      foreach my $channel (BobboBot::channels::channelList())
      {
        switch ($message)
        {
          case 'START'
          {
            $main::irc->yield('privmsg', $channel, '[Ad-Hoc Server] Server started');
          }
          case 'STOP'
          {
            $main::irc->yield('privmsg', $channel, '[Ad-Hoc Server] Server stopped');
          }
          else
          {
            my @toks = split(':', $message); # who, what, game, room
            my $who = shift(@toks);
            my $action = shift(@toks) eq 'JOIN' ? 'joined' : 'left';
            my $game = shift(@toks);
            $game = $lookup->{$game} || $game;
            my $roomID = shift(@toks);
            my $room = substr($roomID, -3) + 1;
            $main::irc->yield('privmsg', $channel, '[Ad-Hoc Server] ' . $who . ' ' . $action . ' room ' . $room . ' (' . $game . ')');
          }
        }
      }
    }
  }
}

sub run
{
  readPipe();
  return "";
}

sub help
{
  return 'adhocserv - Automatic module that tracks MHFU and MHP3rd states';
}

sub auth
{
  return accessLevel('normal');
}

#BobboBot::module::addCommand('adhocserv', 'run', \&BobboBot::adhocserv::run);
#BobboBot::module::addCommand('adhocserv', 'help', \&BobboBot::adhocserv::help);
#BobboBot::module::addCommand('adhocserv', 'auth', \&BobboBot::adhocserv::auth);
BobboBot::module::addEvent('LOAD',    \&BobboBot::adhocserv::openPipe);
BobboBot::module::addEvent('STOP',    \&BobboBot::adhocserv::closePipe);
BobboBot::module::addEvent('RESTART', \&BobboBot::adhocserv::closePipe);

BobboBot::module::addEvent('AUTO', \&BobboBot::adhocserv::readPipe, 1);

1;
