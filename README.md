Kafka Connector Watchdog
========================

A utility to detect failed Kafka Connector tasks and recover them automatically.

The script in `src/restart_kafka_connectors.sh` queries the [Kafka Connect](https://kafka.apache.org/42/kafka-connect/overview/) REST API, attempts to restart failed connector tasks, and if a connector still fails it deletes and re-creates the connector using its current configuration.

## Features

- Detects failed connector tasks via Kafka Connect REST API
- Restarts failed tasks
- If restart fails, deletes and re-creates the connector using its stored configuration
- Supports dry-run mode for safe validation

## Usage

From the repository root:

```sh
./src/restart_kafka_connectors.sh --url http://kafka-connect-host:8083
```

Input can be provided either as command-line arguments or through environment variables.

### Options

- `--url <url>`
  - Kafka Connect REST API base URL
  - Default: `http://localhost:8083`
- `--dryrun` or `--dry-run`
  - Print the API calls without executing them

### Environment Variables

- `KAFKA_CONNECT_URL`
  - If set, overrides the default Kafka Connect URL
- `DRY_RUN`
  - If set to `1` or `true`, enables dry-run mode

### Example

Run against a remote Kafka Connect cluster:

```sh
KAFKA_CONNECT_URL=http://kafka-connect-host:8083 ./src/restart_kafka_connectors.sh
```

Run in dry-run mode:

```sh
./src/restart_kafka_connectors.sh --dry-run
```

```sh
DRY_RUN=1 ./src/restart_kafka_connectors.sh --url http://kafka-connect-host:8083
```
