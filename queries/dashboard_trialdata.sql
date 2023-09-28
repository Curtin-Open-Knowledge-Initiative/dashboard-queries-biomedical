-----------------------------------------------------------------------
-- Montreal Neuro - Trial Data query
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'montreal_neuro_ver1l_2023_09_28_trialdata';
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

-----------------------------------------------------------------------
-- 2. PROCESS TRIAL DATA
-----------------------------------------------------------------------
with trials_data AS (
  SELECT
  # ==== Metric name on dashboard: # Trials
  function_cast_string(nct_id) as nct_id,
  CASE
    WHEN nct_id IS NULL THEN FALSE
    ELSE TRUE
    END as nct_id_found,
  CASE
    WHEN nct_id IS NULL THEN "No Trial-ID"
    ELSE "Has Trial-ID"
    END as nct_id_found_PRETTY,

  # ==== Metric name on dashboard: # Prospective registrations 
  # has_summary_results IS A TEMPORARY CALC UNTIL THE VARIABLE is_prospective IS ADDED
  function_cast_boolean(has_summary_results) as is_prospective,
  CASE
    WHEN function_cast_boolean(has_summary_results) IS TRUE THEN "Registered before enrollment started"
    ELSE "Registered after enrollment started"
    END as is_prospective_PRETTY,
  
  # ==== Metric name on dashboard: # Trial results in a registry < 1 year post completion 
  # is_multicentric IS A TEMPORARY CALC UNTIL THE VARIABLE is_summary_results_1y IS ADDED
  function_cast_boolean(is_multicentric) as is_summary_results_1y,
  CASE
    WHEN function_cast_boolean(is_multicentric) IS TRUE THEN "Summary results reported within 1 year of trial completion"
    ELSE "Summary results not reported within 1 year of trial completion"
    END as is_summary_results_1y_PRETTY,

  function_cast_date(last_update_submitted_date) as last_update_submitted_date,
  function_cast_date(registration_date) as registration_date,
  function_cast_date(summary_results_date) as summary_results_date,
  function_cast_string(study_type) as study_type,
  function_cast_string(phase) as phase,
  function_cast_int(enrollment) as enrollment,
  function_cast_string(recruitment_status) as recruitment_status,
  function_cast_string(title) as title,
  function_cast_datetime(start_date) as start_date,
  function_cast_datetime(completion_date) as completion_date,
  function_cast_datetime(primary_completion_date) as primary_completion_date,
  function_cast_boolean(has_summary_results) as has_summary_results,
  function_cast_string(allocation) as allocation,
  function_cast_string(masking) as masking,
  function_cast_string(main_sponsor) as main_sponsor,
  function_cast_boolean(is_multicentric) as is_multicentric,
  function_cast_string(montreal_neuro_lead_sponsor) as montreal_neuro_lead_sponsor,
  function_cast_string(montreal_neuro_principal_investigator) as montreal_neuro_principal_investigator,
  function_cast_string(montreal_neuro_study_director) as montreal_neuro_study_director,
  function_cast_string(montreal_neuro_study_chair) as montreal_neuro_study_chair,
  function_cast_string(montreal_neuro_unspecified_official) as montreal_neuro_unspecified_official,
  function_cast_string(montreal_neuro_responsible_party) as montreal_neuro_responsible_party,
  function_cast_int(registration_year) as registration_year,
  function_cast_int(start_year) as start_year,
  function_cast_int(completion_year) as completion_year

FROM `university-of-ottawa.neuro_data_raw.montreal_neuro-studies_ver1_raw`
), # End of 2. SELECT trials_data

-----------------------------------------------------------------------
-- 3 Extract and flatten (by DOI) the list of DOIs and Trial-IDs
-- associated with the publication set for The Neuro
-----------------------------------------------------------------------
d_pubs_extract_flat AS (
SELECT 
  doi as PUBS_doi,
  PUBS_clintrials_unnested as PUBS_clintrials_unnested
FROM
  `university-of-ottawa.neuro_dashboard_data.dashboard_data`,
  UNNEST(SPLIT(ANYSOURCE_clintrials," ")) as PUBS_clintrials_unnested
  WHERE ANYSOURCE_clintrial_found
), # END SELECT 5. d_pubs_extract_flat

-----------------------------------------------------------------------
-- 4. To the Trial Data, join matching publications ONLY from The Neuro
-- which reference those Trial-IDs
-----------------------------------------------------------------------
d_clintrial_extract AS (
SELECT 
  trials_data.*,
  #d_pubs_extract_flat.PUBS_doi,
  CONCAT(d_pubs_extract_flat.PUBS_doi, ' ') AS PUBS_doi_CONCAT,

 CASE
    WHEN d_pubs_extract_flat.PUBS_doi IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS PUBS_doi_found,

  CASE
    WHEN d_pubs_extract_flat.PUBS_doi IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset in The Neuro publications"
    ELSE "No Trial-IDs from the Neuro's trial dataset in The Neuro publications"
    END AS PUBS_doi_found_PRETTY,

  FROM trials_data
  LEFT JOIN d_pubs_extract_flat 
  ON trials_data.nct_id = d_pubs_extract_flat.PUBS_clintrials_unnested
), # END SELECT 3. d_clintrial_extract

-----------------------------------------------------------------------
-- 5 Extract and flatten (by DOI) the list of DOIs and Trial-IDs
-- associated with ANY SOURCE (ie Crossref and Pubmed)
-----------------------------------------------------------------------
d_anysource_extract_flat AS (
SELECT 
  doi as ANYSOURCE_doi,
  ANYSOURCE_clintrials AS ANYSOURCE_clintrials_CONCAT,
  ANYSOURCE_clintrials_unnested
FROM
  `university-of-ottawa.neuro_dashboard_data_archive.clintrial_extract_ver1l_2023_09_27`,
  UNNEST(SPLIT(ANYSOURCE_clintrials," ")) as ANYSOURCE_clintrials_unnested
  WHERE ANYSOURCE_clintrial_found
) # END SELECT 5. d_anysource_extract_flat

-----------------------------------------------------------------------
-- 6. To the Trial Data, join matching DOIs and Trial-IDs
-- associated with ANY SOURCE (ie Crossref and Pubmed)
-----------------------------------------------------------------------
SELECT
  d_clintrial_extract.*,
  d_anysource_extract_flat.ANYSOURCE_doi,

  CASE
    WHEN d_anysource_extract_flat.ANYSOURCE_doi IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS ANYSOURCE_doi_found,

  CASE
    WHEN d_anysource_extract_flat.ANYSOURCE_doi IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset in a Crossref or Pubmed publication"
    ELSE "No Trial-IDs from the Neuro's trial dataset found in a Crossref or Pubmed publication"
    END AS ANYSOURCE_doi_found_PRETTY,

  CONCAT(d_anysource_extract_flat.ANYSOURCE_clintrials_CONCAT, ' ') AS ANYSOURCE_clintrials_ALL,

  ----- UTILITY - add a variable for the script version
  var_SQL_script_name

  FROM d_clintrial_extract
  LEFT JOIN d_anysource_extract_flat 
  ON d_clintrial_extract.nct_id = d_anysource_extract_flat.ANYSOURCE_clintrials_unnested
  
  # END OF 6. SELECT d_clintrial_extract_AND_trial_data
