#!/usr/local/bin/perl
use strict;
use warnings;
use POSIX qw(strftime);
use YAML::XS qw(LoadFile);
use LWP::Simple qw($ua get);
use Path::Tiny qw(path);
use Data::Dumper;

my $VERSION = 1.3;
our $conf = LoadFile('config.yaml');
my $heating_state = 0;
my $pump_state = 0;
my %sensors;
our $LOG;

$ua->timeout(10);

open $LOG, '>>', $conf->{log} or die "Unable to open logfile $conf->{log}: $!\n";
# Make it unbuffered
select((select($LOG), $| = 1)[0]);

sub logger {
	print $_[0] . "\n" if $conf->{debug};
	print $LOG strftime('%b %d %H:%M:%S', localtime(time)) . ' ' . $_[0] . "\n";
}

sub toggle_heating {
	my $conf_ref = shift;
	my $sensors_ref = shift;
	my $toggle = shift;
	my %current_state = ();
	while (my $switch = each %{$conf_ref->{switches}}) {
		$current_state{$switch} = 2;
		my $info = get($conf_ref->{switches}->{$switch});
		if ($info =~ /^on[\r\n]*$/) {
			$current_state{$switch} = 1;
		}
		if ($info =~ /^off[\r\n]*$/) {
			$current_state{$switch} = 0;
		}
	}

	if ($toggle) {
		while (my ($k,$v) = each %current_state) {
			# turn on, only if the switch is currently off
			if ($v == 0) {
				logger "Turning ON $k";
				$sensors_ref->{$k}{start_time} = time;
				get("$conf_ref->{switches}->{$k}/0");
			} else {
				logger "$k already on" if $conf_ref->{debug};
			}
		}
	} else {
		while (my ($k,$v) = each %current_state) {
			# turn off, only if the switch is currently on
			if ($v == 1) {
				logger "Turning OFF $k";
				get("$conf_ref->{switches}->{$k}/1");
			} else {
				logger "$k already off" if $conf_ref->{debug};
			}
		}
	}
}

sub get_temp {
	my $url = shift;
	# example output from the sensors: Temperature: 25.30C  Humidity: 46.50
	my $ret = get($url);
	return [0, 0] if (!defined($ret));
	my @line = split /\s+/, $ret;
	$line[1] =~ s/C$//;
	if ($line[1] =~ /^\d+\.\d+$/ and $line[3] =~ /^\d+\.\d+$/) {
		return [$line[1], $line[3]];
	} else {
		return [0, 0];
	}
}

sub collect_data {
	my $conf_ref = shift;
	my $sensors_ref = shift;
	while (my ($k,$v) = each %{$conf_ref->{sensors}}) {
		$sensors_ref->{$k} = get_temp($v->{url});
		# skip sensors which do not return any/valid readings
		if ($sensors_ref->{$k}[0] == 0 and $sensors_ref->{$k}[1] == 0) {
			logger "Skipping sensor $k, because it did not return correct values" if $conf_ref->{debug};
			next;
		}
		logger sprintf("Checking sensor %s:\t %2.2f C %2.2f %% humidity", $k, $sensors_ref->{$k}[0], $sensors_ref->{$k}[1]) if $conf_ref->{debug};
		if ($conf_ref->{sensors}->{$k}->{js_log}) {
			my $f = path($conf_ref->{sensors}->{$k}->{js_file});
			my $d = $f->slurp_utf8;
			my $m = sprintf "{ x: %d000, y: %2.2f },\n]; return mypoints; };\n", time, $sensors_ref->{$k}[0];
			$d =~ s/]; return mypoints; };\n/$m/;
			$f->spew_utf8($d);
		}
	}
	
}

