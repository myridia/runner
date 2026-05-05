
## ![Runnger](pages/public/img/icon_192x192.png) Runner
* Pre-Installed Tools for Speed

This setup allows you to define a dedicated Docker container, the "runner," that executes specific scripts *after* your other essential services (like databases or web applications) have started and are ready. This is invaluable for tasks such as:

*   Database migrations
*   Data seeding
*   Cache warming
*   Post-deployment cleanup or configuration

### Why a "Fatty" Runner?

The term "fatty" runner refers to a Docker image that comes pre-installed with a comprehensive set of tools and dependencies. This approach significantly speeds up execution time because:

*   **No On-Demand Installation:** When the runner container starts, all necessary tools (e.g., `psql`, `curl`, `wget`, `jq`, specific SDKs, language runtimes) are already present. You avoid the time-consuming process of downloading and installing these tools within the container during the job execution.
*   **Faster Job Turnaround:** In CI/CD pipelines (like GitHub Actions, GitLab CI) or local orchestration tools (like `act`), every second counts. A pre-built "fatty" runner minimizes the "time to task" by eliminating installation delays.
*   **Reliability:** Reduces the chance of installation failures during a critical task execution.

**To create a "fatty" runner:**

You would typically have a `Dockerfile` for your `myridia/runner` image that installs all required packages. For example:

```dockerfile
# Dockerfile for myridia/runner (example)
FROM alpine:latest

# Install common tools and dependencies
RUN apk update && apk add --no-cache \
    bash \
    postgresql-client \
    curl \
    wget \
    jq \
    git \
    # Add any other tools you frequently need, e.g., AWS CLI, Python, Node.js, etc.
    python3 py3-pip \
    && pip3 install --no-cache-dir some-python-library

# Set a working directory if needed
# WORKDIR /app

# Copy any default scripts or configurations if necessary
# COPY entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh

# Define default command or entrypoint
# ENTRYPOINT ["/entrypoint.sh"]
# CMD ["/bin/bash", "/runner.sh"] # Example if script is mounted
```
Then, build this image: `docker build -t myridia/runner .`

---

### Key Components:

1.  **`docker-compose.yml`:** Defines the services, including your `runner`.
2.  **`runner.sh` (or similar):** The script that the `runner` container will execute.
3.  **Docker Image (`myridia/runner`):** Your pre-built "fatty" runner image.

---

### Example: `docker-compose.yml`

```yaml
# docker-compose.yml

version: '3.8'

services:
  # --- Your Application Services ---
  # Example: Database
  db:
    image: postgres:13
    environment:
      POSTGRES_DB: mydatabase
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword # Use .env for secrets in production!
    ports:
      - "5432:5432"
    networks:
      workgroup:
        ipv4_address: "10.5.0.3" # Example IP

  # Example: Web Application
  web:
    image: nginx:latest # Replace with your actual web app image
    ports:
      - "80:80"
    depends_on:
      - db # Ensures web starts after db
    networks:
      workgroup:
        ipv4_address: "10.5.0.4" # Example IP

  # --- The "Fatty" Runner Service ---
  runner:
    container_name: runner # Useful for quick identification
    image: "myridia/runner" # Your pre-built "fatty" runner image
    volumes:
      # Mount your execution script into the container
      - ./runner.sh:/runner.sh
    depends_on:
      # IMPORTANT: Ensures runner container starts ONLY AFTER db and web are STARTED.
      # Note: This doesn't guarantee they are *ready*. The script handles readiness checks.
      - db
      - web
    networks:
      workgroup:
        ipv4_address: "10.5.0.5" # Assign a specific IP if needed
    # Define the entrypoint: This is what Docker executes when the container starts.
    # It runs your mounted script using bash.
    entrypoint: ["/bin/bash", "/runner.sh"]
    # Pass secrets via environment variables (fetch from .env or CI/CD secrets)
    environment:
      # Example: Pass the database password securely
      POSTGRES_PASSWORD: ${MY_DB_PASSWORD} # Assumes MY_DB_PASSWORD is in your .env file or shell env
      # Add other necessary environment variables
      # OTHER_CONFIG_VAR: ${SOME_OTHER_VALUE}

networks:
  workgroup:
    driver: bridge
    ipam:
      config:
        - subnet: 10.5.0.0/24
```

