## Project name

This is not a project - this is a library of shell scripts.
Each script was written because of private needs/requirements.

## Table of contents

- [Project name](#project-name)
- [Table of contents](#table-of-contents)
- [General info](#general-info)
- [Ansible tools](#ansible-tools)
- [gdrivemounter](#gdrivemounter)
- [vpsconfigurator](#vpsconfigurator)
- [pgconfigurator](#pgconfigurator)
- [watchdocker](#watchdocker)
- [getcert](#getcert)

## General info

Each script is used to realize another task.
Scripts was written due to personally requirements.
You can use it, modify and do everything that you want.

## Ansible tools

Collection of shell scripts used in Ansible tasks.
For more details check this repository: https://github.com/mrachuta/ansible-playbooks

## gdrivemounter

Script was prepared to be used together with google-drive-ocalmfuse
package. Because gdo has no service-agent, script can be easily adapted
as base for service daemon. It can be also used as separate script, to
manually mount and unmount multiple (or single) drives.

## vpsconfigurator

Script is used to automate initial configuration of VPS.
It creates the new user, set password and install necessary software.
Still in development to exclude as much as possible manually typing.  

## pgconfigurator

Script used to configure containerized postgresql database.
To use script, mount it under: */docker-entrypoint-initdb.d/pgconfigurator.sh*.
It will be executed automatically, when container will be created.

## watchdocker

Script checking for available container-image updates.
If there is no updated image available, update via apt
on base system inside container is performed.
Can be adapted as service-daemon via cron.  

TODO:  
a) manage in-container pip updates

## getcert

Script for getting an new certificate/renewing
an old certificate, using Let's Encrypt as
certificate supplier. It is prepared for containerized environment with docker-compose.yml file.
Works only with nginx. Can be adapted as service-daemon via cron.  
Based on https://github.com/wmnnd/nginx-certbot
