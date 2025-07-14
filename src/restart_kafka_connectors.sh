#!/usr/bin/env bash

set -e

FONT_ESC=$(printf '\033')
FONT_BOLD=${FONT_ESC}[1m
FONT_NC=${FONT_ESC}[0m # No colour

function get_config {

    kafka_connect_url=$1
    connector_name=$2

    if [[ -z "$kafka_connect_url" ]]; then
        echo "No Kafka Connect URL is set"
    else
        if [[ -n "$connector_name" ]]; then
            curl --location "$kafka_connect_url/connectors/$connector_name" | jq -cj '{name: .name, config: .config}'
        else
            echo 'No connector name set for retrieving configuration'
        fi
    fi
}

function delete_connector {

    kafka_connect_url=$1
    is_dry_run=$2
    connector_name=$3

    if [[ -z "$kafka_connect_url" ]]; then
        echo "No Kafka Connect URL is set"
    else
        if [[ -n "$connector_name" ]]; then
            if [[ $is_dry_run == 1 ]]; then
                echo '  (dry-run) ' curl --location --request DELETE "$kafka_connect_url/connectors/$connector_name"
            else
                curl --location --request DELETE "$kafka_connect_url/connectors/$connector_name"
            fi
        else
            echo 'No connector name set for deletion'
        fi
    fi
}

function add_connector {

    kafka_connect_url=$1
    is_dry_run=$2
    connector_configuration=$3

    if [[ -z "$kafka_connect_url" ]]; then
        echo "No Kafka Connect URL is set"
    else
        if [[ -n "$connector_configuration" ]]; then
            if [[ $is_dry_run == 1 ]]; then
                echo '  (dry-run) ' curl --location "$kafka_connect_url/connectors" --header 'Content-Type: application/json' --data "'$connector_configuration'"
            else
                curl --location "$kafka_connect_url/connectors" --header 'Content-Type: application/json' --data $connector_configuration
            fi
        else
            echo 'No connector configuration set'
        fi
    fi
}

function get_connector_task_status {

    kafka_connect_url=$1
    connector_name=$2
    connector_task_id=$3

    if [[ -z "$kafka_connect_url" ]]; then
        echo "No Kafka Connect URL is set"
    else
        if [[ -n "$connector_name" ]]; then
            if [[ -n "$connector_task_id" ]]; then
                curl --location "$kafka_connect_url/connectors/$connector_name/tasks/$connector_task_id/status"
            else
                echo 'No connector task ID set to get task status'
            fi
        else
            echo 'No connector name set to get task status'
        fi
    fi
}

function restart_connector_task {

    kafka_connect_url=$1
    is_dry_run=$2
    connector_name=$3
    connector_task_id=$4

    if [[ -z "$kafka_connect_url" ]]; then
        echo "No Kafka Connect URL is set"
    else
        if [[ -n "$connector_name" ]]; then
            if [[ -n "$connector_task_id" ]]; then
                if [[ $is_dry_run == 1 ]]; then
                    echo '  (dry-run) ' curl --location --request POST "$kafka_connect_url/connectors/$connector_name/tasks/$connector_task_id/restart"
                else
                    curl --location --request POST "$kafka_connect_url/connectors/$connector_name/tasks/$connector_task_id/restart"
                fi
            else
                echo 'No connector task ID set for restart'
            fi
        else
            echo 'No connector name set for restart'
        fi
    fi
}

function show_help {
    echo "Example command: ./restart_kafka_connectors.sh --url http://kafka-connect-host:8083 --dry-run"
}

kafka_connect_url="${KAFKA_CONNECT_URL:-http://localhost:8083}"
is_dry_run=0
connectors_to_check=()

[[ -n "${DRY_RUN}" && ($DRY_RUN == "1" || $DRY_RUN == "true") ]] && is_dry_run=1

while [[ $1 == -* ]]; do
    case "$1" in
      --url) if [[ $# -gt 1 && $2 != -* ]]; then
            kafka_connect_url=$2; shift 2
          fi ;;
      --dryrun) is_dry_run=1; shift;;
      --dry-run) is_dry_run=1; shift;;
      --) shift; break;;
      -*) echo "invalid option: $1" 1>&2; show_help; exit 1;;
    esac
done

connectors=$(curl -s "$kafka_connect_url/connectors?expand=info&expand=status" | jq -e -c -M 'map({name: .status.name } + {connector_class: .info.config."connector.class" } + {tasks: .status.tasks}) | .[] | {task: ((.tasks[]) + {name: .name} + {connector_class: .connector_class})} | select(.task.state=="FAILED") | {name: .task.name, connector_class: .task.connector_class, task_id: .task.id|tostring}')

for entry in $connectors; do

    connector_name=$(echo $entry | jq --raw-output '.name')
    connector_task_id=$(echo $entry | jq --raw-output '.task_id')
    connector_class=$(echo $entry | jq --raw-output '.connector_class')

    echo "Attemping to restart failed connector and task: ${FONT_BOLD}$connector_name $connector_task_id${FONT_NC} ..."

    restart_connector_task $kafka_connect_url $is_dry_run $connector_name $connector_task_id

    echo "Waiting for connector and task: ${FONT_BOLD}$connector_name $connector_task_id${FONT_NC} ..."
    sleep 30

    echo "Querying connector and task status: ${FONT_BOLD}$connector_name $connector_task_id${FONT_NC} ..."

    if get_connector_task_status $kafka_connect_url $connector_name $connector_task_id | jq --exit-status '.state == "RUNNING"' > /dev/null; then
        echo "Successfully restarted connector and task: ${FONT_BOLD}$connector_name $connector_task_id${FONT_NC}"
    else
        echo "Connector task is not in RUNNING state, will attempt to re-install connector later: ${FONT_BOLD}$connector_name${FONT_NC}"
        connectors_to_check+=($connector_name)
    fi

done

distinct_connectors_to_check=($(for connector_name in "${connectors_to_check[@]}"; do echo "${connector_name}"; done | sort -u))

for connector_name in ${distinct_connectors_to_check[*]}; do

    echo "Retrieving connector configuration: ${FONT_BOLD}$connector_name${FONT_NC} ..."
    connector_configuration=$(get_config $kafka_connect_url $connector_name)

    echo "Deleting connector: ${FONT_BOLD}$connector_name${FONT_NC} ..."
    delete_connector $kafka_connect_url $is_dry_run $connector_name

    echo "Waiting for connector to be deleted: ${FONT_BOLD}$connector_name${FONT_NC} ..."
    sleep 30

    echo "Re-adding connector: ${FONT_BOLD}$connector_name${FONT_NC} ..."
    add_connector $kafka_connect_url $is_dry_run $connector_configuration

    echo "\n"
    echo "Waiting for connector to be started: ${FONT_BOLD}$connector_name${FONT_NC} ..."
    sleep 30

done
