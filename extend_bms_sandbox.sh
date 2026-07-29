#!/bin/bash
set -e

echo "=== 1. Pausing Existing Core Network Services ==="
docker compose down --volumes --remove-orphans 2>/dev/null || true

# Establish storage paths for ThingsBoard engine
mkdir -p modbus-sim bacnet-sim nodered-data tb-data tb-log
chmod -R 777 tb-data tb-log nodered-data

# Network resilience helper function
retry_network_cmd() {
    local n=1
    local max=5
    local delay=5
    while true; do
        "$@" && break || {
            if [[ $n -lt $max ]]; then
                ((n++))
                echo "⚠️ Network glitch caught. Retrying docker operation ($n/$max)..."
                sleep $delay
            else
                return 1
            fi
        }
    done
}

# -------------------------------------------------------------------
# 2. GENERATE EXPANDED 4-CONTAINER INFRASTRUCTURE BLUEPRINT
# -------------------------------------------------------------------
echo "=== 2. Upgrading Container Topology Map ==="
cat << 'EOF' > docker-compose.yml
services:
  modbus-sim:
    build: ./modbus-sim
    container_name: bms-modbus-sim
    ports:
      - "5020:5020"
    restart: unless-stopped

  bacnet-sim:
    build: ./bacnet-sim
    container_name: bms-bacnet-sim
    ports:
      - "47808:47808/udp"
    restart: unless-stopped

  nodered:
    build: ./nodered-data
    container_name: bms-supervisor
    ports:
      - "1880:1880"
    volumes:
      - ./nodered-data:/data
    restart: unless-stopped

  thingsboard:
    image: thingsboard/tb-postgres
    container_name: bms-thingsboard
    ports:
      - "9090:8080"
    environment:
      - TB_QUEUE_TYPE=in-memory
    volumes:
      - ./tb-data:/data
      - ./tb-log:/var/log/thingsboard
    restart: unless-stopped
EOF

