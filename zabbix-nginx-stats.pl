#!/usr/bin/perl -w

# Script to parse nginx log file to calculate request counts and average request times.

#         log_format timed_combined '$remote_addr $host $remote_user [$time_local]  '
#                    '"$request" $status $body_bytes_sent '
#                    '"$http_referer" "$http_user_agent" $request_time $upstream_response_time $pipe';
#
# apt-get install libstatistics-descriptive-perl libtimedate-perl

use strict;

my $DEBUG = 0;
my $DRYRUN = 0;
my $ZABBIX_SENDER = '/usr/bin/zabbix_sender';
my $ZABBIX_CONF = '/etc/zabbix/zabbix_agentd.conf';
# MAXAGE is the maximum age of log entries to process, all older lines are ignored
# Since this script is meant to be run every 10 minutes, make sure we don't process more logfile lines.
my $MAXAGE = (2+10)*60*60;

my $reqcount = 0;
my $oldcount = 0;
my $parseerrors = 0;
my $request_time_total = 0;
my $upstream_time_total = 0;
my $statuscount = {
	'200' => 0,
	'404' => 0,
	'403' => 0,
	'500' => 0,
	'503' => 0,

	'other' => 0,
};

use Statistics::Descriptive;
use Date::Parse;

my $s_request_time = Statistics::Descriptive::Full->new();
my $s_upstream_time = Statistics::Descriptive::Full->new();

while(<>){
  if (
    my (
	$remote_addr,
	$hostname,
	$remote_user,
	$time_local,
	$request,
	$status,
	$body_bytes_sent,
	$http_referer,
	$http_user_agent,
	$request_time,
	$upstream_response_time) = m/(\S+) (\S+) (\S+) \[(.*?)\]\s+"(.*?)" (\S+) (\S+) "(.*?)" "(.*?)" ([\d\.]+)(?: ([\d\.]+|-))?/
    ) {
    my $time = str2time($time_local);
    my $diff = time() - $time;
    if ($diff > $MAXAGE) {
      $oldcount += 1;
    }
    $statuscount->{defined $statuscount->{$status} ? $status : 'other'} += 1;
    $s_request_time->add_data(int($request_time*1000));
    if (defined $upstream_response_time && $upstream_response_time ne '-') {
      $s_upstream_time->add_data(int($upstream_response_time*1000));
    }
    $reqcount += 1;
  } else {
    $parseerrors += 1;
  }
}

sub sendstat {
  my ($key, $value) = @_;

  my $cmd = "$ZABBIX_SENDER -c $ZABBIX_CONF -k \"nginx[$key]\" -o \"$value\" >/dev/null";
  if ($DEBUG) {
    print $cmd . "\n";
  }
  system $cmd if ! $DRYRUN;
}
sub sendstatint {
  my ($key, $value) = @_;
  sendstat($key, int($value + 0.5));
}

sub printstats {
  my ($obj, $prefix) = @_;
  if ($obj->count() == 0) {
    return;
  }
  sendstatint("${prefix}_avg", $obj->sum()/$obj->count());
  sendstat("${prefix}_count", $obj->count());
  sendstatint("${prefix}_mean", $obj->mean());
  sendstatint("${prefix}_percentile25", $obj->percentile(25));
  sendstatint("${prefix}_percentile80", $obj->percentile(80));
  sendstatint("${prefix}_percentile90", $obj->percentile(90));
  sendstatint("${prefix}_median", $obj->median());
}


sendstat('oldcount', $oldcount);
sendstat('requestcount', $reqcount);
printstats($s_request_time, 'request_time');
printstats($s_upstream_time, 'upstream_time');
sendstat("parseerrors", $parseerrors);
for my $status (keys %$statuscount) {
  sendstat("status_$status", $statuscount->{$status});
}


