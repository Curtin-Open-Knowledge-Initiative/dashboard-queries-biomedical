-----------------------------------------------------------------------
-- Montreal Neuro - Trial Data query
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'montreal_neuro_ver1l_2023_09_20b_trialdata';
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
-- 3. From the publication dataset get an exploded list of
--    all pairs of DOI and Trial-ID
-----------------------------------------------------------------------
d_pubsdata_ALL_pairs AS (
  SELECT 
  doi,
  clintrial_CONCAT_ALL_SPLIT_unnested
  FROM `university-of-ottawa.neuro_dashboard_data.dashboard_data`,
  UNNEST (SPLIT(clintrial_CONCAT_ALL, ' ') ) AS clintrial_CONCAT_ALL_SPLIT_unnested
  WHERE clintrial_CONCAT_ALL_SPLIT_unnested != ''
  ), # END OF 3. SELECT d_pubsdata_ALL_pairs

-----------------------------------------------------------------------
-- 4. GET DESIRED FIELDS OF THE PUBLICATION DATA
-- IS THIS REDUNDANT??
-----------------------------------------------------------------------
 # data_pubs AS (
 # SELECT
 #   doi,
 #   published_year,
 #   container_title_concat,
 # REPLACE(TRIM(clintrial_CONCAT_ALL),'  ', ' ') AS clintrial_CONCAT_ALL
 # FROM
 #   `university-of-ottawa.neuro_dashboard_data.dashboard_data`
 #   ), # END OF 4. SELECT data_pubs

-----------------------------------------------------------------------
-- 5. To the Trial Data, join matching dois from the publication set which reference 
--    those Trial-IDs and aggregate up
-----------------------------------------------------------------------
  pubsdata_MATCHED_pairs AS (
   SELECT 
   trials_data.nct_id,
   # need to test with the real data if the following handles multiple dois found
   string_agg(doi, ' ') as doi
  
   FROM trials_data
   LEFT JOIN d_pubsdata_ALL_pairs
   ON LOWER(d_pubsdata_ALL_pairs.clintrial_CONCAT_ALL_SPLIT_unnested) LIKE 
     CONCAT('%', LOWER(TRIM(trials_data.nct_id)), '%' )
   group by trials_data.nct_id
  ), # END OF 5. SELECT pubsdata_MATCHED_pairs

-----------------------------------------------------------------------
-- 6. To the Trial Data, join matching publications which reference those Trial-IDs
-----------------------------------------------------------------------
trial_data_and_pubs AS (
  SELECT
  trials_data.*,
  pubsdata_MATCHED_pairs.* EXCEPT (nct_id),
  CASE
    WHEN doi IS NULL THEN FALSE
    ELSE TRUE
    END as doi_found,
  CASE
    WHEN doi IS NULL THEN "No reference of Trial dataset Trial-IDs in publication"
    ELSE "Trial dataset Trial-IDs referenced in publication"
  END as doi_found_PRETTY,

  ----- UTILITY - add a variable for the script version
  var_SQL_script_name

  FROM trials_data
  LEFT JOIN pubsdata_MATCHED_pairs 
  ON trials_data.nct_id = pubsdata_MATCHED_pairs.nct_id
  ) # END OF 6. SELECT trial_data_and_pubs

-----------------------------------------------------------------------
-- 7. Now do the Some for Crossref/Pubmed
--    From the Crossref/Pubmed dataset get a list of
--    all pairs of DOI and Trial-ID
-----------------------------------------------------------------------
/*table_crossref_pubmed AS (
  ------ 7.1 TABLES.
  SELECT academic_observatory.doi,
  -----------------------------------------------------------------------
  --  Search CROSSREF for Trial-IDs
  -----------------------------------------------------------------------
  ------ 7.2 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
  TRIM((SELECT REPLACE(TRIM(array_agg(clinical_trial_number)[offset(0)]),'  ', ' ')
     FROM UNNEST(academic_observatory.crossref.clinical_trial_number)))
     AS clintrial_crossref_id,

  ------ 7.3 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF Abstract search for trial numbers
  REGEXP_EXTRACT_ALL(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}')
    AS clintrial_crossref_id_fromabstract,

  -----------------------------------------------------------------------
  -- Search Pubmed for Trial-IDs
  -----------------------------------------------------------------------
  ------ 7.4 PUBMED TABLE: CONCATENATED Clinical Trial Registries/Data Banks, and Accession Numbers (optional fields)
  TRIM((SELECT STRING_AGG(id, " ") FROM UNNEST(pubmed.pubmed_DataBankList))) AS clintrial_pubmed_id_CONCAT,

  "" AS clintrial_pubmed_id_fromabstract,
  
  FROM `academic-observatory.observatory.doi20230618` as academic_observatory
  # PubMed is only included here as the required fields are not yet in the Academic Observatory
  LEFT JOIN `university-of-ottawa.neuro_data_processed.pubmed_extract` as pubmed
  ON LOWER(academic_observatory.doi) = LOWER(pubmed_doi)
  
  ), # END OF 7. SELECT table_crossref_pubmed

-----------------------------------------------------------------------
-- 8. Combine Crossref and Pubmed
-----------------------------------------------------------------------
combine_table_crossref_pubmed AS (
  SELECT
  doi,
  #------ combine Trial-IDs from datasets
  REPLACE(
    CONCAT(
      COALESCE(clintrial_crossref_id,""), " ",
      # The following complex statement is to capture missing (?) values that returns "0 rows" isntead of null
      TRIM(COALESCE(
        (SELECT CONCAT(p1)
        FROM UNNEST(clintrial_crossref_id_fromabstract) AS p1)
        ,'')),
      COALESCE(clintrial_pubmed_id_CONCAT,""), " ", 
      COALESCE(clintrial_pubmed_id_fromabstract,""), " "
       ), '  ',' ') AS clintrial_CONCAT_ALL

FROM table_crossref_pubmed

), # END OF 8. SELECT combine_table_crossref_pubmed AS (


-----------------------------------------------------------------------
-- 9. To the Trial Data, join matching publication dois which reference 
--    those Trial-IDs and aggregate up
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- 6. To the Trial Data, join matching publications which reference those Trial-IDs
-----------------------------------------------------------------------
trial_data_and_pubs AS (
  SELECT
  trials_data.*,
  pubsdata_MATCHED_pairs.* EXCEPT (nct_id),
  CASE
    WHEN doi IS NULL THEN FALSE
    ELSE TRUE
    END as doi_found,
  CASE
    WHEN doi IS NULL THEN "No reference of Trial dataset Trial-IDs in publication"
    ELSE "Trial dataset Trial-IDs referenced in publication"
  END as doi_found_PRETTY,

  ----- UTILITY - add a variable for the script version
  var_SQL_script_name

  FROM trials_data
  LEFT JOIN d_pubsdata_MATCHED_pairs 
  ON trials_data.nct_id = d_pubsdata_MATCHED_pairs.nct_id
  ) # END OF 6. SELECT trial_data_and_pubs

*/
SELECT
*
FROM
trial_data_and_pubs

 
