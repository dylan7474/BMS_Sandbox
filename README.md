# Smart Facility Management Sandbox

This repository provides a fully functioning, self-contained smart facility
management sandbox. It runs on a single server in an isolated Docker environment
and emulates the automation systems found in an industrial building or data
center.

## System Layers

The sandbox is organized into three core layers:

1. **Virtual Equipment (the floor)** — Live equipment simulators model smart
   industrial electricity meters over Modbus TCP and heavy-duty heating and
   cooling equipment over BACnet/IP. The simulated points include electrical
   power draw and HVAC temperatures.
2. **Supervisor (the brain)** — Node-RED continuously polls the virtual
   equipment, processes the raw measurements, calculates live efficiency
   metrics such as Power Usage Effectiveness (PUE), and packages the results
   into clean telemetry streams.
3. **Head-End Central Portal (the control room)** — ThingsBoard provides the
   enterprise IoT and BMS web console. Node-RED streams calculated telemetry to
   ThingsBoard for real-time charts, historical trends, and interactive
   controls.

## Built-in Storage Protection

Every container uses Docker's `json-file` log driver with automated rotation.
Each log file is limited to 10 MB and each service retains no more than five
files, capping its rotated Docker logs at approximately 50 MB. These guardrails
prevent a persistent component error from consuming unbounded host disk space.

## Architecture

Data moves sequentially through the deployment without depending on an external
proxy, mobile framework, or host-specific networking tool:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                          CLIENT WEB BROWSER                            │
│             (Accessing the system via local network or VPN)            │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                        HTTP / Web Portal Traffic
                                   ▼
=========================== TARGET HOST SERVER ===========================
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │               STANDARD EXPOSED HOST NETWORK PORTS            │     │
│   ├──────────────────────────────┬───────────────────────────────┤     │
│   │ Port 9090: ThingsBoard UI    │ Port 1880: Node-RED Gateway   │     │
│   │ Port 5020: Modbus TCP        │ Port 47808: BACnet/IP (UDP)   │     │
│   └──────────────────────────────┴───────────────────────────────┘     │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                 ISOLATED DOCKER VIRTUAL BRIDGE                 │   │
│   │       Containers communicate on a private sandbox subnet      │   │
│   └─┬───────────────────────────┬──────────────────────────────┬───┘   │
│     │                           │                              │       │
│     ▼                           ▼                              ▼       │
│ ┌────────────────┐        ┌────────────────┐       ┌─────────────────┐ │
│ │ bms-modbus-sim │        │ bms-bacnet-sim│       │ bms-thingsboard │ │
│ │   Simulator    │        │   Simulator    │       │  Head-End + DB  │ │
│ └───────┬────────┘        └────────┬───────┘       └────────▲────────┘ │
│         │                          │                        │          │
│         │ Raw Modbus TCP           │ Raw BACnet/IP         │          │
│         │ (power data)             │ (HVAC temperature)    │          │
│         └──────────────┐    ┌──────┘                        │          │
│                        ▼    ▼                               │          │
│                  ┌────────────────┐                         │          │
│                  │ bms-supervisor │                         │          │
│                  │   Node-RED     │                         │          │
│                  ├────────────────┤                         │          │
│                  │ 1. Poll timers │                         │          │
│                  │ 2. Logic engine│                         │          │
│                  └───────┬────────┘                         │          │
│                          │                                  │          │
│                          └── HTTP API / JSON telemetry ─────┘          │
│                              (private container network)               │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## Services and Ports

| Service | Container | Role | Host endpoint |
| --- | --- | --- | --- |
| ThingsBoard | `bms-thingsboard` | Central BMS portal, telemetry visualization, and PostgreSQL-backed storage | `http://localhost:9090` |
| Node-RED | `bms-supervisor` | Equipment polling, supervisory logic, PUE calculation, and telemetry forwarding | `http://localhost:1880` |
| Modbus simulator | `bms-modbus-sim` | Industrial electricity meter and power data | Modbus TCP port `5020` |
| BACnet simulator | `bms-bacnet-sim` | HVAC and temperature data | BACnet/IP UDP port `47808` |

When accessing the host from another computer, replace `localhost` with the
server's local-network or VPN address.

## Data Flow and Efficiency Metrics

1. Node-RED polls the electricity meter simulator over Modbus TCP and the HVAC
   simulator over BACnet/IP.
