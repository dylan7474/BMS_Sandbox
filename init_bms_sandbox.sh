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
echo "=== 2. Writing Data Center Infrastructure Blueprints ==="
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
# 3. GENERATE HIGH-DENSITY DATA CENTER MODBUS PDU/UPS ENGINE
# -------------------------------------------------------------------
cat << 'EOF' > modbus-sim/modbus_sim.py
import asyncio
import logging
import random
from pymodbus.server import ModbusTcpServer
from pymodbus.simulator import DataType, SimData, SimDevice

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Data Center Power Map: [0]=IT_Load_kW, [1]=Cooling_kW, [2]=UPS_Battery_Pct, [3]=UPS_Load_Pct
sim_data = SimData(address=1, datatype=DataType.REGISTERS, values=[250, 110, 100, 68])
context = SimDevice(id=1, simdata=sim_data)

async def data_center_power_loop(server):
    logger.info("DCIM Power Train Monitoring Operational.")
    await asyncio.sleep(2)
    device_id, func_code, address = 1, 3, 1
    while True:
        await asyncio.sleep(4)
        try:
            # Simulate real-time server computational load spikes
            it_spike = random.randint(-15, 20)
            new_it_power = max(180, min(450, 250 + it_spike))
            
            # Mechanical cooling load scales dynamically based on server load heat dissipation
            new_cooling_power = int(new_it_power * 0.42 + random.randint(-5, 5))
            
            # Calculate total utilization draw on the UPS infrastructure
            new_ups_load = int(((new_it_power + new_cooling_power) / 600) * 100)
            new_battery = 100 if random.random() > 0.05 else 99
            
            await server.async_setValues(device_id, func_code, address, 
                                         [new_it_power, new_cooling_power, new_battery, new_ups_load])
            logger.info(f"[DC-PDU] IT Load: {new_it_power}kW | Mech Load: {new_cooling_power}kW | UPS Load: {new_ups_load}%")
        except Exception as err:
            logger.error(f"[DC-Power Error] {err}")

async def main():
    server = ModbusTcpServer(context=context, address=("0.0.0.0", 5020))
    asyncio.create_task(data_center_power_loop(server))
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
# 4. GENERATE HOT/COLD AISLE BACNET THERMAL MANAGEMENT ENGINE
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
    objectName="DataCenter_CRAC_Zone1", objectIdentifier=("device", 1234),
    maxApduLengthAccepted=1476, segmentationSupported="segmentedBoth", vendorIdentifier=15,
)

cold_aisle_temp = AnalogInputObject(objectIdentifier=("analogInput", 1), objectName="ColdAisleTemp", presentValue=20.5)
hot_aisle_temp = AnalogInputObject(objectIdentifier=("analogInput", 2), objectName="HotAisleTemp", presentValue=32.2)
crac_setpoint = AnalogValueObject(objectIdentifier=("analogValue", 1), objectName="CRAC_Setpoint", presentValue=21.0)

app = BIPSimpleApplication(device, "0.0.0.0")
for obj in [cold_aisle_temp, hot_aisle_temp, crac_setpoint]: 
    app.add_object(obj)

def thermodynamic_containment_loop():
    while True:
        time.sleep(2)
        try:
            sp = crac_setpoint.presentValue
            
            # Cold aisle calculation: impacted directly by CRAC airflow efficiency
            c_temp = cold_aisle_temp.presentValue
            cold_aisle_temp.presentValue = round(c_temp + (sp - c_temp) * 0.12 + random.uniform(-0.05, 0.05), 2)
            
            # Hot aisle calculation: simulates server delta-T heat rejection matching IT output
            server_delta_t = 11.5 + random.uniform(-0.3, 0.6)
            hot_aisle_temp.presentValue = round(cold_aisle_temp.presentValue + server_delta_t, 2)
            
            print(f"[CRAC Loop] Intake (Cold): {cold_aisle_temp.presentValue}°C | Exhaust (Hot): {hot_aisle_temp.presentValue}°C", flush=True)
        except Exception as err:
            print(f"[Thermal Sim Error] {err}", flush=True)

if __name__ == "__main__":
    sim_worker = Thread(target=thermodynamic_containment_loop, daemon=True)
    sim_worker.start()
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
# 5. GENERATE IMMUTABLE NODE-RED IMAGING & AUTOMATED DCIM FLOWS
# -------------------------------------------------------------------
cat << 'EOF' > nodered-data/Dockerfile
FROM nodered/node-red:latest
RUN npm install node-red-contrib-modbus node-red-contrib-bacnet
EOF

