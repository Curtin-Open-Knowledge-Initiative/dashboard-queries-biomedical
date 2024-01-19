-----------------------------------------------------------------------
-- Montreal Neuro - Trial Data query 
-- Run this 2nd and cascade to "dashboard_data_trials"
-- See instructions at https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-----------------------------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
DECLARE var_SQL_script_name STRING DEFAULT 'neuro_ver1o_query2_trials_2024_01_18b';
DECLARE var_TrialDataset_name STRING DEFAULT 'combined-ctgov-studies.csv';
DECLARE var_PubsDataset_name STRING DEFAULT 'data20230217_theneuro_dois_20102022_distinct';
DECLARE var_output_table STRING DEFAULT 'dashboard_data_ver1o_2024_01_18b_trialdata';
  
-----------------------------------------------------------------------
-- 1. FUNCTIONS
-----------------------------------------------------------------------

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_date(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS DATE));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_string(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS STRING));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_int(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS INT));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_boolean(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS BOOLEAN));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_datetime(x ANY TYPE)
AS (
   EXTRACT(DATE FROM (CAST(NULLIF(CAST(x AS STRING), "NA") AS TIMESTAMP)))
   );

# --------------------------------------------------
# 2. Setup table 
# --------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
CREATE TABLE `university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_2024_01_18b_trialdata`
 AS (

-----------------------------------------------------------------------
-- 3. PROCESS IMPORTED TRIAL DATA
-----------------------------------------------------------------------
with d_3_contributed_trials_data AS (
  SELECT
  # descriptions of fields are here: https://github.com/maia-sh/the-neuro-trials/blob/main/R/03_combine-trials.R
  
  # ==== Metric name on dashboard: # Trials
  UPPER(function_cast_string(nct_id)) as nct_id,
  CASE
    WHEN nct_id IS NULL THEN FALSE
    ELSE TRUE
    END as nct_id_found,
  CASE
    WHEN nct_id IS NULL THEN "No Trial-ID"
    ELSE "Has Trial-ID"
    END as nct_id_found_PRETTY,

  -----------------------------------------------------------------------
  # The following comemnted out variables are extract columns in the input data that are not used upstream

  #function_cast_string(source) as source,
  #function_cast_date(last_update_submitted_date) as last_update_submitted_date,
  function_cast_date(registration_date) as registration_date,
  #function_cast_date(summary_results_date) as summary_results_date,
  #function_cast_string(study_type) as study_type,
  #function_cast_string(phase) as phase,
  #function_cast_int(enrollment) as enrollment,
  #function_cast_string(recruitment_status) as recruitment_status,
  #function_cast_string(title) as title,
  function_cast_datetime(start_date) as start_date,
  function_cast_datetime(completion_date) as completion_date,
  #function_cast_datetime(primary_completion_date) as primary_completion_date,
  #function_cast_boolean(has_summary_results) as has_summary_results,
  #function_cast_string(allocation) as allocation,
  #function_cast_string(masking) as masking,
  #function_cast_string(main_sponsor) as main_sponsor,
  #function_cast_boolean(is_multicentric) as is_multicentric,
  #function_cast_int(registration_year) as registration_year,
  #function_cast_int(start_year) as start_year,
  #function_cast_int(completion_year) as completion_year,

  # ==== Metric name on dashboard: # Prospective registrations 
  function_cast_boolean(is_prospective) as is_prospective,
  CASE
    WHEN function_cast_boolean(is_prospective) IS TRUE THEN "Registered before enrollment started"
    ELSE "Registered after enrollment started"
    END as is_prospective_PRETTY,

  #function_cast_int(days_cd_to_summary) as days_cd_to_summary,
  #function_cast_int(days_pcd_to_summary) as days_pcd_to_summary,

  # ==== Metric name on dashboard: # Trial results in a registry < 1 year post completion 
  function_cast_boolean(is_summary_results_1y_cd) as is_summary_results_1y_cd,
  CASE
    WHEN function_cast_boolean(is_summary_results_1y_cd) IS TRUE THEN "Summary results reported within 1 year of trial completion"
    ELSE "Summary results not reported within 1 year of trial completion"
    END as is_summary_results_1y_cd_PRETTY,

  #function_cast_boolean(is_summary_results_1y_pcd) as is_summary_results_1y_pcd,

###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
FROM `university-of-ottawa.neuro_data_raw.montreal_neuro-studies_ver2_raw`
), # End of SELECT d_3_contributed_trials_data

-----------------------------------------------------------------------
# STEP 4:
# This group of steps are to get a list of ANY publications that mention the imported Trials
# This uses the file of PubMeD and Crossref TrialIDs/DOIs ceated in Step 1
# In the dashboard this will go into the section titled "Trial-IDs from the 
# Neuro's trial dataset referenced in any publications (via Pubmed/Crossref)"
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- 4A Extract and flatten the DOIs (1) and Trial-IDs (MANY)
-- associated with ANY SOURCE (ie from Crossref or Pubmed), reulting in a
-- many-to-many file
-- This step needs to be done as the data in Step 1 is by DOIs not TrialIDs
-----------------------------------------------------------------------
d_4a_anysource_extract_flat AS (
SELECT 
  LOWER(doi) as ANYSOURCE_doi,
  UPPER(TRIM(ANYSOURCE_clintrial_id_flat)) as ANYSOURCE_clintrial_id_flat  
FROM
  ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
  `university-of-ottawa.neuro_dashboard_data_archive.clintrial_extract_ver1o_2024_01_17`,
  UNNEST(SPLIT(TRIM(ANYSOURCE_clintrial_idlist)," ")) as ANYSOURCE_clintrial_id_flat
  WHERE ANYSOURCE_clintrial_found
), # END SELECT d_4a_anysource_extract_flat

-----------------------------------------------------------------------
-- 4B. To the list of Contributed trial IDs (i.e. #3), join to the flattened table of 
-- Trial-ID/DOIs from Crossref/Pubmed (ie #4A), using the trial IDs
-- to match the tables. Need to aggregate the Trial-ID/DOIs as there
-- may be more than one DOI that mentions a Trial-ID
-----------------------------------------------------------------------
d_4b_trials_joined_to_anysource AS (
  SELECT 
  p1.nct_id,
  TRIM(STRING_AGG(LOWER(p2.ANYSOURCE_doi), ' ')) AS ANYSOURCE_dois_matching_trialid

  FROM d_3_contributed_trials_data as p1
  LEFT JOIN d_4a_anysource_extract_flat as p2
  ON lower(p1.nct_id) = lower(p2.ANYSOURCE_clintrial_id_flat)  
  GROUP BY p1.nct_id
  # END OF SELECT d_4b_trials_joined_to_anysource
),

-----------------------------------------------------------------------
-- 4C. Add this list of dois that contain trial IDs 
-- (i.e. ANYSOURCE_dois_matching_trialid from #4B) to the the rest of the 
-- contributed trial data, and add some extra calculated fields
-- They may be multiple DOIs per trial ID
-----------------------------------------------------------------------
d_4c_trials_data_joined_to_anysource AS (
  SELECT 
  p3.*,
  p4.ANYSOURCE_dois_matching_trialid,

  CASE
    WHEN p4.ANYSOURCE_dois_matching_trialid IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS ANYSOURCE_doi_found,

  CASE
    WHEN p4.ANYSOURCE_dois_matching_trialid IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset found in a Crossref or Pubmed publication"
    ELSE "No Trial-IDs from the Neuro's trial dataset found in a Crossref or Pubmed publication"
    END AS ANYSOURCE_doi_found_PRETTY,

  FROM d_3_contributed_trials_data as p3
  LEFT JOIN d_4b_trials_joined_to_anysource as p4
  ON lower(p3.nct_id) = lower(p4.nct_id)  
  # END OF SELECT d_4c_trials_data_joined_to_anysource
),

-----------------------------------------------------------------------
-- STEP 5:
-- These next steps are to get the data that inthe dashboard this will go 
-- into the section titled "Trial-IDs from The Neuro's trial dataset that 
-- are found in The Neuro's manuscript-style publication dataset"
-- Data from Crossref and PubMed is used to link the two datasets
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- 5A.From the many-to-many flatted list of DOIs and Trial-IDs associated with ANY SOURCE 
-- (ie re-used from step 4A from earlier), subset JUST the rows/Trial-IDs with DOIs that 
-- are in the contributed PUBLICATION set. This is done so that we can identify 
-- which of the contributed publications have Trial-ID references, by looking up
-- trialIDs from the Pubmed/Crossref data
-----------------------------------------------------------------------
d_5a_pubs_data_intersect_anysource AS (
  SELECT
  TRIM(LOWER(p5.doi)) AS PUBSDATA_doi,
  p6.ANYSOURCE_clintrial_id_flat
  FROM
    ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
    `university-of-ottawa.neuro_data_processed.data20230217_theneuro_dois_20102022_distinct` as p5
    INNER JOIN d_4a_anysource_extract_flat as p6
    ON LOWER(p5.doi) = LOWER(p6.ANYSOURCE_doi)
), # END OF SELECT d_5a_pubs_data_intersect_anysource

----------------------------------------------------------------------
-- 5B.Further subset the previous subset of DOI-to-TrialIDs by just the TrialIDs 
-- that are found in the contributed Clinical Trial list. This step
-- could be done in combination with the following step, but it is being
-- implemented seperately to improve clarity and allow QC of the data
-----------------------------------------------------------------------
d_5b_pubs_data_intersect_anysource AS (
  SELECT
    p8.nct_id,
    TRIM(STRING_AGG(p7.PUBSDATA_doi, ' ')) AS PUBSDATA_doi #could be more than 1

  FROM
    d_5a_pubs_data_intersect_anysource AS p7
    INNER JOIN d_3_contributed_trials_data AS p8

  ON LOWER(p7.ANYSOURCE_clintrial_id_flat) = LOWER(p8.nct_id)
  GROUP BY p8.nct_id
) # END OF SELECT d_5a_pubs_data_intersect_anysource

-----------------------------------------------------------------------
-- 5C. To the enhanced Trial Data (#4C) join the subset of TrialIDs that 
-- are found in the contributed PUBLICATIONS set, and add some extra fields
-----------------------------------------------------------------------
SELECT
  p9.*,
  p10.PUBSDATA_doi,

  CASE
    WHEN p10.PUBSDATA_doi IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS PUBSDATA_doi_found,

  CASE
    WHEN p10.PUBSDATA_doi IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset found in a publication from The Neuro"
    ELSE "No Trial-IDs from the Neuro's trial dataset found in a publication from The Neuro"
    END AS PUBSDATA_doi_found_PRETTY,

  ----- UTILITY - add a variable for the script and input data versions
  var_SQL_script_name,
  var_TrialDataset_name,
  var_PubsDataset_name

  FROM d_4c_trials_data_joined_to_anysource as p9
  LEFT JOIN d_5b_pubs_data_intersect_anysource as p10 
  ON lower(p9.nct_id) = lower(p10.nct_id)
  
  # END OF d_5c_trialdata_with_dois_from_contribpubs
  
 ) # End create table