2. The supervisor normalizes the readings and calculates total facility load
   and PUE.
3. Node-RED sends JSON telemetry directly to ThingsBoard over the private Docker
   network.
4. ThingsBoard stores and presents current values, historical trends, charts,
   and controls in its central web portal.

PUE is calculated as:

```text
PUE = Total Facility Power / IT Equipment Power
    = (IT Load + Cooling Load) / IT Load
```

## Core Architecture Rules

- **Standard port alignment:** ThingsBoard is exposed on host port `9090`, while
  Node-RED uses `1880`, Modbus TCP uses `5020`, and BACnet/IP uses UDP `47808`.
- **Isolated internal communications:** Node-RED posts telemetry to
  `http://bms-thingsboard:9090` using Docker's private DNS and bridge network. It
  does not route container-to-container traffic through the host interface.
- **Contained and repeatable deployment:** The framework can be created,
  started, stopped, or removed as a unit with Docker Compose, making deployments
  repeatable on any compatible server.

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 2.0 or later (`docker compose`)
- A Linux host capable of running Bash scripts
- Host firewall access to the ports required by your deployment

## Deployment

Clone the repository and enter its directory:

```bash
git clone https://github.com/dylan7474/BMS_Sandbox.git
cd BMS_Sandbox
```

Initialize the three-service equipment and supervisor sandbox:

```bash
./init_bms_sandbox.sh
```

Then extend it with the ThingsBoard head-end and log-rotation guardrails:

```bash
./extend_bms_sandbox.sh
```

Both scripts are deployment helpers and run Docker Compose on your behalf. Note
that the initialization script removes existing Compose volumes as part of its
clean reset. After deployment, verify the services:

```bash
docker compose ps
```

Open the web interfaces:

- ThingsBoard: <http://localhost:9090>
- Node-RED: <http://localhost:1880>

The default ThingsBoard tenant credentials are:

- **Username:** `tenant@thingsboard.org`
- **Password:** `tenant`

Change default credentials before exposing the service beyond a trusted sandbox
network.

## Create a Simulated Data Flow in ThingsBoard

After deploying the stack, complete the following one-time setup to connect a
ThingsBoard device to the telemetry that Node-RED is already publishing.

### Phase 1: Provision the Device

1. Open the ThingsBoard central console at <http://localhost:9090>. When
   accessing the sandbox remotely, replace `localhost` with the server's
   network IP address.
2. Log in with your ThingsBoard credentials. The sandbox defaults are
   `tenant@thingsboard.org` for the username and `tenant` for the password.
3. In the left navigation sidebar, select **Entities**, and then select
   **Devices**.
4. Click the **+** (**Add Device**) icon in the top-right corner of the table,
   and select **Add new device**.
5. In the **Name** field, enter a clear device name such as `Data Center Core`,
   and click **Add**.
6. A connectivity wizard displays sample test commands. These commands are not
   needed for this data flow; click **Close** or the **X** in the top-right
   corner.

### Phase 2: Match the Device to the Automation Flow

Node-RED is preconfigured to publish telemetry with a standardized access
token. Assign that same token to the new ThingsBoard device:

1. In the **Devices** table, click the row for the device you just created. A
   device details panel opens on the right.
2. At the top of the details panel, click **Manage credentials**.
3. Clear the randomly generated value in the **Access token** field and enter
   the repository token exactly as shown:

   ```text
   sandbox_dcim_token
   ```

4. Click **Save**.

### Phase 3: Verify Live Telemetry

1. In the device details panel, select the **Latest telemetry** tab.
2. Allow 5 to 10 seconds for the first readings to arrive. The table should
   populate automatically and continue refreshing with live values.
3. Confirm that telemetry keys such as `Calculated_PUE`, `IT_Load_kW`,
   `Cooling_Load_kW`, and `Room_Temperature_C` appear and change as the
   simulator loops run.

The simulated equipment, Node-RED supervisor, and ThingsBoard device now form a
verified, closed-loop telemetry pipeline.

## Operations

Start or recreate the complete stack:

```bash
docker compose up -d
```

Stop the stack while preserving its persistent data:

```bash
docker compose down
```

Follow service logs:

```bash
docker compose logs --follow
```

Remove the stack and its Docker-managed volumes when a full reset is required:

```bash
docker compose down --volumes --remove-orphans
```
