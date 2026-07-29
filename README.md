# Zero-Touch Containerized BMS Industrial Sandbox

A fully automated, containerized Building Management System (BMS) laboratory sandbox. This repository provisions a local multi-protocol testing ground containing simulated **Modbus TCP** power meters and **BACnet/IP** HVAC controllers, all seamlessly pre-wired into an immutable **Node-RED** supervisor orchestrator.

The entire stack initializes completely from scratch with zero validation errors, missing nodes, or network topology bottlenecks.

---

## 🏗️ Architecture & Topology

The environment deploys three discrete local services orchestrated inside an isolated Docker network bridge:

| Service Name | Protocol / Engine | Network Profile | Purpose / Data Map |
| :--- | :--- | :--- | :--- |
| **`bms-supervisor`** | Node-RED (Latest) | `http://localhost:1880` | Pre-baked protocol palettes (`modbus`, `bacnet`) pulling & parsing automated live workflows. |
| **`bms-modbus-sim`** | Modbus TCP (`pymodbus` v4) | `Port 5020` | **Holding Registers:**<br>• `HR1`: Total Energy Consumption (kWh)<br>• `HR2`: Generator Running Status (0/1) |
| **`bms-bacnet-sim`** | BACnet/IP (`bacpypes`) | `Port 47808 (UDP)` | **Actinide Space Mappings:**<br>• `AnalogInput 1`: Room Temp Actual (°C)<br>• `AnalogValue 1`: Temp Setpoint (°C)<br>• `BinaryInput 1`: Fan Run State |

---

## ⚡ Prerequisites

Ensure your development host has the standard containerization runtimes installed:
* **Docker Engine** (v20.10+)
* **Docker Compose** (v2.0+)

---

## 🚀 Quick Start (Zero-Touch Deployment)

The included environment bootstrap script handles absolute directory sandboxing, container imaging builds, dependency injection, and workspace blueprint deployment with built-in network fault-tolerance loops.

1. Clone this repository to your local system:
   ```bash
   git clone https://github.com/dylan7474/BMS_Sandbox.git
   cd BMS_Sandbox
   chmod +X init_bms_sandbox.sh
   ./init_bms_sandbox.sh