# JSON flow map containing the embedded JavaScript PUE calculation workspace
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
        "id": "bacnet_cold_instance",
        "type": "BACnet-Instance",
        "name": "ColdAisleInstance",
        "instanceAddress": "1"
    },
    {
        "id": "bacnet_hot_instance",
        "type": "BACnet-Instance",
        "name": "HotAisleInstance",
        "instanceAddress": "2"
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
        "y": 120,
        "wires": [["modbus_polling_node"]]
    },
    {
        "id": "modbus_polling_node",
        "type": "modbus-read",
        "z": "bms_flow_tab",
        "name": "Read Facility PDU Registers",
        "topic": "meter_data",
        "showStatusActivities": true,
        "logIOActivities": false,
        "showErrors": true,
        "showWarnings": true,
        "unitid": "1",
        "dataType": "HoldingRegister",
        "adr": "1",
        "quantity": "4",
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
        "x": 390,
        "y": 120,
        "wires": [["dcim_pue_calculator"], []]
    },
    {
        "id": "dcim_pue_calculator",
        "type": "function",
        "z": "bms_flow_tab",
        "name": "Calculate PUE Metric",
        "func": "let itPower = msg.payload[0];\nlet coolingPower = msg.payload[1];\nlet totalFacilityPower = itPower + coolingPower;\nlet PUE = totalFacilityPower / itPower;\n\nmsg.payload = {\n    \"IT_Load_kW\": itPower,\n    \"Cooling_Load_kW\": coolingPower,\n    \"Total_Facility_Load_kW\": totalFacilityPower,\n    \"Calculated_PUE\": parseFloat(PUE.toFixed(2)),\n    \"UPS_Battery_Pct\": msg.payload[2],\n    \"UPS_Load_Pct\": msg.payload[3]\n};\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 640,
        "y": 120,
        "wires": [["modbus_debug_output"]]
    },
    {
        "id": "modbus_debug_output",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "DCIM Power Analytics",
        "active": true,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 880,
        "y": 120,
        "wires": []
    },
    {
        "id": "bacnet_cold_trigger",
        "type": "inject",
        "z": "bms_flow_tab",
        "name": "Poll Timer (5s)",
        "props": [{"p": "payload"}],
        "repeat": "5",
        "once": true,
        "onceDelay": "0.5",
        "payloadType": "date",
        "x": 150,
        "y": 220,
        "wires": [["bacnet_cold_node"]]
    },
    {
        "id": "bacnet_cold_node",
        "type": "BACnet-Read",
        "z": "bms_flow_tab",
        "name": "Read Cold Aisle Temp",
        "objectType": "0",
        "instance": "bacnet_cold_instance",
        "propertyId": "85",
        "device": "bacnet_device_config",
        "server": "bacnet_client_config",
        "multipleRead": false,
        "x": 380,
        "y": 220,
        "wires": [["cold_cleaner_node"]]
    },
    {
        "id": "cold_cleaner_node",
        "type": "change",
        "z": "bms_flow_tab",
        "name": "Extract Cold Temp",
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
        "x": 630,
        "y": 220,
        "wires": [["bacnet_cold_debug"]]
    },
    {
        "id": "bacnet_cold_debug",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "Cold Aisle Data",
        "active": true,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 860,
        "y": 220,
        "wires": []
    },
    {
        "id": "bacnet_hot_trigger",
        "type": "inject",
        "z": "bms_flow_tab",
        "name": "Poll Timer (5s)",
        "props": [{"p": "payload"}],
        "repeat": "5",
        "once": true,
        "onceDelay": "0.7",
        "payloadType": "date",
        "x": 150,
        "y": 300,
        "wires": [["bacnet_hot_node"]]
    },
    {
        "id": "bacnet_hot_node",
        "type": "BACnet-Read",
        "z": "bms_flow_tab",
        "name": "Read Hot Aisle Temp",
        "objectType": "0",
        "instance": "bacnet_hot_instance",
        "propertyId": "85",
        "device": "bacnet_device_config",
        "server": "bacnet_client_config",
        "multipleRead": false,
        "x": 380,
        "y": 300,
        "wires": [["hot_cleaner_node"]]
    },
    {
        "id": "hot_cleaner_node",
        "type": "change",
        "z": "bms_flow_tab",
        "name": "Extract Hot Temp",
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
        "x": 630,
        "y": 300,
        "wires": [["bacnet_hot_debug"]]
    },
    {
        "id": "bacnet_hot_debug",
        "type": "debug",
        "z": "bms_flow_tab",
        "name": "Hot Aisle Data",
        "active": true,
        "tosidebar": true,
        "complete": "payload",
        "targetType": "msg",
        "x": 860,
        "y": 300,
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
echo "SUCCESS: Permanent Data Center DCIM Environment Online!"
echo "Supervisor Interface: http://localhost:1880"
echo "=========================================================="
