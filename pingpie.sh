#!/bin/bash

JSON_CONFIG='./config.json' # TODO: set this up to have an override mechanism when custom path provided
declare -A fail_counter
declare -A last_fired

main() {
	ensure_deps
	load_vars
	parse_config
	perform_checks
}

load_vars() {
	if [[ -f ".env" ]]; then
		echo 'Loading vars...'
		export $(grep -v '^#' .env | xargs)
	else
		echo "Error: .env not found."
		exit 1
	fi

	REQUIRED_VARS=("ACCOUNT_SID" "AUTH_TOKEN" "FROM_PHONE" "TO_PHONE")

	for var in "${REQUIRED_VARS[@]}"; do
		if [[ -z "${!var}" ]]; then
			echo "Error: Required variable $var is not set in $ENV_FILE."
			exit 1
		fi
	done
}

ensure_deps() {
	echo 'Verifying dependencies'
	local dependencies=("curl" "jq" "date")
	determine_package_manager

	for dep in "${dependencies[@]}"; do
		if ! command -v "$dep" &>/dev/null; then
			if [[ "$PACKAGE_MANAGER" == "UNKNOWN" ]]; then
				echo "$dep is not installed on your system and your package manager is unknown. Cannot auto-install. Exiting."
				return 1
			else
				prompt_install
			fi
		else
			echo "$dep is already installed."
		fi
	done
}

prompt_install() {
	read -rp "Would you like to install $dep with $PACKAGE_MANAGER? [y/n] " response

	if [[ "$response" == "y" || "$response" == "Y" ]]; then
		echo "Installing $dep with $PACKAGE_MANAGER..."
		$INSTALL_CMD "$dep"
		if [[ $? -ne 0 ]]; then
			echo "Failed to install $dep. Please install it manually."
		else
			echo "$dep installed successfully."
		fi
	else
		echo "$dep is required but was not installed. Exiting."
		exit 1
	fi
}

determine_package_manager() {
	if [[ -f /etc/os-release ]]; then
		. /etc/os-release
		case "$ID" in
		ubuntu | debian)
			PACKAGE_MANAGER="apt"
			INSTALL_CMD="sudo apt update && sudo apt install -y"
			;;
		fedora)
			PACKAGE_MANAGER="dnf"
			INSTALL_CMD="sudo dnf install -y"
			;;
		centos | rhel)
			PACKAGE_MANAGER="yum"
			INSTALL_CMD="sudo yum install -y"
			;;
		arch)
			PACKAGE_MANAGER="pacman"
			INSTALL_CMD="sudo pacman -Sy --noconfirm"
			;;
		*)
			PACKAGE_MANAGER="UNKNOWN"
			INSTALL_CMD="UNKNOWN"
			echo "Unsupported distribution. Please install dependencies manually."
			;;
		esac
	else
		PACKAGE_MANAGER="UNKNOWN"
		INSTALL_CMD="UNKNOWN"
		echo "/etc/os-release not found. Unable to determine package manager."
	fi
}

parse_config() {
	if [[ ! -f "$JSON_CONFIG" ]]; then
		echo "Error: JSON file $JSON_CONFIG not found."
		exit 1
	fi

	if jq -e '.alerts' "$JSON_CONFIG" &>/dev/null; then

		for alert in $(jq -c '.alerts[]' "$JSON_CONFIG"); do
			url=$(echo "$alert" | jq -r '.url')
			name=$(echo "$alert" | jq -r '.name')
			allowed_fails=$(echo "$alert" | jq -r '.allowedFails')

			if [[ -z "$url" || -z "$name" || ! "$allowed_fails" =~ ^[0-9]+$ ]]; then
				echo "Error: Invalid alert structure detected."
				exit 1
			fi
	    fail_counter["$name"]=0
	    last_fired["$name"]=0

			echo "Alert:"
			echo "  URL: $url"
			echo "  Name: $name"
			echo "  Allowed Fails: $allowed_fails"
		done
	else
		echo "Error: 'alerts' key is missing in the JSON data."
		exit 1
	fi
}

perform_checks() {
	first_alert=$(jq -c '.alerts[0].name' "$JSON_CONFIG")
	while true; do
    for alert in $(jq -c '.alerts[]' "$JSON_CONFIG"); do
      url=$(echo "$alert" | jq -r '.url')
	    name=$(echo "$alert" | jq -r '.name')
			allowed_fails=$(echo "$alert" | jq -r '.allowedFails')
			if [[ "$name" ==  "${first_alert//\"/}" ]]; then
	      sleep 30
			fi
			check
    done
  done
}

check() {
  response=$(curl -L --max-time 5 --write-out "%{http_code} %{url_effective}" --silent --output /dev/null "$url")
  http_code=$(echo "$response" | awk '{print $1}')
  final_url=$(echo "$response" | awk '{print $2}')

  if [[ "$http_code" =~ ^2 ]]; then
  	echo "Check for $url returned a 2xx"
	  fail_counter[$name]=0
  else
    echo "Error: Request to $url failed with HTTP status code $http_code."
    ((fail_counter["$name"]++))
  fi

  if [[ ${fail_counter[$name]} -gt $allowed_fails ]]; then
    handle_alert
  fi
}

handle_alert() {
	current_time=$(date +%s)
	time_diff=$((current_time - last_fired[$name]))

  if [[ "$time_diff" -gt 900 ]]; then
    alert
  fi
}

alert() {
	MESSAGE="Warning! Your alert for $name has failed! Please take action if necessary!"
	curl -X POST "https://api.twilio.com/2010-04-01/Accounts/$ACCOUNT_SID/Messages.json" \
	  --data-urlencode "Body=$MESSAGE" \
	  --data-urlencode "From=$FROM_PHONE" \
	  --data-urlencode "To=$TO_PHONE" \
	  -u "$ACCOUNT_SID:$AUTH_TOKEN"
}

main
