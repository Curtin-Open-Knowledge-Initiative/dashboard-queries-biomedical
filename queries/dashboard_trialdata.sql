-----------------------------------------------------------------------
-- Montreal Neuro - Trial Data query 
-- Run this 2nd and cascade to "dashboard_data_trials"
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'montreal_neuro_ver1l_2023_10_02d_trialdata';
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
-- associated with ANY SOURCE (ie Crossref or Pubmed)
-----------------------------------------------------------------------
d_anysource_extract_flat AS (
SELECT 
  LOWER(doi) as ANYSOURCE_doi,
  ANYSOURCE_clintrial_ids_flat
FROM
  `university-of-ottawa.neuro_dashboard_data_archive.clintrial_extract_ver1l_2023_10_02`,
  UNNEST(SPLIT(ANYSOURCE_clintrial_ids," ")) as ANYSOURCE_clintrial_ids_flat
  WHERE ANYSOURCE_clintrial_found
), # END SELECT 3. d_anysource_extract_flat

-----------------------------------------------------------------------
-- 4. To the Trial Data, join matching DOIs
-- associated with ANY SOURCE (ie Crossref and Pubmed)
-----------------------------------------------------------------------
d_trials_data_joined_2_anysource AS (
  SELECT
  trials_data.*,
  TRIM(CONCAT(d_anysource_extract_flat.ANYSOURCE_doi, ' ')) AS ANYSOURCE_ALL_dois_matching_trialid,

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
  ON lower(trials_data.nct_id) = lower(d_anysource_extract_flat.ANYSOURCE_clintrial_ids_flat)
  
  # END OF 4. SELECT d_trials_data_joined_2_anysource
),

-----------------------------------------------------------------------
-- 5.From the flatted list of DOIs and Trial-IDs associated with ANY SOURCE 
-- (ie Crossref or Pubmed) select JUST the rows with DOIs in the publication set
-----------------------------------------------------------------------
d_pubs_data_intersect_anysource AS (
  SELECT
  DISTINCT(LOWER(contributed_pubs.doi)) AS PUBSDATA_doi, 
  d_anysource_extract_flat.ANYSOURCE_clintrial_ids_flat
  FROM
    `university-of-ottawa.neuro_data_raw.raw20230217_theneuro_dois_20102022_tidy_long` as contributed_pubs
  INNER JOIN d_anysource_extract_flat 
  ON LOWER(contributed_pubs.doi) = LOWER(d_anysource_extract_flat.ANYSOURCE_doi)
) # END OF 5. SELECT d_pubs_data_intersect_anysource

-----------------------------------------------------------------------
-- 6. To the Trial Data, join matching DOIs and Trial-IDs
-- associated with just the DOIs in the publication set
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

  FROM d_trials_data_joined_2_anysource
  LEFT JOIN d_pubs_data_intersect_anysource 
  ON lower(d_trials_data_joined_2_anysource.nct_id) = lower(d_pubs_data_intersect_anysource.ANYSOURCE_clintrial_ids_flat)
  
  # END OF 6. SELECT d_trials_data_joined_2_pubs

 
