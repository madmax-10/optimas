# Optimas

Optimas is a **GPU profiling analysis** tool you run locally with Docker. You upload profiling exports in the web app; Optimas analyzes them and shows results. The stack is a web UI plus a backend API.

Source repository: [https://github.com/madmax-10/optimas.git](https://github.com/madmax-10/optimas.git)

## Optimas setup guide

A step-by-step guide to installing and running Optimas with Docker.

### Step 1: Download and install Docker

Go to [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/) and download **Docker Desktop** for your operating system (Mac, Windows, or Linux). Run the installer and follow the prompts.

Launch Docker Desktop and wait until it is fully started — you will see the Docker whale icon in the system tray or menu bar when it is ready. **Docker Compose** is included with Docker Desktop on Mac and Windows, so no separate install is required.

### Step 2: Log in to Docker

Open a terminal (Command Prompt, PowerShell, or Mac/Linux terminal). Run:

```bash
docker login
```

Enter your Docker Hub username and password when prompted. If you do not have an account, create one for free at [https://hub.docker.com](https://hub.docker.com).

### Step 3: Clone the Optimas repository

```bash
git clone https://github.com/madmax-10/optimas.git
cd optimas
```

### Step 4: Mount the data directory

Before starting the app, link your local `data/` directory to `/app/data` inside the container so uploads persist across restarts and the backend always reads your local files.

Compose uses the **`DATA_PATH`** environment variable so the bind mount uses your current machine path — nothing is hardcoded in the YAML.

**Set the variable in the same terminal session** you will use for `docker compose`:

**Mac / Linux:**

```bash
export DATA_PATH=$(pwd)/data
```

**Windows (Command Prompt):**

```bat
set DATA_PATH=%cd%\data
```

**Windows (PowerShell):**

```powershell
$env:DATA_PATH = "$(Get-Location)\data"
```

### Step 5: Start the app

From inside the `optimas` folder:

```bash
docker compose up -d
```

Wait while Docker pulls images and starts containers (often a few minutes the first time). The volume mount from Step 4 applies automatically — no extra flags.

### Step 6: Open the web app

In your browser, open:

- **http://localhost:5173**

The backend API listens at **http://localhost:8000**; the UI talks to it for you — you do not need to open the API URL directly.

### Step 7: Upload your profiling data

In the web UI, upload your GPU profiling files (for example **Nsight-style CSV exports** or **JSON metrics** files).

To try a sample run first, use the example files in **`data/accuracy/statistics/`**:

- `accuracy_roofline.csv`
- `accuracy_optimized_roofline.csv`
- `accuracy_pcsamp.csv`
- `errors_accuracy.json`

After you submit, results appear on screen. Because `data/` is mounted into the container, files you add locally are visible inside the container without restarting.

### Step 8: Stop the app

```bash
docker compose down
```

This stops the containers cleanly. Your local **`data/`** folder and its contents are unchanged.

### Step 9: Update to the latest version (optional)

From the `optimas` folder:

```bash
docker compose pull
docker compose up -d
```

## Sample data (`data/accuracy/statistics/`)

These files match the shapes Optimas expects from typical GPU profiler exports (roofline / Speed of Light CSVs, PC sampling CSV, and a JSON metrics bundle).

| Path | What it is |
|------|------------|
| `data/accuracy/statistics/main.cu` | CUDA source for the benchmark behind the samples (context only; not uploaded for results). |
| `data/accuracy/statistics/accuracy_roofline.csv` | Roofline / “GPU Speed Of Light” style export for one kernel. |
| `data/accuracy/statistics/accuracy_optimized_roofline.csv` | Same style of export for an optimized variant. |
| `data/accuracy/statistics/accuracy_pcsamp.csv` | PC sampling style export for the same workload. |
| `data/accuracy/statistics/errors_accuracy.json` | Detailed GPU metrics in JSON form. |

For your own work, export from your tools in the same general formats, then upload those files in the web app the same way.

## What runs where

| What | Address |
|------|---------|
| Web interface | http://localhost:5173 |
| API | http://localhost:8000 |
