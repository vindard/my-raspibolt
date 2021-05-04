# Automated Raspibolt steps

This is a personal repo I use to do an assisted setup of a [Raspibolt Bitcoin full node](https://stadicus.github.io/RaspiBolt/). It pretty much includes all the steps as presented in the guide, with a few very slight modifications (e.g. I stick with the `pi` user instead of switching to `admin`).

I also add some additional utilities and services that I personally run/use on my Raspberry Pi, e.g.:
- [**NoIP DUC**](https://www.noip.com/download?page=linux) for tracking my IP dynamically
- **Transmission** torrent client for hosting Bitcoin release version torrents ([see here](https://gist.github.com/vindard/f6d3b390006ef4b6f52de0f7155ad9a4))

> _Disclaimer: This repo is still very much a work-in-progress and is only meant to assist and not fully automate the node setup process._
>
> I prefer this over other automated node packages because I like the high level of control and verifiability this offers, and it gives me the chance to practice linux architecture-related things.


## Usage

Everything is designed to be run from the `setup.sh` script. I've separated all the different steps I take into `step_xx` functions. I usually comment/uncomment different steps as I go along with my installation, and I would manually do the steps that haven't been automated as yet (e.g. external HDD setup and `raspi-config` changes).

I also include sensitive values in a `.env` file in the top-level dir that gets sourced into the main script. The scripts currently expect the following variables:

```
# General device info
export LOCAL_IP=

# For backups
export DROPBOX_API_TOKEN=

# For lnd auto-unlock
export LND_UNLOCK_PWD=

# For Transmission UI
export TSM_USER=
export TSM_PASS=

# For Sphinx Relay
export SPHINX_PORT=     # optional

```
