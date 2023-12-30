#!/bin/bash
# Skyler Ogden
# CupricReki@gmail.com
# 20201109 
# script to add healthcheck.io scripts for startup notifications, shutdown notification, and cron updates




checks () {

	# check for sudo
	if (( $EUID != 0 )); then
	    echo 'need root'
	    exit 1
	fi

	# Dependency checks 
	if ! command -v jq &> /dev/null
	then
	    echo "jq not found, attempting apt install"
	    apt update && apt install -y jq
	fi
}

hio_setup () {

	# Healthcheck.io API key
	API_KEY=W0QoEVjl_PRzRFp3f1s80ENFc8qpkIVO

	# Check's parameters. This example uses system's hostname for check's name.
	PAYLOAD='{"name": "'`hostname`'", "timeout": 60, "grace": 60, "unique": ["name"]}'

	# Create the check if it does not exist.
	# Grab the ping_url from JSON response using the jq utility:
	URL=`curl -s https://healthchecks.io/api/v1/checks/  -H "X-Api-Key: $API_KEY" -d "$PAYLOAD"  | jq -r .ping_url`
}

script_start_setup () {

	# Create startup script
	touch /usr/local/bin/healthcheckio_start.sh
	/bin/cat <<EOM >"/usr/local/bin/healthcheckio_start.sh"
#!/bin/bash
# using curl (10 second timeout, retry up to 5 times):
curl -m 10 --retry 5 $URL/start
EOM
	chmod 744 /usr/local/bin/healthcheckio_start.sh
}

script_stop_setup () {

	# Create stop script
	touch /usr/local/bin/healthcheckio_stop.sh
	/bin/cat <<EOM >"/usr/local/bin/healthcheckio_stop.sh"
#!/bin/bash
# using curl (10 second timeout, retry up to 5 times):
curl -m 10 --retry 5 $URL/fail
EOM
	chmod 744 /usr/local/bin/healthcheckio_stop.sh
}

unit_start_setup () {

	# Create unit start call for start script
	touch /etc/systemd/system/healthcheckio_start.service
	/bin/cat <<EOM >"/etc/systemd/system/healthcheckio_start.service"
[Unit]
Description=Send healthcheck on startup
After=network.service

[Service]
ExecStart=/usr/local/bin/healthcheckio_start.sh

[Install]
WantedBy=default.target
EOM
	chmod 644 /etc/systemd/system/healthcheckio_start.service
	systemctl daemon-reload
	systemctl enable healthcheckio_start.service
}

unit_stop_setup () {

	# Create unit stop call for stop script
	touch /etc/systemd/system/healthcheckio_stop.service
	/bin/cat <<EOM >"/etc/systemd/system/healthcheckio_stop.service"
[Unit]
Description=Send healthcheck on shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/healthcheckio_stop.sh
TimeoutSec=20

[Install]
WantedBy=shutdown.target
EOM
	chmod 644 /etc/systemd/system/healthcheckio_stop.service
	systemctl daemon-reload
	systemctl enable healthcheckio_stop.service
}

unit_setup () {

	systemctl start healthcheckio_start.service
}

cron_setup () {
	# Setup periodic checks every minutes
	crontab -l > mycron

	# Check if entry exists
	if grep -q $URL mycron ; then
		echo 'fstab entry already exists'
	else
		# append to cron
		printf '* * *   *   *	curl -fsS -m 10 --retry 5 -o /dev/null %s\n' $URL >> mycron

		# install new cron file
		crontab mycron
	fi
	rm mycron
}

script_exit () {

	# start unit and send first healthcheck
	systemctl start healthcheckio_start.service

	exit 0
}

checks
hio_setup 
script_start_setup
script_stop_setup
unit_start_setup
unit_stop_setup
unit_setup
cron_setup
script_exit
exit 0
