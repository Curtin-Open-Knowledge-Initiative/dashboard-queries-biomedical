# == FUNCTION ====================================
CREATE TEMP FUNCTION custom_cast_date(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS DATE));

# == FUNCTION ====================================
CREATE TEMP FUNCTION custom_cast_string(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS STRING));

# == FUNCTION ====================================
CREATE TEMP FUNCTION custom_cast_int(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS INT));

# == FUNCTION ====================================
CREATE TEMP FUNCTION custom_cast_boolean(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS BOOLEAN));

# == FUNCTION ====================================
CREATE TEMP FUNCTION custom_cast_datetime(x ANY TYPE)
AS (
   EXTRACT(DATE FROM (CAST(NULLIF(CAST(x AS STRING), "NA") AS TIMESTAMP)))
   );

# == SELECT ======================================
SELECT

# ==== Metric name on dashboard: # Trials
custom_cast_string(nct_id) as nct_id,
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
custom_cast_boolean(has_summary_results) as is_prospective,
CASE
  WHEN custom_cast_boolean(has_summary_results) IS TRUE THEN "Registered before enrollment started"
  ELSE "Registered after enrollment started"
  END as is_prospective_PRETTY,
  
# ==== Metric name on dashboard: # Trial results in a registry < 1 year post completion 
# is_multicentric IS A TEMPORARY CALC UNTIL THE VARIABLE is_summary_results_1y IS ADDED
custom_cast_boolean(is_multicentric) as is_summary_results_1y,
CASE
  WHEN custom_cast_boolean(is_multicentric) IS TRUE THEN "Summary results reported within 1 year of trial completion"
  ELSE "Summary results not reported within 1 year of trial completion"
  END as is_summary_results_1y_PRETTY,

custom_cast_date(last_update_submitted_date) as last_update_submitted_date,
custom_cast_date(registration_date) as registration_date,
custom_cast_date(summary_results_date) as summary_results_date,
custom_cast_string(study_type) as study_type,
custom_cast_string(phase) as phase,
custom_cast_int(enrollment) as enrollment,
custom_cast_string(recruitment_status) as recruitment_status,
custom_cast_string(title) as title,
custom_cast_datetime(start_date) as start_date,
custom_cast_datetime(completion_date) as completion_date,
custom_cast_datetime(primary_completion_date) as primary_completion_date,
custom_cast_boolean(has_summary_results) as has_summary_results,
custom_cast_string(allocation) as allocation,
custom_cast_string(masking) as masking,
custom_cast_string(main_sponsor) as main_sponsor,
custom_cast_boolean(is_multicentric) as is_multicentric,
custom_cast_string(montreal_neuro_lead_sponsor) as montreal_neuro_lead_sponsor,
custom_cast_string(montreal_neuro_principal_investigator) as montreal_neuro_principal_investigator,
custom_cast_string(montreal_neuro_study_director) as montreal_neuro_study_director,
custom_cast_string(montreal_neuro_study_chair) as montreal_neuro_study_chair,
custom_cast_string(montreal_neuro_unspecified_official) as montreal_neuro_unspecified_official,
custom_cast_string(montreal_neuro_responsible_party) as montreal_neuro_responsible_party,
custom_cast_int(registration_year) as registration_year,
custom_cast_int(start_year) as start_year,
custom_cast_int(completion_year) as completion_year

FROM `university-of-ottawa.neuro_data_raw.montreal_neuro-studies_ver1_raw` 
