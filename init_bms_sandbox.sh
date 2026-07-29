#!/bin/bash
set -e

echo "=== 1. Executing Automated Sandbox Cleanup ==="
docker compose down --volumes --remove-orphans 2>/dev/null || true

mkdir -p modbus-sim bacnet-sim nodered-data

retry_network_cmd() {
    local n=1
    local max=5
    local delay=5
    while true; do
        "$@" && break || {
            if [[ $n -lt $max ]]; then
                ((n++))
                echo "⚠️ Network disruption caught. Retrying command ($n/$max) in $delay seconds..."
                sleep $delay
            else
                echo "❌ Command failed permanently after $max attempts."
                return 1
            fi
        }
    done
}

# -------------------------------------------------------------------
# 2. GENERATE COMPREHENSIVE MULTI-CONTAINER TOPOLOGY
# -------------------------------------------------------------------
echo "=== 2. Writing Clean Environment Blueprints ==="
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
EOF

# -------------------------------------------------------------------
# 3. GENERATE V4-COMPLIANT MODBUS SIMULATOR ENGINE
# -------------------------------------------------------------------
cat << 'EOF' > modbus-sim/modbus_sim.py
import asyncio
import logging
import random
from pymodbus.server import ModbusTcpServer
from pymodbus.simulator import DataType, SimData, SimDevice

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

sim_data = SimData(address=1, datatype=DataType.REGISTERS, values=[1000, 0])
context = SimDevice(id=1, simdata=sim_data)

async def instrumentation_loop(server):
    logger.info("Modbus industrial register loop operational.")
    await asyncio.sleep(2)
    device_id, func_code, address = 1, 3, 1
    while True:
        await asyncio.sleep(4)
        try:
            values = await server.async_getValues(device_id, func_code, address, count=2)
            new_energy = (values[0] + random.randint(1, 3)) % 65535
            new_gen_status = 1 if random.random() > 0.85 else 0
            await server.async_setValues(device_id, func_code, address, [new_energy, new_gen_status])
            logger.info(f"[Modbus Register Map] HR1 (Energy): {new_energy} kWh | HR2 (Gen Run Status): {new_gen_status}")
        except Exception as err:
            logger.error(f"[Modbus Loop Error] {err}")

async def main():
    server = ModbusTcpServer(context=context, address=("0.0.0.0", 5020))
    asyncio.create_task(instrumentation_loop(server))
    logger.info("Spawning Modbus TCP Listener engine on internal container port 5020")
    await server.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
EOF

cat << 'EOF' > modbus-sim/Dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir pymodbus
COPY modbus_sim.py .
CMD ["python", "modbus_sim.py"]
EOF

# -------------------------------------------------------------------
# 4. GENERATE SPEC-COMPLIANT BACNET HVAC ENGINE
# -------------------------------------------------------------------
cat << 'EOF' > bacnet-sim/bacnet_sim.py
import time
import random
from threading import Thread
from bacpypes.core import run
from bacpypes.app import BIPSimpleApplication
from bacpypes.local.device import LocalDeviceObject
from bacpypes.object import AnalogInputObject, AnalogValueObject, BinaryInputObject

device = LocalDeviceObject(
    objectName="SimulatedAHU", objectIdentifier=("device", 1234),
    maxApduLengthAccepted=1476, segmentationSupported="segmentedBoth", vendorIdentifier=15,
)
room_temp_obj = AnalogInputObject(objectIdentifier=("analogInput", 1), objectName="RoomTemperature", presentValue=21.0)
temp_setpoint_obj = AnalogValueObject(objectIdentifier=("analogValue", 1), objectName="TemperatureSetpoint", presentValue=22.0)
fan_status_obj = BinaryInputObject(objectIdentifier=("binaryInput", 1), objectName="FanStatus", presentValue="active")

app = BIPSimpleApplication(device, "0.0.0.0")
for obj in [room_temp_obj, temp_setpoint_obj, fan_status_obj]: app.add_object(obj)

def physics_simulation_loop():
    while True:
        time.sleep(2)
        try:
            current_temp = room_temp_obj.presentValue
            setpoint = temp_setpoint_obj.presentValue
            if fan_status_obj.presentValue == "active":
                current_temp += (setpoint - current_temp) * 0.08 + random.uniform(-0.04, 0.04)
            else:
                current_temp += random.uniform(-0.12, 0.15)
            room_temp_obj.presentValue = round(current_temp, 2)
            if random.random() > 0.97:
                fan_status_obj.presentValue = "inactive" if fan_status_obj.presentValue == "active" else "active"
            print(f"[BACnet Engine] RoomTemp: {room_temp_obj.presentValue}°C | Setpoint: {setpoint}°C | Fan: {fan_status_obj.presentValue}", flush=True)
        except Exception as err:
            print(f"[BACnet Loop Error] {err}", flush=True)

if __name__ == "__main__":
    simulation_worker = Thread(target=physics_simulation_loop, daemon=True)
    simulation_worker.start()
    print("Initializing BACnet/IP Stack on 0.0.0.0:47808", flush=True)
    run()
EOF

cat << 'EOF' > bacnet-sim/Dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir bacpypes
COPY bacnet_sim.py .
CMD ["python", "bacnet_sim.py"]
EOF

# -------------------------------------------------------------------
# 5. GENERATE IMMUTABLE NODE-RED IMAGING & FLOW MAPS
# -------------------------------------------------------------------
cat << 'EOF' > nodered-data/Dockerfile
FROM nodered/node-red:latest
RUN npm install node-red-contrib-modbus node-red-contrib-bacnet
EOF

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
        "x": 150,
        "y": 140,
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
        "x": 380,
        "y": 140,
        "wires": [["modbus_debug_output"], []]
    },
    {
        "id": "modbus_debug_output",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "Modbus Telemetry Stream",
        "active": true,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 660,
        "y": 140,
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
        "x": 150,
        "y": 240,
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
        "x": 390,
        "y": 240,
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
        "x": 620,
        "y": 240,
        "wires": [["bacnet_debug_output"]]
    },
    {
        "id": "bacnet_debug_output",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "BACnet Telemetry Stream",
        "active": true,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 860,
        "y": 240,
        "wires": []
    }
]
EOF

chmod -R 777 nodered-data

# -------------------------------------------------------------------
# 6. RUNTIME INITIALIZATION
# -------------------------------------------------------------------
echo "=== 3. Running Resilient Multi-Container Build ==="
retry_network_cmd docker compose build
retry_network_cmd docker compose up -d

echo "=========================================================="
echo "SUCCESS: Permanent, High-Availability BMS Sandbox Online!"
echo "Supervisor Interface: http://localhost:1880"
echo "=========================================================="
