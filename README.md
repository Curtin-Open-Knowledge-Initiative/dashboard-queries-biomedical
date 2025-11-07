# Workflows for Biomedical Open Science Dashboards

*Data Workflows for Open Science Dashboards for Biomedical Research Organizations*

### Contacts
coki@curtin.edu.au

*Rebecca Handcock, Keegan Smith, Kathryn Napier, Cameron Neylon*

### Description
Our objective is to create a digital tool that can automatically curate information, thus providing an audit, about Open Science research practices. Specifically, we have designed and implemented an automated dashboard that reports Open Science metrics. Our tool has been developed for and is specific to the discipline of biomedicine. The dashboard displays metrics and benchmarks to visualize institutional and individual performance regarding Open Science practices.

This repository contains version controlled SQL queries and processing scripts used to create data for these dashboards. The BOS workflow does the following for each project institution that has a configuration file set up within the workflow:
- Checks for the existence of the expected static data files
- Creates the required output datasets if they do not exist
- Generates queries (for both table and view creation) and writes them to file
- Runs the queries
- Checks that the latest views are up to date.

## Overview of  SQL queries that generate data for the BOS dashboard

The dashboards for this project are created in Google LookerStudio, using data stored in BigQuery and processed with SQL scripts. Automation code written in Python is used to create and run customized SQL based on a configuration file. Additional scripts in 'R' are used to create flowcharts documenting project processes.

An overview of the data and processing steps in the automated BOS workflow can be found below:

![Alt text](ASSETS/2025_flowcharts_ver4b_NOLABELS_graph.pngDELETE)

There are 3 SQL scripts that the BOS Workflow needs to run in sequence due to interdependencies between the datasets:

