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

The dashboards for this project are created in Google LookerStudio, using data stored in BigQuery and processed with SQL scripts. Automation code written in Python is used to create and run customised SQL based on a configuration file. Additional scripts in 'R' are used to create flowcharts documenting project processes.

An overview of the data and processing steps in the automated BOS workflow can be found below:

![Alt text](ASSETS/2025_flowcharts_ver4b_NOLABELS_graph.pngDELETE)

There are 3 SQL scripts that the BOS Workflow needs to run in sequence due to interdependencies between the datasets:

1. **Script #1 - Clinical Trial pre-processing** 
This SQL script takes a data extract from the [Academic Observatory]([https://curtinic.atlassian.net/browse/COK-249](https://github.com/The-Academic-Observatory)) of Crossref and PubMed data and creates a combined list of Clinical Trials from these. The reason for creating this data extract is that the data is reused downstream in multiple parts of the workflow, so it makes sense to create the data extract once.

2. **Script #2 - Clinical Trial data processing** 
This Trial Data query SQL script and should be run second due to dependencies between the files.

3. **Script #3 - Publication data processing**
This is the main dashboard SQL query for The Neuro's publications and should be run third due to dependencies between the files.

# Before running the BOS workflow

### Step 1 - Backup existing dashboard
If making a new dashboard version, export the dashboard as a PDF and upload to the archive folder.

### Step 2 - Prepare input data in BigQuery

Throughout this document the BigQuery project for the BOS workflow will be called: `BIOMED_PROJECT` - replace this with the actual project-ID for your BigQuery project. The naming convention for institutions is that they have a prefix, e.g. `P01_NAME` - replace this with the actual institution name prefix.

Each partner institution will have the following datasets in the `BIOMED_PROJECT` project with partitioned tables, i.e., .

- `P01_NAME_from_institution` - Date-sharded input data from the institution:
    - `dois_YYYYMMDD` - Institution publication DOIs
    - `oddpub_YYYYMMDD` - Institution publication DOIs output from OddPub processing
    - `trials_aact_YYYYMMDD` - Institution trial data output from AACT processing

- `P01_NAME_data` - Date-sharded output from the BOS workflow:

    - `pubsYYYYMMDD` - Output with institution publication data, by DOI
    - `trialsYYYYMMDD` - Output with institution clinical trial data, by Trial-ID
    - `alltrialsYYYYMMDD` - Output on al clinical trials, by Trial-ID

- `P01_NAME_data_latest` - Most recent output from the BOS workflow. This is the data that the BOS dashbaord draws from:
    - `pubs` - most recent of pubsYYYYMMDD
    - `trials` - most recent of trialsYYYYMMDD 
    - `utility_table` - 1x1 table used for community visualisations
    - `utility_years` - table containing year range of the data

    utility_pubs_with_years
utility_table
utility_trials_reporting
utility_years

Running the BOX workflow assumes that the 3 tables of input data have already been uploaded to the `P01_NAME_from_institution` BigQuery dataset, as specified in the BOS data onboarding schema (not detailed here), and with the date incrimented so that it is the most recent date in the data stack.

### Step 3 - Setup your computing environment
**Computing**: To run the BOS workflow, a workstation (e.g. laptop computer or virtual machine) is required that either runs [Docker](https://www.docker.com/), or can run a virtual environment. 

**IDE**: The BOS workflow is run from within an integrated development environment (IDE) such as Visual Studio Code (i.e., [vscode](https://code.visualstudio.com/)) or [Pycharm](https://www.jetbrains.com/pycharm/). Ensure that a suitable IDE is installed.

**Python**: The BOS workflow is written in the [Python](https://www.python.org/) programming language. Make sure you have the correct Python version installed on your local machine. The BOS workflow is written in Python3, specifically Python 3.11. So this version of Python needs to be installed to run. If necessary then install the correct Python version. You can check that you have the correct version of python installed by typing the following command into a terminal window:

`which python3.11`


**Google Cloud Command Line Interface** The BOS workflow requires that the Google Cloud Command Line Interface (i.e., `gcloud cli`) is installed. The gcloud cli is a set of tools that allows users to interact with and manage Google Cloud resources directly from the command line. You can see instructions for installation [here](https://cloud.google.com/sdk/docs/install).

**Docker**: If you plan to run the BOS workflow within a [Docker container](https://www.docker.com/) then you need to have Docker installed and running on your machine. A Docker container is a "are standardized, executable packages that bundle an application's code along with all its necessary dependencies, such as libraries, system tools, and runtime environments, etc."

### Step 4 - Clone the BOS workflow GitHub repository
The BOS workflow GitHub repository (https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical) should then be cloned and opened in your IDE. This only needs to be done once.

# Running the BOS workflow

The BOS workflow does the following for each configured partner institution:

- Checks for the existence of the expected static data files
- Creates the required output datasets if they do not exist
- Generates queries and writes them to file
- Runs the queries
- Overwrites the _latest_ tables with copies of the newly created tables

### Step 5 - Open a terminal window within your IDE**

The BOS workflow is run from a terminal window from within your IDE. Open a terminal window, and make sure that you are in the directory where the repo is, ie:
 ` ~ dashboard-queries-biomedical`

### Step 6 - GCP User Setup

Running the workflow requires an authenticated Google Cloud service account with the appropriate permissions.

Your user account will require the following roles in the `BIOMED_PROJECT` Project:

- Bigquery Admin
- Create Service Accounts
- Project IAM Admin
- Role Administrator
- Service Account Key Admin

And also the following roles in the `Academic-Observatory` Project:

- Project IAM Admin
- Role Administrator

If it is not desirable to grant this level of access to the user for the Academic-Observatory, a privileged user can instead run the following:

`bash
gcloud projects add-iam-policy-binding academic-observatory \
    --member=serviceAccount:$sa_full_name \
    --role=projects/academic-observatory/roles/BiomedWorkflow \
`

Where `$sa_full_name` is the name of the service account that the user creates in the gcp_setup.sh step.
This grants the service account the necessary access to the `Academic Observatory` Project in order to run the BOS workflow.

### Step 6 - GCP Service Account Setup - Authentication

The GCP setup requires that the `gcloud cli` is installed (see earlier note). Once gcloud is installed, authenticate by entering the following command at the terminal.

`gcloud auth login`

After you have authenticated in the browser you can return to the terminal window where there should be written some messages such as:

```bash
You are now logged in as [XXXXXXX@ XXXXXXX].
Your current project is [XXXXXXX].  You can change this setting by running:
  $ gcloud config set project PROJECT_ID
```

Make sure that your current project is [BIOMED_PROJECT]. If not then use the command (replace BIOMED_PROJECT with the actual name of the BOS Project)

```bash
gcloud config set project BIOMED_PROJECT
```

### Step 7 - Running the GCP Service Account Setup command

For ease of setup, there is a setup file `gcp_setup.sh` that will do all of the hard work. 

Run the following setup command from your terminal window, providing your working project (AUTH_PROJECT - the project you use to authenticate with) and the project that will be written to (BIOMED_PROJECT).

`bash
bash gcp_setup.sh [AUTH_PROJECT] [BIOMED_PROJECT]
`

There is no reason these two projects can't be the same if you wish.

If you do not have the necessary privileges for the Academic Observatory (as described in the previous step), add the `--skip-ao` flag.

The setup script has a few more useful run options. You can view them by running:

`bash
bash gcp_setup.sh --help
`


GOT TO CONFIG





---
----
----
---
----
-------
----
-------
----
-------
----
-------
----
----
### Step 23 - Run SQL for PubMed data
This SQL script takes a data extract from the [Academic Observatory]([https://curtinic.atlassian.net/browse/COK-249](https://github.com/The-Academic-Observatory)) of Crossref and PubMed data and creates a combined list of Clinical Trials from these. The reason for creating this data extract is that the data is reused downstream in the workflow, so it makes sense to create it once and re-use it. This SQL script is listed as being required to be run first, but if the data already exists on disc then it does not need to be re-run. If the script does need to be run to make changes or for some other reason, then do the following steps:

1. In BigQuery, make a copy of the most recent SQL script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, eg `neuro_ver1p_query1_alltrials_2024_05_17`

2. Set variables at the top of the SQL script. These variables are not used to select data locations, but are 'text tags' that will be added as fields in the output file:
    - **var_SQL_script_name**: name of the SQL script, eg `neuro_ver1p_query1_alltrials_2024_05_17`
    - **var_SQL_year_cutoff**: earliest year that data is extracted from the Academic Observatory, eg 2000, or use 1 for all data
    - **var_AcademicObservatory_doi**: name of the DOI table version used, eg `doi20240512`
      
3. In the script, make sure that you are happy with the version of the BigQuery input dataset, as these may have been updated since the last time that the script was run:
    - **Academic Observatory** - the version of the Academic Observatory DOI table, eg `doi20240512`
   
5. Check that the output table has a similar naming convention to the script name, eg:
    - `neuro_ver1p_query1_alltrials_2024_05_17`
      
5. Make any other changes to the SQL script and save the changes.

6. Run the SQL script.

*Note: See information on the overloaded field containing both Clinical Trial Registries and Databanks [here](https://www.codecademy.com/pages/contribute-docs)*

### Step 2B - Run SQL for Trial data
This Trial Data query SQL script and should be run second due to dependencies between the files.

1. In BigQuery, make a copy of the most recent script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, eg `neuro_ver1p_query2_trials_2024_05_17`
   
2. Set variables at the top of the SQL script. These variables are not used to select data locations, but are 'text tags' that will be added as fields in the output file:
    - **var_SQL_script_name**: name of the SQL script, eg `neuro_ver1p_query2_trials_2024_05_17`
    - **var_data_trials**: `PROJ_trials_YYYYMM` Table name of clinical trials output from the Charite processing, eg `theneuro_trials_20231111`
    - **var_data_dois**: `ORG_dois_YYYYMM` Table name containing DOIs from the institution institution, eg `theneuro_dois_20230217`

3. In the script, make sure that you are happy with the versions of the BigQuery input datasets, as these may have been updated since the last time that the script was run:
    - **Charite Processing by the Project** - `PROJ_trials_YYYYMM` Table of output from the Charite processing, eg `theneuro_trials_20231111`
    - **Publication DOIs** - `ORG_dois_YYYYMM` Table containing DOIs from the institution institution, eg `theneuro_dois_20230217`
    - **Clinical Trial data extract** - This table was created in Step 1, eg `neuro_ver1p_query1_alltrials_2024_05_17`

5. Check that the output table has a similar naming convention to the script name, eg:
    - `OUTPUT_ver1p_query2_trials_2024_05_17`

5. Make any other changes you want to make to the script and save the changes.

6. Run the script.


### Step 2C - Run SQL for Publication data
This is the main dashboard SQL query for The Neuro's publications and should be run third due to dependencies between the files.

1. In BigQuery, make a copy of the most recent script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, eg `neuro_ver1p_query3_pubs_2024_05_17`
   
2. Set variables at the top of the SQL script. These variables are not used to select data locations, but are 'text tags' that will be added as fields in the output file:
    - **var_SQL_script_name**: name of the SQL script, eg  `neuro_ver1p_query3_pubs_2024_05_17`
    - **var_data_dois**: `ORG_dois_YYYYMM` Table name containing DOIs from the institution institution, eg `theneuro_dois_20230217`
    - **var_data_trials**: `PROJ_trials_YYYYMM` Table name of clinical trials output from the Charite processing, eg `theneuro_trials_20231111`
    - **var_data_oddpub**: `PROJ_oddpub_YYYYMM` Table name of output from the Oddpub processing, eg `theneuro_oddpub_20231017`

3. In the script, make sure that you are happy with the versions of the BigQuery input datasets, as these may have been updated since the last time that the script was run:
    - **Publication DOIs** - `ORG_dois_YYYYMM` Table containing DOIs from the institution institution, `theneuro_dois_20230217`
    - **Institution Clinical Trials** - `ORG_trials_YYYYMM` Table containing list of clinical trials from the partner institution, eg `theneuro_trials_20231111`
    - **Oddpub Processing by the Project** - `PROJ_oddpub_YYYYMM` Table of output from the Oddpub processing, eg `theneuro_oddpub_20231017`
    - **Clinical Trial data extract** - This table was created in Step 1, eg `neuro_ver1p_query1_alltrials_2024_05_17`
    - **Academic Observatory** - the version of the Academic Observatory DOI table, eg `academic-observatory.observatory.doi20240512`

4. Check that the output table has a similar naming convention to the script name, eg:
    - `university-of-ottawa.neuro_dashboard_data_archive.OUTPUT_ver1p_query3_pubs_2024_05_17`

6. Make any other changes you want to make to the script and save the changes.
   
7. Run the script.


### Step 2D - Run SQL for ORCID data
The Researcher ORCID Data query SQL script and should be run fourth due to dependencies between the files.

1. In BigQuery, make a copy of the most recent script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, eg `neuro_ver1p_query4_orcid_2024_05_17`
   
2. Set variables at the top of the SQL script. These variables are not used to select data locations, but are 'text tags' that will be added as fields in the output file:
    - **var_SQL_script_name**: name of the SQL script, eg `neuro_ver1p_query4_orcid_2024_05_17`
    - **var_ORCID_Dataset_name**: name of the table containing list of researcher ORCIDs from the partner institution, eg `theneuro_orcids_20230906`
    - **var_output_table**: name of the output table, eg `OUTPUT_ver1p_query4_orcid_2024_05_17`

3. In the script, make sure that you are happy with the versions of the BigQuery input datasets, as these may have been updated since the last time that the script was run:
      - The contributed Researcher ORCID data
      - **Researcher ORCIDs** - `ORG_orcid_YYYYMM` Table containing list of researcher ORCIDs from the partner institution, eg `theneuro_orcids_20230906`

4. Check that the output table has a similar naming convention to the script name, eg:
    - `university-of-ottawa.neuro_dashboard_data_archive.OUTPUT_ver1p_query4_orcid_2024_05_17`
      
5. Make any other changes you want to make to the script and save the changes.

6. Run the script.

### Step 3 - Update the BigQuery views with the new data
Edit the following views to point at the tables created in Steps 2-4”. Do this by opening the view, going to the ‘Details’ tab, and clicking ‘Edit Query’. In the tab that opens, edit the query and select ‘Save View’. Back in the view, click ’Refresh’ at the top right:

- `university-of-ottawa.neuro_dashboard_data.dashboard_data_trials`
- `university-of-ottawa.neuro_dashboard_data.dashboard_data_pubs`
- `university-of-ottawa.neuro_dashboard_data.dashboard_data_orcid`

*Note: the *PubMed* data extract from Step 1 is not used in the dashboard

### Step 4 - Update the data connections in Looker Studio
In LookerStudio refresh the data connections to look at the new files:

- Have the dashboard in edit mode and go to “Resource” > “Manage added data sources”
- For each table, refresh the link by going “Edit” then “Edit Connection”
- Check the correct view is still selected (it should not have changed) and click “Reconnect”
- For “Apply connection changes” click “Yes”, then “Done”

### Step 5 - QC ...
Check all dashboard pages that everything looks OK. 

### Step 6 - Refresh the data extract in Google Sheets
Refresh the data extract for the Publications output that is made available the linked Google Sheet, “Data”, “Data Connectors”, “Refresh Options”, “Refresh All”. Copy/paste the main publication SQL into the dashboard page too.

### Step 7 - Back-up
Back-up the scripts to Github

---
### Funding
The Biomedical institutional open science dashboard program was supported by a Wellcome Trust Open Research Fund (223828/Z/21/Z). The results of the Delphi in step one were [published](https://doi.org/10.1371/journal.pbio.3001949) in PloS Biology. 

Please contact, Dr. Kelly Cobey (kcobey@ottawaheart.ca), the Primary Investigator, with additional questions. 

---
### Internal project resources
_The following sites require authentication to access_

[Jira ticket](https://curtinic.atlassian.net/browse/COK-249) and [GoogleDrive folder](https://drive.google.com/drive/folders/1I5uPFBWe0pQQT2myRHaCeAgU_xwAAVpg?usp=sharing)

