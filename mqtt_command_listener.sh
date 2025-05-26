#!/bin/bash

# Function to log messages to syslog and stdout
log_syslog() {
    local level="$1"
    local message="$2"
    logger -p "user.${level}" -t "mqtt_command_listener" "$message"
    echo "[${level^^}] $message"
}

# Load environment variables from .env file
set -a
source .env
set +a

# Ensure required variables are set
if [[ -z "$MQTT_BROKER" || -z "$MQTT_PORT" || -z "$MQTT_TOPIC" || -z "$MQTT_USER" || -z "$MQTT_PASS" ]]; then
    log_syslog "err" "Missing required environment variables. Check your .env file."
    exit 1
fi

# Handle clean exit and publish offline status
cleanup() {
    log_syslog "info" "Shutting down. Sending offline status..."
    if mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
        -t "$MQTT_STATUS_TOPIC" -m "offline" -r; then
        log_syslog "info" "Offline status sent successfully to $MQTT_STATUS_TOPIC"
    else
        log_syslog "err" "Failed to send offline status to $MQTT_STATUS_TOPIC"
    fi
    exit 0
}
trap cleanup SIGINT SIGTERM

log_syslog "info" "Starting MQTT listener..."

# Send retained 'online' status
log_syslog "info" "Publishing retained 'online' status..."
if mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
    -t "$MQTT_STATUS_TOPIC" -m "online" -r; then
    log_syslog "info" "Online status published successfully to $MQTT_STATUS_TOPIC"
else
    log_syslog "err" "Failed to publish online status to $MQTT_STATUS_TOPIC"
fi

while true; do
    log_syslog "info" "Attempting to connect to MQTT broker at $MQTT_BROKER:$MQTT_PORT on topic '$MQTT_TOPIC'..."

    mosquitto_sub -h "$MQTT_BROKER" -p "$MQTT_PORT" -t "$MQTT_TOPIC" -u "$MQTT_USER" -P "$MQTT_PASS" |
        while read -r message; do
            log_syslog "info" "Received: $message"

            case "$message" in
            "on")
                log_syslog "info" "Turning display on."
                ./turn_on_display.sh
                ;;
            "off")
                log_syslog "info" "Turning display off."
                ./turn_off_display.sh
                ;;
            *)
                log_syslog "warning" "Unknown command: $message"
                ;;
            esac
        done

    log_syslog "err" "Disconnected from MQTT broker. Retrying in 5 seconds..."
    sleep 5
done