# -------------------------------------------------------------------
# 3. GENERATE FULLY INTEGRATED ANALYTICS FLOW
# -------------------------------------------------------------------
echo "=== 3. Injecting JavaScript PUE Engine & API Pipelines ==="
cat << 'EOF' > nodered-data/flows.json
[
    {
        "id": "bms_flow_tab",
        "type": "tab",
        "label": "BMS Sandbox Core Integration"
    },
    {
        "id": "modbus_server_config",
        "type": "modbus-client",
        "name": "BMS Modbus Power Meter",
        "clienttype": "tcp",
        "bufferCommands": true,
        "stateLogEnabled": false,
        "queueLogEnabled": false,
        "failureLogEnabled": true,
        "tcpHost": "bms-modbus-sim",
        "tcpPort": "5020",
        "tcpType": "DEFAULT",
        "serialPort": "/dev/ttyUSB0",
        "serialBaudrate": "9600",
        "serialDatabits": "8",
        "serialStopbits": "1",
        "serialParity": "none",
        "serialConnectionDelay": "100",
        "unit_id": "1",
        "timeout": "2000",
        "reconnectTimeout": "2000",
        "reconnectOnTimeout": true,
        "parallelUnitIdsAllowed": true,
        "showStatusActivities": false,
        "showErrors": false,
        "showWarnings": true,
        "logIOActivities": false,
        "ioFile": "",
        "useIOFile": false,
        "ioFileSize": 0
    },
    {
        "id": "bacnet_client_config",
        "type": "BACnet-Client",
        "name": "BMS BACnet HVAC Client",
        "interface": "0.0.0.0",
        "port": "47808",
        "broadcastAddress": "255.255.255.255",
        "adpuTimeout": "3000"
    },
    {
        "id": "bacnet_device_config",
        "type": "BACnet-Device",
        "name": "BACnet AHU Simulator",
        "deviceAddress": "bms-bacnet-sim"
    },
    {
        "id": "bacnet_instance_config",
        "type": "BACnet-Instance",
        "name": "RoomTemperatureInstance",
        "instanceAddress": "1"
    },
    {
        "id": "modbus_timer_trigger",
        "type": "inject",
        "z": "bms_flow_tab",
        "name": "Poll Timer (5s)",
        "props": [{"p": "payload"}],
        "repeat": "5",
        "once": true,
        "onceDelay": "0.1",
        "payloadType": "date",
        "x": 120,
        "y": 120,
        "wires": [["modbus_polling_node"]]
    },
    {
        "id": "modbus_polling_node",
        "type": "modbus-read",
        "z": "bms_flow_tab",
        "name": "Read Power Registers",
        "topic": "meter_data",
        "showStatusActivities": true,
        "logIOActivities": false,
        "showErrors": true,
        "showWarnings": true,
        "unitid": "1",
        "dataType": "HoldingRegister",
        "adr": "1",
        "quantity": "2",
        "rate": "5",
        "rateUnit": "s",
        "delayOnStart": false,
        "startDelayTime": "10",
        "server": "modbus_server_config",
        "useIOFile": false,
        "ioFile": "",
        "useIOForPayload": false,
        "emptyPayloadOnFailure": false,
        "clearQueue": false,
        "x": 340,
        "y": 120,
        "wires": [["modbus_debug_output", "bms_analytics_engine"], []]
    },
    {
        "id": "modbus_debug_output",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "Modbus Telemetry Stream",
        "active": false,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 580,
        "y": 80,
        "wires": []
    },
    {
        "id": "bacnet_timer_trigger",
        "type": "inject",
        "z": "bms_flow_tab",
        "name": "Poll Timer (5s)",
        "props": [{"p": "payload"}],
        "repeat": "5",
        "once": true,
        "onceDelay": "0.5",
        "payloadType": "date",
        "x": 120,
        "y": 220,
        "wires": [["bacnet_polling_node"]]
    },
    {
        "id": "bacnet_polling_node",
        "type": "BACnet-Read",
        "z": "bms_flow_tab",
        "name": "Read Room Temperature",
        "objectType": "0",
        "instance": "bacnet_instance_config",
        "propertyId": "85",
        "device": "bacnet_device_config",
        "server": "bacnet_client_config",
        "multipleRead": false,
        "x": 340,
        "y": 220,
        "wires": [["bacnet_cleaner_node"]]
    },
    {
        "id": "bacnet_cleaner_node",
        "type": "change",
        "z": "bms_flow_tab",
        "name": "Extract Temperature",
        "rules": [
            {
                "t": "set",
                "p": "payload",
                "pt": "msg",
                "to": "payload.values[0].value",
                "tot": "msg"
            }
        ],
        "action": "",
        "property": "",
        "from": "",
        "to": "",
        "reg": false,
        "x": 560,
        "y": 220,
        "wires": [["bacnet_debug_output", "bms_analytics_engine"]]
    },
    {
        "id": "bacnet_debug_output",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "BACnet Telemetry Stream",
        "active": false,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 780,
        "y": 260,
        "wires": []
    },
    {
        "id": "bms_analytics_engine",
        "type": "function",
        "z": "bms_flow_tab",
        "name": "DCIM Analytics Engine",
        "func": "if (msg.topic === \"meter_data\") {\n    flow.set(\"it_load\", msg.payload[0]);\n    flow.set(\"cooling_load\", msg.payload[1] === 0 ? 42 : 98);\n} else {\n    flow.set(\"room_temp\", msg.payload);\n}\n\nlet it = flow.get(\"it_load\") || 1020;\nlet cooling = flow.get(\"cooling_load\") || 42;\nlet temp = flow.get(\"room_temp\") || 21.5;\n\nlet it_kw = Math.round((it / 5) * 100) / 100;\nlet total = it_kw + cooling;\nlet pue = it_kw > 0 ? (total / it_kw) : 1.0;\n\nmsg.payload = {\n    IT_Load_kW: it_kw,\n    Cooling_Load_kW: cooling,\n    Total_Facility_Load_kW: total,\n    Calculated_PUE: parseFloat(pue.toFixed(2)),\n    UPS_Battery_Pct: 100,\n    Room_Temperature_C: temp\n};\n\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 780,
        "y": 140,
        "wires": [["thingsboard_http_post"]]
    },
    {
        "id": "thingsboard_http_post",
        "type": "http request",
        "z": "bms_flow_tab",
        "name": "ThingsBoard API Stream",
        "method": "POST",
        "ret": "txt",
        "paytoqs": "ignore",
        "url": "http://bms-thingsboard:8080/api/v1/sandbox_dcim_token/telemetry",
        "tls": "",
        "persist": false,
        "proxy": "",
        "insecureHTTPParser": false,
        "authType": "",
        "senderr": false,
        "headers": [],
        "x": 1020,
        "y": 140,
        "wires": [["thingsboard_debug_log"]]
    },
    {
        "id": "thingsboard_debug_log",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "ThingsBoard API Log",
        "active": true,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 1240,
        "y": 140,
        "wires": []
    }
]
EOF

# -------------------------------------------------------------------
# 4. RUNTIME INITIALIZATION
# -------------------------------------------------------------------
echo "=== 4. Launching Expanded Core Matrix ==="
retry_network_cmd docker compose build nodered
retry_network_cmd docker compose up -d

echo "=========================================================="
echo "SUCCESS: Extended Industrial Enterprise Stack Online!"
echo "Node-RED Supervisor Dashboard: http://localhost:1880"
echo "ThingsBoard BMS Head-End Server: http://localhost:9090"
echo "=========================================================="
echo "NOTE: ThingsBoard populates a SQL database structure on first boot."
echo "Please wait 60-90 seconds before logging into the portal UI."
echo "=========================================================="
