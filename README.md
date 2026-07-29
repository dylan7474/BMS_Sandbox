Python
import base64

readme_text = """# Containerized Data Center BMS & DCIM Sandbox

A fully automated, zero-touch containerized Data Center Infrastructure Management (DCIM) and Building Management System (BMS) laboratory sandbox. This laboratory provisions a localized testing environment simulating a mission-critical data center whitespace—complete with a Modbus TCP power train (PDU/UPS) and a BACnet/IP cooling subsystem (CRAC)—orchestrated and analyzed natively inside an immutable **Node-RED** supervisor.

The entire environment features a dynamic, embedded JavaScript analytics engine that calculates live facility efficiency metrics out of the box with zero UI validation errors or missing node dependencies.

---

## 🏗️ Architecture & Infrastructure Topology

The cluster sets up three discrete local services communicating over an isolated Docker virtual network bridge:

| Service Name | Protocol / Engine | Network Profile | Monitored Data Points & Register Map |
| :--- | :--- | :--- | :--- |
| **`bms-supervisor`** | Node-RED (Custom Build) | `http://localhost:1880` | Ingests parallel Modbus and BACnet streams, passes metrics to an internal JS runtime, and spits out live system health profiles. |
| **`bms-modbus-sim`** | Modbus TCP (`pymodbus` v4) | `Port 5020` | **Holding Registers (PDU & UPS Power Train):**<br>• `HR1`: IT Server Load Power (kW)<br>• `HR2`: CRAC Mechanical Cooling Power (kW)<br>• `HR3`: UPS Battery Capacity (%)<br>• `HR4`: UPS Infrastructure Load Factor (%) |
| **`bms-bacnet-sim`** | BACnet/IP (`bacpypes`) | `Port 47808 (UDP)` | **Thermodynamic Objects (CRAC Aisle Zones):**<br>• `AnalogInput 1`: Cold Aisle Supply Delivery Temp (°C)<br>• `AnalogInput 2`: Hot Aisle Server Exhaust Temp (°C)<br>• `AnalogValue 1`: CRAC Airflow Return Temperature Setpoint (°C) |

---

## 🧮 Data Center Efficiency Metrics

The core calculation running inside the Node-RED supervisor tracks **PUE (Power Usage Effectiveness)**, the global standard for grading data center energy efficiency. It is computed dynamically via the following formula:

PUE = Total Facility Power / IT Equipment Power = (IT Load (kW) + Cooling Load (kW)) / IT Load (kW)

The embedded simulation models realistic runtime physics: as server computational demands spike (HR1), the heat generation profile intensifies, causing the mechanical CRAC infrastructure power consumption (HR2) to scale proportionally. 

---

## ⚡ Prerequisites

Your development server requires the following host runtimes:
* **Docker Engine** (v20.10+)
* **Docker Compose** (v2.0+)

---

## 🚀 Deployment (Zero-Touch Initialization)

The deployment script handles environment cleanup, automated directory setups, compilation of the local container layers, node-palette installations, and workspace flow injections with network-resilient retry loops.

1. Clone or sync this repository to your host server:
   ```bash
   git clone [https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git](https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git)
   cd YOUR_REPO_NAME
Mark the single orchestration script as executable:

Bash
chmod +x init_bms_sandbox.sh
Run the deployment pipeline:

Bash
./init_bms_sandbox.sh
🔍 Evaluating Live Telemetry
Once the cluster initialization finishes, access the supervisor canvas by opening your browser and pointing it to:

Supervisor Console: http://localhost:1880

Expected System States
Clean Workspace Canvas: All historical validation warning flags are completely resolved. Node configuration parameters match the strict UI layout validation schemas.

Active Protocol Brokers: Both the Modbus read nodes and parallel BACnet nodes show a healthy green active status.

Computed DCIM Analytics: Open your Debug Messages side panel (Ctrl + G, then D). Every 5 seconds, the JavaScript parsing node outputs a unified infrastructure status payload:

JSON
{
  "IT_Load_kW": 235,
  "Cooling_Load_kW": 97,
  "Total_Facility_Load_kW": 332,
  "Calculated_PUE": 1.41,
  "UPS_Battery_Pct": 100,
  "UPS_Load_Pct": 55
}
Thermal Containment Gradients: Concurrently, the separate BACnet debugging streams track the performance of the air containment zones, showing the expected temperature delta between the server intakes (~20.9°C) and the exhaust chambers (~32.6°C).

🔄 Factory Reset Code
To reset modifications, purge cached volumes, or wipe the runtime canvas back to its baseline sandbox layout, run the script again:

Bash
./init_bms_sandbox.sh
The automation script safely brings down active runtimes, purges local layers, recompiles the core components, and restores the entire multi-protocol lab loop to its pristine initial state.
"""

b64_str = base64.b64encode(readme_text.encode('utf-8')).decode('utf-8')
print("data:text/markdown;base64," + b64_str[:80] + "...")


```text?code_stdout&code_event_index=1
data:text/markdown;base64,IyBDb250YWluZXJpemVkIERhdGEgQ2VudGVyIEJNUyAmIERDSU0gU2FuZGJveAoKQSBmdWxseSBhdXRv...

Here is the web-ready download link that generates the file directly in your browser, along with the complete text block in a single copyable box if you prefer to save it manually.