sub check_sensor_data {
	my $conf_ref = shift;
	my $sensors_ref = shift;
	my $toggle = -1;
	my @time = localtime(time);
	# time[1] - minutes
	# time[2] - hours

	while (my $sensor = each %{$conf->{sensors}}) {
		# skip this sensor if we don't have data for it or if the data is 0
		next if (!defined($sensors_ref->{$sensor}[0]) or $sensors_ref->{$sensor}[0] == 0);

		# Get the start and stop time for the sensor
		my ($start_hour,$start_min) = split /:/, $conf->{sensors}->{$sensor}->{start_time};
		my ($stop_hour,$stop_min) = split /:/, $conf->{sensors}->{$sensor}->{stop_time};
	
		logger "Sensor: $sensor kill_temp: $conf_ref->{sensors}->{$sensor}->{kill_temp} max_temp: $conf_ref->{sensors}->{$sensor}->{max_temp} min_temp: $conf_ref->{sensors}->{$sensor}->{min_temp}" if $conf_ref->{debug};


		if ($sensors_ref->{$sensor}[0] > $conf_ref->{sensors}->{$sensor}->{max_temp}) {
			logger "Turning OFF because of sensor($sensor) max temp($sensors_ref->{$sensor}[0] C)" if $conf_ref->{debug};
			$toggle = 0;
		}
		if ($sensors_ref->{$sensor}[0] <= $conf_ref->{sensors}->{$sensor}->{min_temp}) {
			logger "Turning ON because of sensor($sensor) min_temp($sensors_ref->{$sensor}[0] C)" if $conf_ref->{debug};
			$toggle = 1;
		}

		# do not check kill_temp and global min_temp if it is outside sensor's active time zone
		# start time 19:00 stop time 10:00
		# start time 08:00 stop time 22:00
		if ($time[2] >= $start_hour and $time[2] <= $stop_hour and $time[1] >= $start_min and $time[1] <= $stop_min) {
			if ($sensors_ref->{$sensor}[0] > $conf_ref->{kill_temp} or 
				$sensors_ref->{$sensor}[0] > $conf_ref->{sensors}->{$sensor}->{kill_temp}) {
				logger "Turning OFF because of sensor($conf_ref->{sensors}->{$sensor}->{kill_temp} C) ot global kill temp($conf_ref->{kill_temp} C)" if $conf_ref->{debug};
				$toggle = 0;
			}
			if ($sensors_ref->{$sensor}[0] <= $conf_ref->{min_temp}) {
				logger "Turning ON because of global min_temp($conf_ref->{min_temp} C)" if $conf_ref->{debug};
				$toggle = 1;
			}
		}

		if ($sensors_ref->{$sensor}[0] <= $conf_ref->{min_temp}) {
			logger "Turning ON because of global min_temp($conf_ref->{min_temp} C)" if $conf_ref->{debug};
			$toggle = 1;
		}
	}

	# Do not turn off the burner if it has worked less then min_time
	if ($toggle == 0 && defined($sensors_ref->{start_time}) && (time - $sensors_ref->{start_time} < $conf_ref->{min_time})) {
		logger "Turning ON because of minimum time($conf_ref->{min_time} seconds)" if $conf_ref->{debug};
		$toggle = 1;
	}

	# Check if the heating is triggered manually
	my @override_stat = stat($conf_ref->{manual_override}->{file});
	# skip if the file is not existing
	goto RET if ($#override_stat < 0);

	if (time - $conf_ref->{manual_override}->{duration} < $override_stat[9]) {
		logger "Turning ON because of manual override" if $conf_ref->{debug};
		$toggle = 1;
	} else {
		logger "Removing the manual override";
		unlink $conf_ref->{manual_override}->{file};
	}
	
	RET:
	logger "Toggle: $toggle" if $conf_ref->{debug};
	return $toggle;
}

sub main {
	my $toggle = -1;
	collect_data($conf, \%sensors);
	
	$toggle = check_sensor_data($conf, \%sensors);

	# Toggle the heating only if any rule has been matched
	toggle_heating($conf, \%sensors, $toggle) if ($toggle > -1);
}

logger "Staring $0 $VERSION";
if ($conf->{debug}) {
	main;
} else {
	while (1) {
		main;
		sleep($conf->{check_interval});
	}
}

__END__

Basically the regulator should work as follows:

# check if any of the sensors is above its max_temp
	if so, we need to turn off the heating

# check if any of the sensors is below its min_temp
	if so, we need to turn on the heating

# check if any of the sensors is above its kill_temp or the global kill_temp
	if so, we need to turn off the heating

# check if any of the sensors is below the global min_temp
	if so, we need to turn on the heating

# check if we have manually triggered the start of the heating

# toggle the heating
	turn it on, only if it is off and turn it off only if it is on
