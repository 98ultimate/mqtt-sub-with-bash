#!/bin/bash

# Load environment variables from .env file
set -a
source .env
set +a

# Ensure required variables are set
if [[ -z "$MQTT_BROKER" || -z "$MQTT_PORT" || -z "$MQTT_TOPIC" || -z "$MQTT_USER" || -z "$MQTT_PASS" ]]; then
    echo "Missing required environment variables. Check your .env file."
    exit 1
fi

# Handle clean exit and publish offline status
cleanup() {
    echo "[INFO] Shutting down. Sending offline status..."
    if mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
        -t "$MQTT_STATUS_TOPIC" -m "offline" -r; then
        echo "[INFO] Offline status sent successfully to $MQTT_STATUS_TOPIC"
    else
        echo "[ERROR] Failed to send offline status to $MQTT_STATUS_TOPIC"
    fi
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "[INFO] Starting MQTT listener..."

# Send retained 'online' status
echo "[INFO] Publishing retained 'online' status..."
if mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
    -t "$MQTT_STATUS_TOPIC" -m "online" -r; then
    echo "[INFO] Online status published successfully to $MQTT_STATUS_TOPIC"
else
    echo "[ERROR] Failed to publish online status to $MQTT_STATUS_TOPIC"
fi

while true; do
    echo "[INFO] Attempting to connect to MQTT broker at $MQTT_BROKER:$MQTT_PORT on topic '$MQTT_TOPIC'..."

    mosquitto_sub -h "$MQTT_BROKER" -p "$MQTT_PORT" -t "$MQTT_TOPIC" -u "$MQTT_USER" -P "$MQTT_PASS" |
        while read -r message; do
            echo "[MESSAGE] Received: $message"

            case "$message" in
            "on")
                echo "[ACTION] Turning display on."
                ./light_control.sh on
                ;;
            "off")
                echo "[ACTION] Turning display off."
                ./light_control.sh off
                ;;
            *)
                echo "[WARN] Unknown command: $message"
                ;;
            esac
        done

    echo "[ERROR] Disconnected from MQTT broker. Retrying in 5 seconds..."
    sleep 5
done
