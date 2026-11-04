#!/bin/bash


for service in ssh cron nginx; do
	echo "$service": $(systemctl is-active "$service")
done