1. **Script #1 - Clinical Trial pre-processing** 
This SQL script takes a data extract from the [Academic Observatory]([https://curtinic.atlassian.net/browse/COK-249](https://github.com/The-Academic-Observatory)) of Crossref and PubMed data and creates a combined list of Clinical Trials from these. The reason for creating this data extract is that the data is reused downstream in multiple parts of the workflow, so it makes sense to create the data extract once.

*Note: See information on the overloaded field containing both Clinical Trial Registries and Databanks [here](https://www.nlm.nih.gov/bsd/medline_databank_source.html)*

2. **Script #2 - Clinical Trial data processing** 
This Trial Data query SQL script and should be run second due to dependencies between the files.

3. **Script #3 - Publication data processing**
This is the main dashboard SQL query for The Neuro's publications and should be run third due to dependencies between the files.

# Before running the BOS workflow

### Step 1 - Backup existing dashboard
If making a new dashboard version, export the dashboard as a PDF and upload to the archive folder.

### Step 2 - Setup your BigQuery project

Throughout this document the BigQuery project for the BOS workflow will be called: `BIOMED_PROJECT` - replace this with the actual project-ID for your BigQuery project. The naming convention for institutions is that they have a prefix, e.g. `P01_NAME` - replace this with the actual institution name prefix.

### Step 3 - Prepare input data in BigQuery

Each partner institution will have the following datasets in the `BIOMED_PROJECT` project with partitioned tables, i.e., .

- `P01_NAME_from_institution` - Date-sharded input data from the institution:
    - `dois_YYYYMMDD` - Institution publication DOIs
    - `oddpub_YYYYMMDD` - Institution publication DOIs output from OddPub processing
    - `trials_aact_YYYYMMDD` - Institution trial data output from AACT processing

- `P01_NAME_data` - Date-sharded output from the BOS workflow:

    - `pubsYYYYMMDD` - Output with institution publication data, by DOI
    - `trialsYYYYMMDD` - Output with institution clinical trial data, by Trial-ID
    - `alltrialsYYYYMMDD` - Output on al clinical trials, by Trial-ID

- `P01_NAME_data_latest` - Most recent output from the BOS workflow. This is the data that the BOS dashboard draws from:
    - `pubs` - most recent of pubsYYYYMMDD
    - `trials` - most recent of trialsYYYYMMDD 
    - `utility_table` - 1x1 table used for community visualizations
    - `utility_years` - table containing year range of the data

### Step 4 – Choose how you will run the workflow

**Option 4.a – From a terminal window**:

The BOS workflow commands can be run from a terminal window.

**Option 4.b – From within an IDE**:

The BOS workflow can also be run from within an integrated development environment (IDE) such as Visual Studio Code (i.e., [vscode](https://code.visualstudio.com/)) or [Pycharm](https://www.jetbrains.com/pycharm/). If you want to run the workflow from within an IDE, then ensure that a suitable IDE is installed.

### Step 5 - Clone the BOS workflow GitHub repository
The BOS workflow GitHub repository (https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical) should then be cloned and opened in your IDE. This only needs to be done once, unless the repository has been updated.

### Step 6 - Setup your computing environment - Option 1 - Docker

The BOS workflow can be run either with Docker or within a virtual environment. The BOS python-based workflow depends on various environment settings, and sometimes there were issues with it running correctly on different machines.

 The BOS workflow therefore includes a [Docker container](https://www.docker.com/) that runs through the installation and runs from start to finish. Running the BOS workflow with [Docker](https://www.docker.com/) is the easiest option as the various dependencies are managed for you.

A Docker container is a "standardized, executable packages that bundle an application's code along with all its necessary dependencies, such as libraries, system tools, and runtime environments, etc."

To run the BOS workflow within a Docker container you need to have Docker installed on your machine, and the Docker container needs to be running while you run the workflow.

**Build the Docker container**

To build the container, make sure Docker is running on your machine. Open a terminal window (or if you are running within an IDE then open the terminal window within the IDE), and make sure that you are in the top-level directory of the repository. Run the following command:

```bash
docker build -t biomed:latest .
```

After this command has run you should now have a `biomed:latest` image within Docker.

### Step 7 - Setup your computing environment - Option 2 - Virtual environment

If you do not wish to use Docker you will need to check the following are installed and set up:

**Python**: The BOS workflow is written in the [Python](https://www.python.org/) programming language, specifically Python 3.11. To check that you have Python 3.11 installed on your machine you can type the following command into a terminal window. The command will return the Python version, assuming it's installed.

`python3 --version`

**pip**: You need to have pip to install the BOS workflow. You can see if you have pip installed using the following command

`python3 -m pip --version`

**Create a virtual environment** It is recommended that you create a new virtual environment for the BOS workflow with the following command that will create a new virtual environment called `venv_biomed` in the current directory. You can choose to place it anywhere else by changing the `venv_biomed` to a different path on your system.

`python3.11 -m venv venv_biomed && source venv_biomed/bin/activate`

**Install the workflow with pip**  You should then install the BOS workflow with `pip` from the repository's root directory (i.e., where `pyproject.toml` is located):

`pip install .`

**Install the BOS workflow**

Now install the biomedical workflow. You need to repeat this step if the repository has changed else you don't need to do it every time you run the workflow.

Make sure that you are in the top-level directory of the repository and run the following command:

```bash
pip install .
```

*Tip*
If you get the error `bash: pip: command not found` but you have the correct version of Python installed, this is likely due to an issue with other installed software. Instead you can be explicit about the version of pip to use by using the following alternative command:

```bash
python3 -m  pip install .
```

# Setting up the Google Cloud Platform (GCP) environment

### Step 8 - Make sure the Google Cloud CLI is installed on your computer

**Google Cloud Command Line Interface**: The BOS workflow requires that the Google Cloud Command Line Interface (i.e., `gcloud cli`) is installed on your computer. The gcloud cli is a set of tools that allows users to interact with and manage Google Cloud resources directly from the command line. You can see instructions for installation [here](https://cloud.google.com/sdk/docs/install).

### Step 9 - GCP setup - User Roles

Running the workflow requires an authenticated Google Cloud Platform service account with the appropriate permissions.

Your user account will require the following roles in the `BIOMED_PROJECT` Project:

- BigQuery Admin
- Create Service Accounts
- Project IAM Admin
- Role Administrator
- Service Account Key Admin

And also the following roles in the `Academic-Observatory` Project:

- Project IAM Admin
- Role Administrator

If it is not desirable to grant this level of access to the user for the Academic-Observatory, a privileged user (i.e. a user with the appropriate permissions) can instead run the following command:

```bash
gcloud projects add-iam-policy-binding academic-observatory \
    --member=serviceAccount:$sa_full_name \
    --role=projects/academic-observatory/roles/BiomedWorkflow \
```

Where `$sa_full_name` is the name of the service account that the user creates in the gcp_setup.sh step.
This grants the service account the necessary access to the `Academic Observatory` Project in order to run the BOS workflow.

### Step 10 - GCP setup - Authenticating the Google Cloud CLI

To have the Google Cloud CLI (i.e. Command line interface) access the BOS resources you need to authorize it with your Google profile that has has the appropriate access. To do so, run the following command rom a terminal window within your IDE to authorize gcloud with your credentials:

```bash
gcloud auth login
```

This command will redirect you to a window in your browser (e.g. Chrome, Safari). After you have authenticated in the browser with the appropriate account you can return to the terminal window where there should be written a messages such as:

`
You are now logged in as [XXXXXXX@ XXXXXXX].
Your current project is [XXXXXXX].  You can change this setting by running:
  $ gcloud config set project PROJECT_ID
`

*Tip*

Make sure that your current project is [BIOMED_PROJECT]. If not then use the following command (replace BIOMED_PROJECT with the actual name of the BOS Project)

`
gcloud config set project BIOMED_PROJECT
`

*Tip*

To see what GCP account you are currently authenticated with use the following Google Cloud SDK command from the terminal window within your IDE :

`
gcloud auth list
`

### Step 11 - Setup your access key

> [!WARNING] 
> This only has to be done once for the project, as every time this command is run it
> makes a new access key and there is a limit as to how many can be created. The access key will be 
> downloaded into a file call .keyfile.json

To setup your access key, there is a setup file `gcp_setup.sh` that will do all of the hard work. Run the following setup command from the terminal window within your IDE and making sure that you are in the top level of the repository, ie: ` ~ dashboard-queries-biomedical`. Provide your working project (AUTH_PROJECT is the project you used to authenticate with) and the project that data will be written to (BIOMED_PROJECT). There is no reason these two projects can't be the same if you wish.

```bash
bash gcp_setup.sh [AUTH_PROJECT] [BIOMED_PROJECT]
```

This command will create an access key with the provided authorizations and save it to a file called `.keyfile.json`. You can use this `.keyfile.json` as is, or for extra security make a symbolic link to the file (see below).

*Tip*

If you do not have the necessary privileges for the Academic Observatory (as described in the previous step), add the `--skip-ao` flag.

The setup script has a few more useful run options. You can view them by running:

```bash
bash gcp_setup.sh --help
```

### Step 12 - Create a symbolic link to your Keyfile (optional)

Once you have downloaded a Keyfile you can use it to access Google Cloud Platform services. A good way to enhance security is that instead of using the actual key file, you instead  create a symbolic **link** to the Keyfile. This way, the Keyfile is protected in case the symbolic link is shared, such as when the repository is backed up to GitHUb.

To do this:

1. Move the `.keyfile.json` file to a different location on your system that is not inside the repository containing the BOS workflow.
2. From the terminal window within your IDE, first check that you are in the top-level directory of the repository where the `.keyfile.json` is located.
3. Now run the following command which will copy the **location** of your keyfile into the `.keyfile.json` file within the repository, but not the **contents* of the keyfile. When using this command, replace `"/path/to/your/keyfile.json"` with the path and filename of where your downloaded keyfile is located.

```bash
ln -s /path/to/your/keyfile.json .keyfile.json
```

# Running the BOS workflow

Running the BOS workflow assumes that the 3 tables of input data have already been uploaded to the `P01_NAME_from_institution` BigQuery dataset, as specified in the BOS data onboarding schema (not detailed here), and with the date incremented so that it is the most recent date in the data stack.

### Step 13 - Setting the configuration file for this run

The workflow requires a config file to be setup for each run. The config file is a plain text file written in the  YAML Markup language. The config file describes all of the workflow run parameters for this particular run, such as the name of the partner and which date-sharded tables to use, etc. See the [example config file](/example_config.yaml) for more information about each field in the config file. Also see an example below:

### Step 14 - Run the workflow!

The BOS workflow does the following for each configured partner institution:

- Checks for the existence of the expected static data files
- Creates the required output datasets if they do not exist
- Generates queries and writes them to file
- Runs the queries
- Overwrites the _latest_ tables with copies of the newly created tables

From a terminal window within your IDE, make sure that you are in the top level of the repository. To run the Docker image, we need to mount the required files (config file and keyfile) to the container and run the `biomed` command that actually runs the BOS workflow. This is an example of how the command should be entered;

```bash
docker run \
    -v ./config.yaml:/app/config.yaml \
    -v ./.keyfile.json:/app/.keyfile.json \
    --entrypoint biomed \
    biomed:latest /app/config.yaml
```

Here is another example of running the workflow with a config file called `config_P01_NAME.yaml`

```bash
docker run \
    -v ./config_P01_NAME.yaml:/app/config_P01_NAME.yaml \
    -v ./.keyfile.json:/app/.keyfile.json \
    --entrypoint biomed \
    biomed:latest /app/config_P01_NAME.yaml
```

*Notes about running the workflow*

- `Dryrun`: Can be run in dryrun mode, which will simply generate the queries without running them. Useful for development/troubleshooting.
- Concurrency: Most of the runtime is waiting for queries to finish, so partner workflows run concurrently. This means performance is not greatly inhibited by scaling.
- Config checking: The config file is read and checked before running the workflow, so obvious errors are picked up and pointed out before doing anything serious.
- Static table checking: Checks for the existence of each partner's static tables. If they don't exist, the queries will not run and waste resources.

# After running the BOS workflow

### Step 15 - Output files
The workflow wil create the following files:

- `P01_NAME_data` - Date-sharded output from the BOS workflow - this will be sharded by the date found in the Config .yaml file in the field "run_version"

    - `pubsYYYYMMDD` - Output with institution publication data, by DOI
    - `trialsYYYYMMDD` - Output with institution clinical trial data, by Trial-ID
    - `alltrialsYYYYMMDD` - Output on al clinical trials, by Trial-ID

- `P01_NAME_data_latest` - Most recent output from the BOS workflow. This is the data that the BOS dashboard draws from:
    - `pubs` - most recent of pubsYYYYMMDD
    - `trials` - most recent of trialsYYYYMMDD 
    - `utility_table` - 1x1 table used for community visualizations
    - `utility_years` - table containing year range of the data

*Note: the Clinical Trial pre-processing extract created by Script 1 is not used in the dashboard

### Step 16 - Update the data connections in Looker Studio
In LookerStudio the dashboard should always point at the most recent data contained within `P01_NAME_data_latest`
refresh the data connections to look at the new files:

- Have the dashboard in edit mode and go to “Resource” > “Manage added data sources”
- For each table, refresh the link by going “Edit” then “Edit Connection”
- Check the correct view is still selected (it should not have changed) and click “Reconnect”
- For “Apply connection changes” click “Yes”, then “Done”

### Step 17 - Refresh the data extract in Google Sheets
Refresh the data extract for the Publications output that is made available the linked Google Sheet:
`- `“Data” > “Data Connectors” > “Refresh Options” > “Refresh All”`

### Step 18 - QC ...
Check all dashboard pages that everything looks OK. 

---
# Funding
The Biomedical institutional open science dashboard program was supported by a Wellcome Trust Open Research Fund (223828/Z/21/Z). The results of the Delphi in step one were [published](https://doi.org/10.1371/journal.pbio.3001949) in PloS Biology. 

Please contact, Dr. Kelly Cobey (kcobey@ottawaheart.ca), the Primary Investigator, with additional questions. 
