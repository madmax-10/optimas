# Optimas

Run Optimas on your computer with Docker. You **upload GPU profiling data** in the web app; Optimas then shows you the analysis. The stack is a web interface plus a backend API.

Source repository: [https://github.com/madmax-10/optimas.git](https://github.com/madmax-10/optimas.git)

## Get the project

```bash
git clone https://github.com/madmax-10/optimas.git
cd optimas
```

## What you need

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/) (included with Docker Desktop on Mac and Windows)

## Run the app

From the `optimas` folder:

```bash
docker compose up -d
```

Then open the **web app** in your browser:

- **http://localhost:5173**

The **API** is available at **http://localhost:8000** (the UI talks to it for you).

### Use the app

Optimas **only produces results after you upload your data** through the web interface. Pick the profiling files from your machine (for example Nsight-style CSV exports or the JSON metrics export your workflow uses), submit them as the app asks, then review the output on screen.

### Stop the app

```bash
docker compose down
```

### Update to the latest images

```bash
docker compose pull
docker compose up -d
```

## Sample data (`data/accuracy/`)

Example inputs live in **`data/accuracy/`**. Upload these files in the web app to see a full run without generating your own captures first. They are the same shapes Optimas expects from typical GPU profiler exports (roofline / Speed of Light CSVs, PC sampling CSV, and a JSON metrics bundle).

| Path | What it is |
|------|------------|
| `data/accuracy/main.cu` | CUDA source for the benchmark behind the samples (context only; not uploaded for results). |
| `data/accuracy/accuracy_roofline.csv` | Roofline / “GPU Speed Of Light” style export for one kernel. |
| `data/accuracy/accuracy_optimized_roofline.csv` | Same style of export for an optimized variant. |
| `data/accuracy/accuracy_pcsamp.csv` | PC sampling style export for the same workload. |
| `data/accuracy/errors_accuracy.json` | Detailed GPU metrics in JSON form. |

For your own work, export profiling data from your tools in the same general formats, then **upload those files in the web app** the same way to get results for your kernels.

## What runs where

| What | Address |
|------|---------|
| Web interface | http://localhost:5173 |
| API | http://localhost:8000 |
