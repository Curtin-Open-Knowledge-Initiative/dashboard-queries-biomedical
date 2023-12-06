# dashboard-queries-biomedical

**Biomedical Open Science project - Dashboard Queries**

*Open Science Dashboards for Biomedical Research Organisations*

### Contacts
coki@curtin.edu.au

*Rebecca Handcock, Kathryn Napier, Cameron Neylon*

### Description
Our objective is to create a digital tool that can automatically curate information, thus providing an audit, about OS research practices. Specifically, we will design and implement an automated dashboard that reports OS metrics. Our tool will be developed for and specific to the discipline of biomedicine. The dashboard will display metrics and benchmarks to visualize institutional and individual performance regarding OS practices.

This repository contains version controlled SQL queries and processing scripts.

### Resources
[Jira ticket](https://curtinic.atlassian.net/browse/COK-249)

[Google drive folder](https://drive.google.com/drive/folders/1I5uPFBWe0pQQT2myRHaCeAgU_xwAAVpg?usp=sharing)

## How to generate data and update these dashboards
The dashboards for this project are created in Google LookerStudio, using data stored in Bigquery.


### Naming conventions for SQL scripts
There are 4 SQL scripts in the “Project Queries” for the Bigquery project that need to be run in sequence due to interdependencies between the datasets
Filenames contain a version number (e.g. 1n) which corresponds to to a “sprint” of work, and a corresponding Jira ticket. Filenames also contain a suffix of “YYYY_MMM_DDabc”, which is incremented whenever a copy of the script is made. At the end of the sprint, all intermediate copies will be deleted, leaving only the final copies of the scripts to represent the sprint.


Steps to run these scripts and update data on the dashboards:

### Step 0 - Backup existing dashboard
If making a new dashboard version, export the dashboard as a PDF and upload to the google drive folder, and incriment the dashboard version on the FAQ page.


### Step 1 - Run SQL for Pubmed data
“neuro_ver1o_query1_pubmed_2023_12_06” is a version of the script to create a data extract of the Academic Observatory to extract Crossref and Pubmed data and make a combined list of Clinical trials from these. This SQL script is listed as being required to be run first, but if the data already exists on disc then it does not need to be re-run. If it does need to be run to make changes or for some other reason, then do the following.

1. In Bigquery, make a copy of the most recent script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, e.g. “neuro_ver1o_query1_pubmed_2023_12_06” 
2. Set variables at the top of the SQL script. These are not actual locations, but just text to be added as a field in the output file:
change the variable var_SQL_script_name to be the new script name
3. In the script, make sure that you are happy with the versions of the input dataset for:
    - Crossref from Academic Observatory
4. Make any other changes you want to make to the script and save the changes.
5. Run the script.
6. Save the output to a table with a similar naming convention to the script name, eg:
```
university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_pubmed_2023_12_06
```

*Note: See the overload field containing both Clinical Trial Registries and Databanks [here](https://www.codecademy.com/pages/contribute-docs)*

### Step 2 - Run SQL for Trial data
“neuro_ver1o_query2_trials_2023_12_06” is a version of the Trial Data query script and should be run second due to dependencies between the files.

1. In Bigquery, make a copy of the most recent script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, e.g. “neuro_ver1o_query2_trials_2023_12_06” 
2. Set variables at the top of the SQL script. These are not actual locations, but just text to be added as a field in the output file:
    - var_SQL_script_name to be the new script name
    - var_TrialDataset_name to be the name of the input datafile
    - var_output_table to be the name of the output table
3. In the script, make sure that you are happy with the versions of the input dataset for:
    - Clinical Trial Extract - this was created in Step 1
    - The Bigquery table name for the input trial data
    - The list of publication DOIs
4. Make any other changes you want to make to the script and save the changes.
5. Run the script.
6. Save the output to a table with a similar naming convention to the script name, eg:
```
university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_trialdata_2023_12_06’
```


### Step 3 - Run SQL for Publication data
“neuro_ver1o_query3_pubs_2023_12_06” is the main dashboard query for The Neuro's publications and should be run third due to dependencies between the files.

1. In Bigquery, make a copy of the most recent script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, e.g. “neuro_ver1o_query3_pubs_2023_12_06” 
2. Set variables at the top of the SQL script. These are not actual locations, but just text to be added as a field in the output file:
    - change the variable var_SQL_script_name to be the new script name
    - change the variable var_PubsDataset_name to be the name of the input datafile
    - change the variable var_output_table to be the name of the output table
3. In the script, make sure that you are happy with the versions of the input dataset for:
    - Crossref from Academic Observatory
    - Contributed data from Oddpub
    - Unpaywall dataset
    - Clinical Trial Extract - this was created in Step 1
    - The list of publication DOIs
4. Make any other changes you want to make to the script and save the changes.
5. Run the script.
6. Save the output to a table with a similar naming convention to the script name, eg:
```
university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_pubs_2023_12_06’
```


### Step 4 - Run SQL for ORCID data
“neuro_ver1o_query4_orcid_2023_12_06” is a version of the Researcher ORCID Data query script and should be run fourth due to dependencies between the files.

1. In Bigquery, make a copy of the most recent script and save it as a ‘Project’ query. Increment the naming to reflect the current sprint and creation date, e.g. “neuro_ver1o_query4_orcid_2023_12_06” 
2. Set variables at the top of the SQL script. These are not actual locations, but just text to be added as a field in the output file:
    - change the variable var_SQL_script_name to be the new script name
    - change the variable var_ORCID_Dataset_name to be the name of the input datafile
    - change the variable var_output_table to be the name of the output table
3. In the script, make sure that you are happy with the versions of the input 
dataset for:
    - The contributed Researcher ORCID data
4. Make any other changes you want to make to the script and save the changes.
5. Run the script.
6. Save the output to a table with a similar naming convention to the script name, e.g.
```
     university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_orcid_2023_12_06
```

### Step 5 - Update the Bigquery views with the new data
Edit the following views to point at the tables created in Steps 2-4”. Do this by opening the view, going to the ‘Details’ tab, and clicking ‘Edit Query’. In the tab that opens, edit the query and select ‘Save View’. Back in the view, click ’Refresh’ at the top right.

    university-of-ottawa.neuro_dashboard_data.dashboard_data_trials
    university-of-ottawa.neuro_dashboard_data.dashboard_data_pubs
    university-of-ottawa.neuro_dashboard_data.dashboard_data_orcid

*Note: the *pubmed* data from Step 1 is not used in the dashboard

### Step 6 - Update the data connections in Looker Studio
In LookerStudio refresh the data connections to look at the new files:

    - Have the dashboard in edit mode and go to “Resource” > “Manage added data sources”
    - For each table, refresh the link by going “Edit” then “Edit Connection”
    - Check the correct view is still selected (it should not have changed) and click “Reconnect”
    - For “Apply connection changes” click “Yes”, then “Done”


### Step 7 - QC ...
Check all dashboard pages that everything looks OK. 

### Step 8 - Refresh the data extract in Google Sheets
Refresh the data extract for the Publications output that is made available the linked Google Sheet, “Data”, “Data Connectors”, “Refresh Options”, “Refresh All”. Copy/paste the main publication SQL into the dashboard page too.

### Step 9 - Back-up
Back-up the scripts to Github
