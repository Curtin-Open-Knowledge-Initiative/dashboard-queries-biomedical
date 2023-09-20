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

# ========================================================
# == From the publication dataset get an exploded list of
# == all pairs of DOI and Trial-ID
# ========================================================
WITH data_pubs_pairs AS (
  SELECT 
  doi,
  clintrial_CONCAT_ALL_SPLIT_unnested
  FROM `university-of-ottawa.neuro_dashboard_data.dashboard_data`,
  UNNEST (SPLIT(clintrial_CONCAT_ALL, ' ') ) AS clintrial_CONCAT_ALL_SPLIT_unnested
  WHERE clintrial_CONCAT_ALL_SPLIT_unnested != ''
  ),

# ========================================================
# == GET DESIRED FIELDS OF THE PUBLICATION DATA =========
# ========================================================
  data_pubs AS (
  SELECT
    doi,
    published_year,
    container_title_concat,
  REPLACE(TRIM(clintrial_CONCAT_ALL),'  ', ' ') AS clintrial_CONCAT_ALL
  FROM
    `university-of-ottawa.neuro_dashboard_data.dashboard_data`),

# ========================================================
# == PROCESS TRIAL DATA ==================================
# ========================================================
  data_trials AS (
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

FROM `university-of-ottawa.neuro_data_raw.montreal_neuro-studies_ver1_raw`),

# ========================================================
# To the Trial Data, join matching publication dois which reference 
# those Trial-IDs and aggregate up
# ========================================================
  matched_pairs AS (
   SELECT 
   data_trials.nct_id,
   # need to test with the real data if the following handles multiple dois found
   string_agg(doi, ' ') as doi
   FROM data_trials
   LEFT JOIN data_pubs_pairs
   ON LOWER(data_pubs_pairs.clintrial_CONCAT_ALL_SPLIT_unnested) LIKE 
     CONCAT('%', LOWER(TRIM(data_trials.nct_id)), '%' )
   group by data_trials.nct_id
  )

# ========================================================
# To the Trial Data, join matching publications which reference those Trial-IDs
# ========================================================
SELECT
data_trials.*,
matched_pairs.* EXCEPT (nct_id),
CASE
    WHEN doi IS NULL THEN FALSE
    ELSE TRUE
  END as doi_found,
  CASE
    WHEN doi IS NULL THEN "No reference of Trial dataset Trial-IDs in publication"
    ELSE "Trial dataset Trial-IDs referenced in publication"
  END as doi_found_PRETTY
FROM
data_trials
LEFT JOIN matched_pairs 
ON data_trials.nct_id = matched_pairs.nct_id

