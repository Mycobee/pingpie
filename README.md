# About

PingPie is a dead simple FOSS uptime monitoring tool that can be used on Linux systems. It integrates with Twilio to text when a site goes down. It is designed for hobbyists, small teams, and freelancers to have a nearly free uptime.com alternative that can run on a simple device such as a Raspberry Pi. It runs volleys of checks every 30ish seconds.

Currently, the notification mechanism uses Twilio, but PRs for other providers will be considered.

## Setup

1. Install `jq`, `date`, and `curl` on your system. (This will not work with Darwin date currently, only GNU date and Bash versions >= 4.xx)
1. Create a valid configuration file with your desired alerts, using the same format as the `exampleconfig.json` file provided in this project
1. Set the environment variables required in the `.env.example` file, in a file called `.env`
1. Run the script `./pingpie.sh`

### Limitations

- This script will not exit on failure. This is by design, as the goal is to not have your alerting system crash if possible. There is currently no way to know if the script is messing up, other than viewing your logs.
- This script will run your checks, the sleep 30 seconds before the next volley of checks. This timing is not exact, so if it takes 15 seconds for all checks to complete all your checks, the next round of checks will be 45 seconds from start the original round.
- This script uses bash and normal shell utilities, which come with their own limitations. This was chosen for portability and simplicity reasons. Most Linux systems can run this script, and no need to distribute it via a compiled binary or different architectures. One day I might rewrite in Go, if I need to scale it. But for now, Bash it is!

### Gratitude

Thank you to all the giants, on whose shoulders I stand tall. Without you I wouldn't be here. I am he as you are me as you are :bee: and we are all together :heart:
