# Biomed Workflow

An automated workflow that does the following for each configured partner:
- Checks for the existence of the expected static data files
- Creates the required output datasets if they do not exist
- Generates queries (for both table and view creation) and writes them to file
- Runs the queries
- Checks that the latest views are up to date.

## Quickstart Setup
### GCP Setup
Running the workflow requires an authenticated Google Cloud service account with the appropriate permissions.

For ease of setup, there is a setup file `gcp_setup.sh` that will do all of the hard work.

The setup file requires that the gcloud cli is installed. You can see instructions for installation [here](https://cloud.google.com/sdk/docs/install).

Once gcloud is installed, authenticate with 

```bash
gcloud auth login
```

Then run the setup command, providing your working project and the project that will be written to.

```bash
bash gcp_setup.sh [MY_PROJECT] [BIOMED_PROJECT]
```
There is no reason these two projects can't be the same if you wish.


### Config
The workflow requires a config file to be setup. The config file describes all of the workflow run parameters. See the [example config file](/example_config.yaml) for more infromation.

Create your own config file with your required configuration.

### Installation
The workflow is written in Python3, so it needs to be installed to run.

It is recommended to create a new virtual environment for the biomed workflow with the following command:
```bash
python3 -m venv venv_biomed && source venv_biomed/bin/activate
```
This will create a new virtual environment called `venv_biomed` in the current directory. You can choose to place it anywhere else by changing the `venv_biomed` to a different path on your system.

Install with pip
```bash
pip install .
````

## Running 
Once the wokflow has been installed, you can run it from the repository root with
```bash
biomed MY_CONFIG
```
Where MY_CONFIG is your config file.

## Features
- Dryrun: Can be run in dryrun mode, which will simply generate the queries without running them. Useful for development/troubleshooting.
- Concurrency: Most of the runtime is waiting for queries to finish, so partner workflows run concurrently. This means performance is not greatly inhibited by scaling.
- Config checking: The config file is read and checked before running the workflow, so obvious errors are picked up and pointed out before doing anything serious.
- Static table checking: Checks for the existence of each partner's static tables. If they don't exist, the queries will not run and waste resources.