---

### Example: `runner.sh` (Robust Script with Pre-installed Tools)

This script leverages the tools already present in your "fatty" runner image.

```bash
#!/bin/bash
# runner.sh - Executes post-startup tasks using pre-installed tools.

# --- Configuration ---
# Adjust these to match your specific environment.
# These values can also be passed via environment variables from docker-compose.yml.
DB_HOST="${DB_HOST:-10.5.0.3}" # Default to IP, or use env var DB_HOST
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-odoo}"
DB_NAME="${DB_NAME:-odoo}"
# IMPORTANT: Fetch password from environment variable for security!
DB_PASSWORD="${POSTGRES_PASSWORD:-YOUR_DEFAULT_PASSWORD}" # Fallback to default if not set

# --- Script Execution ---

# Exit immediately if a command exits with a non-zero status.
# This prevents the script from continuing if a critical step fails.
set -e

echo "--- Runner Script Started ---"
echo "Using Image: $(cat /proc/1/cpuset/cpu.effective_cpus || echo 'N/A') - (This is a placeholder, real image info would need inspection or be passed)"
echo "Runner Container ID: $(hostname)" # Often useful for debugging container logs

# 1. Wait for the Database to be Ready
echo "Waiting for PostgreSQL database at ${DB_HOST}:${DB_PORT} to become available..."

MAX_RETRIES=60         # Number of times to check before giving up
RETRY_INTERVAL=2       # Seconds to wait between checks
RETRY_COUNT=0

# Use 'psql' (pre-installed in the fatty runner) to check connectivity.
# '-w' disables password prompts, important for non-interactive scripts.
# Redirecting output to /dev/null as we only care about the exit code (success/failure).
while ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -w -c '\q' > /dev/null 2>&1; do
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Database connection failed after ${MAX_RETRIES} retries. Exiting."
        exit 1
    fi
    echo "Database not ready. Retrying in ${RETRY_INTERVAL}s... (Attempt ${RETRY_COUNT}/${MAX_RETRIES})"
    sleep $RETRY_INTERVAL
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo "Database is ready!"

# 2. Perform Your Specific Tasks (using pre-installed tools)
echo "Executing database cleanup task..."

# Example: Delete Odoo's ir_attachment records for views to force recreation
# Ensure DB_PASSWORD is set. PGPASSWORD env var is the standard for psql.
export PGPASSWORD="$DB_PASSWORD"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "DELETE FROM ir_attachment WHERE res_model='ir.ui.view' AND name LIKE '%assets_%';"

echo "Database cleanup task completed successfully."

# --- Add More Tasks Here ---
# Example: Fetching data from another service using curl (pre-installed)
# echo "Fetching initial configuration from external API..."
# curl --fail -sSf -H "Authorization: Bearer ${API_TOKEN}" https://api.example.com/config > /app/config.json
# echo "Configuration fetched."

# Example: Running a Python script (Python & pip pre-installed)
# echo "Running data seeding script..."
# python3 /app/scripts/seed_data.py
# echo "Data seeding complete."

echo "--- Runner Script Finished Successfully ---"
```

---

### Integration with CI/CD Tools (GitHub Actions, GitLab CI, `act`, etc.)

The "fatty" runner is *ideal* for CI/CD environments. Tools like `act` (to simulate GitHub Actions locally) or actual CI/CD platforms benefit greatly from this pre-built approach.

**The Core Idea:**

Your CI/CD pipeline orchestrates Docker Compose to:
1.  Start your application services (DB, Web, etc.).
2.  Run the `myridia/runner` container *after* the others.
3.  Pass any necessary secrets or configurations securely.

