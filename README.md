# Containerized Data Center BMS & DCIM Sandbox

A fully automated, zero-touch containerized Data Center Infrastructure Management (DCIM) and Building Management System (BMS) laboratory sandbox. This repository provisions a localized testing environment simulating a mission-critical data center whitespace—complete with a Modbus TCP power train (PDU/UPS) and a BACnet/IP cooling subsystem (CRAC)—orchestrated and analyzed natively inside an immutable **Node-RED** supervisor.

The entire environment features a dynamic, embedded JavaScript analytics engine that calculates live facility efficiency metrics out of the box with zero UI validation errors or missing node dependencies.

## 🏗️ Architecture & Infrastructure Topology

The cluster sets up three discrete local services communicating over an isolated Docker virtual network bridge:

| Service Name | Protocol / Engine | Network Profile | Monitored Data Points & Register Map |
| :--- | :--- | :--- | :--- |
| **`bms-supervisor`** | Node-RED (Custom Build) | `http://localhost:1880` | Ingests parallel Modbus and BACnet streams, passes metrics to an internal JS runtime, and spits out live system health profiles. |
| **`bms-modbus-sim`** | Modbus TCP (`pymodbus` v4) | `Port 5020` | **Holding Registers (PDU & UPS Power Train):**<br>• `HR1`: IT Server Load Power (kW)<br>• `HR2`: CRAC Mechanical Cooling Power (kW)<br>• `HR3`: UPS Battery Capacity (%)<br>• `HR4`: UPS Infrastructure Load Factor (%) |
| **`bms-bacnet-sim`** | BACnet/IP (`bacpypes`) | `Port 47808 (UDP)` | **Thermodynamic Objects (CRAC Aisle Zones):**<br>• `AnalogInput 1`: Cold Aisle Supply Delivery Temp (°C)<br>• `AnalogInput 2`: Hot Aisle Server Exhaust Temp (°C)<br>• `AnalogValue 1`: CRAC Airflow Return Temperature Setpoint (°C) |

## 🧮 Data Center Efficiency Metrics

The core calculation running inside the Node-RED supervisor tracks **PUE (Power Usage Effectiveness)**, the global standard for grading data center energy efficiency. It is computed dynamically via the following formula:

$$
PUE = \frac{\text{Total Facility Power}}{\text{IT Equipment Power}} = \frac{\text{IT Load (kW)} + \text{Cooling Load (kW)}}{\text{IT Load (kW)}}
$$

The embedded simulation models realistic runtime physics: as server computational demands spike (`HR1`), the heat generation profile intensifies, causing the mechanical CRAC infrastructure power consumption (`HR2`) to scale proportionally.

## ⚡ Prerequisites

Your development server requires the following host runtimes:

* **Docker Engine** (v20.10+)
* **Docker Compose** (v2.0+)

## 🚀 Quick Start (Zero-Touch Deployment)

The included environment bootstrap script handles absolute directory sandboxing, container imaging builds, dependency injection, and workspace blueprint deployment with built-in network fault-tolerance loops.

1. Clone this repository to your local system:

   
```bash
   git clone https://github.com/dylan7474/BMS_Sandbox.git
   cd BMS_Sandbox

Once the extend_bms_sandbox.sh script has been completed, you can login to http://localhost:9090 and log in with the tenant credentials (tenant@thingsboard.org / tenant).
