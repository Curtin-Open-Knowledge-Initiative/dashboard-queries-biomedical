# Biomed Workflow

An automated workflow that does the following for each configured partner:
- Checks for the existence of the expected static data files
- Creates the required output datasets if they do not exist
- Generates queries (for both table and view creation) and writes them to file
- Runs the queries
- Checks that the latest views are up to date.

## Quickstart Setup
### Installation
The workflow is written in Python3, specifically Python 3.11. So it needs to be installed to run.

It is recommended to create a new virtual environment for the biomed workflow with the following command:
```bash
python3.11 -m venv venv_biomed && source venv_biomed/bin/activate
```
This will create a new virtual environment called `venv_biomed` in the current directory. You can choose to place it anywhere else by changing the `venv_biomed` to a different path on your system.

Install with pip from the repository's root directory (where `pyproject.toml` is located):
```bash
pip install .
````

### GCP User Setup
Running the workflow requires an authenticated Google Cloud service account with the appropriate permissions.

Your user account will require the following roles in the Biomedical Project:
- Bigquery Admin
- Create Service Accounts
- Project IAM Admin
- Role Administrator
- Service Account Key Admin

And also the following roles in the Academic-Observatory Project:
- Project IAM Admin
- Role Administrator

If it is not desirable to grant this level of access to the user for the Academic-Observatory, a privileged user can instead run the following:
```bash
gcloud projects add-iam-policy-binding academic-observatory \
    --member=serviceAccount:$sa_full_name \
    --role=projects/academic-observatory/roles/BiomedWorkflow \
```
Where `$sa_full_name` is the name of the service account that the user creates in the gcp_setup.sh step. 
This grants the service account the necessary access to the Academic Observatory in order to run the Biomedical Workflow.

### GCP Service Account Setup

For ease of setup, there is a setup file `gcp_setup.sh` that will do all of the hard work.

The setup file requires that the gcloud cli is installed. You can see instructions for installation [here](https://cloud.google.com/sdk/docs/install).

Once gcloud is installed, authenticate with 

```bash
gcloud auth login
```

Then run the setup command, providing your working project (AUTH_PROJECT - the project you use to authenticate with) and the project that will be written to (BIOMED_PROJECT).

```bash
bash gcp_setup.sh [AUTH_PROJECT] [BIOMED_PROJECT]
```
There is no reason these two projects can't be the same if you wish.

If you do not have the necessary privileges for the Academic Observatory (as described in the previous step), add the `--skip-ao` flag.

The setup script has a few more useful run options. You can view them by running:
```bash
bash gcp_setup.sh --help
```

### Config
The workflow requires a config file to be setup. The config file describes all of the workflow run parameters. See the [example config file](/example_config.yaml) for more infromation.

Create your own config file with your required configuration.


## Running 
Once the wokflow has been installed, you can run it from the repository root with
```bash
biomed MY_CONFIG
```
Where MY_CONFIG is your config file.

Depending on your operating system, this may produce an import issue with the `main` module. If this happens, the workflow can instead be run with:
```bash
python3 main.py MY_CONFIG
```
Or you can run it via Docker... see below.

## Containerisation
The package can also be built and run as a container using Docker. 

To build the container, run in the root directory:
```bash
docker build -t biomed:latest .
```

You should now have a `biomed:latest` image. To run the image, we need to mount the required files (config file and keyfile) to the container and run the biomed command:

```bash
docker run \
    -v ./config.yaml:/app/config.yaml \
    -v ./.keyfile.json:/app/.keyfile.json \
    --entrypoint biomed \
    biomed:latest /app/config.yaml
```
## Features
- Dryrun: Can be run in dryrun mode, which will simply generate the queries without running them. Useful for development/troubleshooting.
- Concurrency: Most of the runtime is waiting for queries to finish, so partner workflows run concurrently. This means performance is not greatly inhibited by scaling.
- Config checking: The config file is read and checked before running the workflow, so obvious errors are picked up and pointed out before doing anything serious.
- Static table checking: Checks for the existence of each partner's static tables. If they don't exist, the queries will not run and waste resources.