**Example with `act` (for GitHub Actions locally):**

*   **`docker-compose.yml`:** As defined above.
*   **`.github/workflows/deploy.yml`:** (Simplified Example)

    ```yaml
    name: Deploy Workflow

    on:
      push:
        branches: [ main ]

    jobs:
      deploy:
        runs-on: ubuntu-latest
        steps:
          - name: Checkout code
            uses: actions/checkout@v3

          # Step 1: Start necessary services using Docker Compose
          # Use 'up -d' to run them in detached mode in the background.
          - name: Start Application Services
            uses: arrterian/docker-compose-action@v1.2.0
            with:
              command: up -d db web # Only start the services the runner depends on
            env:
              # Pass secrets required by the app services themselves
              MY_DB_PASSWORD: ${{ secrets.DB_PASSWORD }}

          # Step 2: Run the Runner Container
          # 'run --rm' starts the specified service, executes its entrypoint/command,
          # and then removes the container once it exits.
          - name: Execute Post-Startup Tasks
            uses: arrterian/docker-compose-action@v1.2.0
            with:
              compose-file: docker-compose.yml # Your compose file
              command: run --rm runner      # Execute the 'runner' service
            env:
              # Pass secrets required by the runner script
              POSTGRES_PASSWORD: ${{ secrets.DB_PASSWORD }}
              # Add any other env vars the runner script needs
              # API_TOKEN: ${{ secrets.API_TOKEN }}

          # Optional: Add steps to stop services after the job if needed
          # - name: Stop Application Services
          #   uses: arrterian/docker-compose-action@v1.2.0
          #   with:
          #     command: down
    ```

*   **Local `act` command:**
    To run this workflow locally using `act`:

    ```bash
    # --- Command Explanation ---
    # act --workflow-file <path_to_workflow> : Specifies the workflow to run.
    # --secret <NAME>=<VALUE>               : Provides secrets to the workflow run.
    # -P <service_name>=<image_name>        : Maps a service defined in your docker-compose.yml
    #                                         (e.g., 'runner') to a specific Docker image ('myridia/runner').
    #                                         This is crucial if 'act' doesn't automatically pick up your image.
    #                                         For this setup, 'act' will likely use the image defined in the compose file.
    #                                         If your compose file referenced `image: myridia/runner`, act should find it.
    #                                         If you use `build: .`, you'd need to ensure the image is built first.
    # --pull=false                          : Prevents re-downloading images if they exist locally. Speeds up tests.
    # <job_name>                            : The specific job within the workflow to execute (e.g., 'deploy').

    act --workflow-file .github/workflows/deploy.yml \
        --secret DB_PASSWORD=your_local_db_password \
        # If your docker-compose.yml doesn't explicitly define the 'myridia/runner' image
        # or if you want to force a specific image for the runner service:
        # -P runner=myridia/runner \
        --pull=false \
        deploy # Name of the job in your workflow file
    ```

**Benefit of the "Fatty" Runner in this Context:**

When `act` (or GitHub Actions) executes the `arrterian/docker-compose-action` for the runner step, it will pull and start the `myridia/runner` image. Since this image already contains all the necessary tools (`psql`, `curl`, etc.), the `runner.sh` script can immediately begin its work without waiting for any package installations, leading to a much faster and more predictable execution.


### Definition

#### GitHub Actions Runner:
* A server/process that picks up jobs from your workflow and runs them
* It "runs" the steps defined in your .github/workflows/*.yml files
* Can be GitHub-hosted (provided by GitHub) or self-hosted (your own machine)

#### Docker (Docker Runner/Executor):
* Less commonly called "runner" directly, but tools like GitLab CI use "Docker runner" to mean a worker that spins up Docker containers to execute jobs
* It "runs" your build/test/deploy commands inside isolated containers
* The name is straightforward — it's the thing that runs your tasks.
