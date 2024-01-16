-----------------------------------------------------------------------
-- Montreal Neuro - Trial Data query 
-- Run this 2nd and cascade to "dashboard_data_trials"
-- See instructions at https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-----------------------------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
DECLARE var_SQL_script_name STRING DEFAULT 'neuro_ver1o_query2_trials_2024_01_15a';
DECLARE var_TrialDataset_name STRING DEFAULT 'combined-ctgov-studies.csv';
DECLARE var_output_table STRING DEFAULT 'dashboard_data_ver1o_2024_01_15_trialdata';
  
-----------------------------------------------------------------------
-- 0. FUNCTIONS
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
# 0. Setup table 
# --------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
CREATE TABLE `university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_2024_01_15_trialdata`
 AS (

-----------------------------------------------------------------------
-- 2. PROCESS TRIAL DATA
-----------------------------------------------------------------------
with trials_data AS (
  SELECT
  # desscriptions of fields are here: https://github.com/maia-sh/the-neuro-trials/blob/main/R/03_combine-trials.R
  
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
), # End of 2. SELECT trials_data


-----------------------------------------------------------------------
# The next step is to get a list of DOIs that mention the imported Trials
# This uses the file of PubMeD and Crossref TrialIDs/DOIs ceated in Step 1
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- 3 Extract and flatten (by DOI) the list of DOIs and Trial-IDs
-- associated with ANY SOURCE (ie Crossref or Pubmed)
-- This needs to be done as the data in Step 1 by DOIs not TrialIDs
-----------------------------------------------------------------------
d_anysource_extract_flat AS (
SELECT 
  LOWER(doi) as ANYSOURCE_doi,
  UPPER(TRIM(ANYSOURCE_clintrial_id_flat)) as ANYSOURCE_clintrial_id_flat
FROM
  ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
  `university-of-ottawa.neuro_dashboard_data_archive.clintrial_extract_ver1o_2024_01_15`,
  UNNEST(SPLIT(ANYSOURCE_clintrial_idlist," ")) as ANYSOURCE_clintrial_id_flat
  WHERE ANYSOURCE_clintrial_found
), # END SELECT 3. d_anysource_extract_flat

-----------------------------------------------------------------------
-- 4. To the Trial Data, join matching DOIs
-- associated with ANY SOURCE (ie Crossref and Pubmed)
-----------------------------------------------------------------------
d_trials_data_joined_2_anysource AS (
  SELECT DISTINCT
  trials_data.*,
  LOWER(TRIM(CONCAT(d_anysource_extract_flat.ANYSOURCE_doi, ' '))) AS ANYSOURCE_ALL_dois_matching_trialid,

  CASE
    WHEN d_anysource_extract_flat.ANYSOURCE_doi IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS ANYSOURCE_doi_found,

  CASE
    WHEN d_anysource_extract_flat.ANYSOURCE_doi IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset found in a Crossref or Pubmed publication"
    ELSE "No Trial-IDs from the Neuro's trial dataset found in a Crossref or Pubmed publication"
    END AS ANYSOURCE_doi_found_PRETTY,

  FROM trials_data
  LEFT JOIN d_anysource_extract_flat 
  ON lower(trials_data.nct_id) = lower(d_anysource_extract_flat.ANYSOURCE_clintrial_id_flat)  
  # END OF 4. SELECT d_trials_data_joined_2_anysource
),

-----------------------------------------------------------------------
-- 5.From the flatted list of DOIs and Trial-IDs associated with ANY SOURCE 
-- (ie Crossref or Pubmed) select JUST the rows with DOIs in 
-- the contributed publication set
-----------------------------------------------------------------------
d_pubs_data_intersect_anysource AS (
  SELECT
  DISTINCT(LOWER(contributed_pubs.doi)) AS PUBSDATA_doi, 
  d_anysource_extract_flat.ANYSOURCE_clintrial_id_flat
  FROM
  ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
    `university-of-ottawa.neuro_data_raw.raw20230217_theneuro_dois_20102022_tidy_long` as contributed_pubs
  INNER JOIN d_anysource_extract_flat 
  ON LOWER(contributed_pubs.doi) = LOWER(d_anysource_extract_flat.ANYSOURCE_doi)
) # END OF 5. SELECT d_pubs_data_intersect_anysource

-----------------------------------------------------------------------
-- 6. To the Trial Data, join matching DOIs and Trial-IDs
-- associated with just the DOIs in the contributed publication set
-----------------------------------------------------------------------
 
SELECT
  d_trials_data_joined_2_anysource.*,
  TRIM(CONCAT(d_pubs_data_intersect_anysource.PUBSDATA_doi, ' ')) AS PUBSDATA_ALL_dois_matching_trialid,

  CASE
    WHEN d_pubs_data_intersect_anysource.PUBSDATA_doi IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS PUBSDATA_doi_found,

  CASE
    WHEN d_pubs_data_intersect_anysource.PUBSDATA_doi IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset found in a publication from The Neuro"
    ELSE "No Trial-IDs from the Neuro's trial dataset found in a publication from The Neuro"
    END AS PUBSDATA_doi_found_PRETTY,

  ----- 4.2 UTILITY - add a variable for the script and input data versions
  var_SQL_script_name,
  var_TrialDataset_name,
  var_output_table,

  FROM d_trials_data_joined_2_anysource
  LEFT JOIN d_pubs_data_intersect_anysource 
  ON lower(d_trials_data_joined_2_anysource.nct_id) = lower(d_pubs_data_intersect_anysource.ANYSOURCE_clintrial_id_flat)
  
  # END OF 6. SELECT d_trials_data_joined_2_pubs
  
  ) # End create table
