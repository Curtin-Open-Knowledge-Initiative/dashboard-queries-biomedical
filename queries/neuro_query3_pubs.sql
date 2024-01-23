-----------------------------------------------------------------------
-- Montreal Neuro - Dashboard query for The Neuro's publications
-- Run this 3rd and cascade to "dashboard_data_pubs"
-- See instructions at https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-----------------------------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
DECLARE var_SQL_script_name STRING DEFAULT 'neuro_ver1o_query3_pubs_2024_01_22d';
DECLARE var_data_dois STRING DEFAULT 'theneuro_dois_20230217';
DECLARE var_data_trials STRING DEFAULT 'theneuro_trials_20231003';
DECLARE var_data_oddpub STRING DEFAULT 'theneuro_oddpub_20230217';

-----------------------------------------------------------------------
-- 0. Setup table 
-----------------------------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
CREATE TABLE `university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_2024_01_22d_pubs`
 AS (

-----------------------------------------------------------------------
---  1. ENRICH ACADEMIC OBSERVATORY WITH UNNPAYWALL AND CONTRIBUTED 
---     TABLES OTHER THAN PUBS
-----------------------------------------------------------------------
WITH
enriched_doi_table AS (
  SELECT
    academic_observatory,
    contributed_oddpub,
    unpaywall,
    clintrial_extract,
    CASE -- This could be done below but it makes the query below more readable to do it here
      WHEN academic_observatory.crossref.published_month > 12 THEN null
      ELSE DATE(academic_observatory.crossref.published_year, academic_observatory.crossref.published_month, 1)
      END as cr_published_date,
    
    (SELECT g.oa_date -- This needs to be done up here so it is available below
      FROM UNNEST(unpaywall.oa_locations) as g
      WHERE g.host_type="repository"
      ORDER BY g.oa_date ASC LIMIT 1
      ) as first_green_oa_date # END OF CREATION OF enriched_doi_table
  
  ------ TABLES.
  ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
  FROM `academic-observatory.observatory.doi20231217` as academic_observatory
    # Contributed data is any extra data that is not in the Academic Observatory
    LEFT JOIN `university-of-ottawa.neuro_data_processed.theneuro_oddpub_20230217` as contributed_oddpub
      ON LOWER(academic_observatory.doi) = LOWER(contributed_oddpub.doi)
    # Unpaywall is only included here as the required fields are not yet in the Academic Observatory
    LEFT JOIN `academic-observatory.unpaywall.unpaywall` as unpaywall
      ON LOWER(academic_observatory.doi) = LOWER(unpaywall.doi)
    # Import the PubMed/Crossref extract as the required fields are not yet in the Academic Observatory
    LEFT JOIN `university-of-ottawa.neuro_dashboard_data_archive.clintrial_extract_ver1o_2024_01_19` as clintrial_extract
      ON LOWER(academic_observatory.doi) = LOWER(clintrial_extract.doi)
), # END OF #1 enriched_doi_table

-----------------------------------------------------------------------
-- 2. PREPARE CONTRIBUTED DOI SUBSET
-----------------------------------------------------------------------
# Contributed DOIs is the DOI subset of interest. Used to subset the other data
contributed_dois AS (
  SELECT
  DISTINCT(doi)
  FROM
  ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
    `university-of-ottawa.neuro_data_processed.theneuro_dois_20230217`
), # END OF #2 contributed_dois

-----------------------------------------------------------------------
-- 3. EXTRACT AND TIDY FIELDS OF INTEREST
-----------------------------------------------------------------------
main_select AS (
  SELECT
  ------ 3.1 DOI TABLE: Misc METADATA
  lower(contributed_dois.doi) as doi,
  lower(enriched_doi_table.academic_observatory.doi) as doi_academicobservatory,
  enriched_doi_table.academic_observatory.crossref.published_year, -- from doi table
  CAST(enriched_doi_table.academic_observatory.crossref.published_year as int) as published_year_PRETTY,
  ARRAY_to_string(enriched_doi_table.academic_observatory.crossref.container_title, " ") as container_title_concat,

  ------ 3.2 DOI TABLE: CROSSREF TYPE
  enriched_doi_table.academic_observatory.crossref.type as crossref_type,
  CASE
    WHEN enriched_doi_table.academic_observatory.crossref.type = "journal-article" THEN "Journal articles"
    WHEN enriched_doi_table.academic_observatory.crossref.type = "book-chapter" THEN "Book chapter"
    WHEN enriched_doi_table.academic_observatory.crossref.type = "posted-content" THEN "Preprint"
    WHEN enriched_doi_table.academic_observatory.crossref.type = "book" THEN "Book"
    WHEN enriched_doi_table.academic_observatory.crossref.type = "mongraphs" THEN "Book"
    WHEN enriched_doi_table.academic_observatory.crossref.type = "proceedings-article" THEN "Conference proceedings"
    ELSE null
  END as crossref_type_PRETTY,

  ------ 3.3 DOI TABLE: OPEN ACCESS
  enriched_doi_table.academic_observatory.coki.oa.coki,

  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.publisher_only THEN "Publisher Open"
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.both THEN "Both"
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.other_platform_only THEN "Other Platform Open"
    ELSE "Closed"
  END as oa_coki_PRETTY,

  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.publisher_only THEN 0
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.both THEN 1
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.other_platform_only THEN 2
    ELSE 3
  END as oa_coki_GRAPHORDER,

  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.open THEN "Open"
    ELSE "Closed"
  END as oa_coki_open_PRETTY,
  
  ------ 3.4 DOI TABLE: MADE AVAILABLE DATE / EMBARGO
  first_green_oa_date,
  cr_published_date,
  DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) as embargo,

 CASE
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 0 then "Green OA prior to published date"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 3 then "Immediately available"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 8 then "Open before six months"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 14 then "Open before twelve months"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 26 then "Open before two years"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) >= 26 then "Open after two years"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) is null then "Insufficient Data"
   ELSE "Insufficient Data"
  END as embargo_PRETTY,

  CASE
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 0 then 6
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 3 then 1
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 8 then 2
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 14 then 3
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 26 then 4
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) >= 26 then 5
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) is null then 99
   ELSE 99
  END as embargo_GRAPHORDER,

  ------ 3.5 DOI TABLE: PLAN-S COMPLIANT
  CASE
    WHEN NOT academic_observatory.coki.oa.coki.open THEN FALSE
    WHEN unpaywall.best_oa_location.license != "cc-by" THEN FALSE
    WHEN academic_observatory.coki.oa.coki.publisher THEN TRUE

    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 1 then TRUE
    ELSE FALSE
  END as plans_compliant,

  CASE
    WHEN NOT academic_observatory.coki.oa.coki.open THEN "Not PlanS Compliant"
    WHEN unpaywall.best_oa_location.license != "cc-by" THEN "Not PlanS Compliant"
    WHEN academic_observatory.coki.oa.coki.publisher THEN "PlanS Compliant"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 1 then "PlanS Compliant"
    ELSE "Not PlanS Compliant"
  END as plans_compliant_PRETTY,

  ------ 3.6 DOI TABLE: LICENSE
  unpaywall.best_oa_location.license as license,

  CASE
    WHEN unpaywall.best_oa_location.license = 'pd' THEN "Public Domain"
    WHEN unpaywall.best_oa_location.license = 'cc0' THEN "CC0"
    WHEN unpaywall.best_oa_location.license = 'cc-by' THEN "CC-BY"
    WHEN unpaywall.best_oa_location.license = 'cc-by-sa' THEN "CC-BY-SA"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nd' THEN "CC BY-ND"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc' THEN "CC-BY-NC"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc-sa' THEN "CC-BY-NC-SA"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc-nd' THEN "CC BY-NC-ND"
    WHEN unpaywall.best_oa_location.license = 'acs-specific: authorchoice/editors choice usage agreement' THEN "ACS-specific: Author-choice/Editor's-choice Usage Agreement"
    WHEN unpaywall.best_oa_location.license = 'elsevier-specific: oa user license' THEN "Elsevier-specific: OA User License"
    WHEN unpaywall.best_oa_location.license = 'publisher-specific, author manuscript' THEN "Publisher-specific: Author Manuscript"
    WHEN unpaywall.best_oa_location.license = 'implied-oa' THEN "Free to read (no identified license)"
    WHEN unpaywall.best_oa_location.license is null THEN "No licence info"
    ELSE "No licence info"
  END as license_PRETTY,

  CASE
    WHEN unpaywall.best_oa_location.license = 'pd' THEN 1
    WHEN unpaywall.best_oa_location.license = 'cc0' THEN 2
    WHEN unpaywall.best_oa_location.license = 'cc-by' THEN 3
    WHEN unpaywall.best_oa_location.license = 'cc-by-sa' THEN 4
    WHEN unpaywall.best_oa_location.license = 'cc-by-nd' THEN 5
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc' THEN 6
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc-sa' THEN 7
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc-nd' THEN 8
    WHEN unpaywall.best_oa_location.license = 'acs-specific: authorchoice/editors choice usage agreement' THEN 9
    WHEN unpaywall.best_oa_location.license = 'elsevier-specific: oa user license' THEN 10
    WHEN unpaywall.best_oa_location.license = 'publisher-specific, author manuscript' THEN 11
    WHEN unpaywall.best_oa_location.license = 'implied-oa' THEN 12
    WHEN unpaywall.best_oa_location.license is null THEN 99
   ELSE 99 
  END as license_GRAPHORDER,

  CASE
    WHEN unpaywall.best_oa_location.license = 'pd' THEN "No restrictions"
    WHEN unpaywall.best_oa_location.license = 'cc0' THEN "No restrictions"
    WHEN unpaywall.best_oa_location.license = 'cc-by' THEN "Attribution required"
    WHEN unpaywall.best_oa_location.license = 'cc-by-sa' THEN "Share-alike"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nd' THEN "No derivatives"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc' THEN "No derivatives"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc-sa' THEN "No derivatives"
    WHEN unpaywall.best_oa_location.license = 'cc-by-nc-nd' THEN "No derivatives"
    WHEN unpaywall.best_oa_location.license = 'acs-specific: authorchoice/editors choice usage agreement' THEN "Publisher-specific license"
    WHEN unpaywall.best_oa_location.license = 'elsevier-specific: oa user license' THEN "Publisher-specific license"
    WHEN unpaywall.best_oa_location.license = 'publisher-specific, author manuscript' THEN "Publisher-specific license"
    WHEN unpaywall.best_oa_location.license = 'implied-oa' THEN "Free to read"
    WHEN unpaywall.best_oa_location.license is null THEN "No licence info"
    ELSE "No licence info" 
  END as license_GROUP,

  ------ 3.7 DOI TABLE: PUBLISHER ORCID
  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.crossref.author) as auth WHERE auth.ORCID is not null) > 0 THEN TRUE
    ELSE FALSE
  END AS has_publisher_orcid,
  
  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.crossref.author) as auth WHERE auth.ORCID is not null) > 0 THEN "Has publisher ORCID"
    ELSE "Does not have publisher ORCID"
  END AS has_publisher_orcid_PRETTY,
  
  ------ 3.8 DOI TABLE: AUTHOR ORCID
  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.authors) as authors where authors.identifier is not null) > 0 THEN TRUE
    ELSE FALSE
  END AS in_orcid_record,

  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.authors) as authors where authors.identifier is not null) > 0 THEN "In an ORCID record"
    ELSE "Not in any ORCID record"
  END AS in_orcid_record_PRETTY,

  ------ 3.9 DOI TABLE: CROSSREF FUNDER RECORD
  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.funders) as funders where funders.identifier is not null) > 0 THEN TRUE
    ELSE FALSE
  END AS has_cr_funder_record,

  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.funders) as funders where funders.identifier is not null) > 0 THEN "Has funder acknowledgement"
    ELSE "No funder acknowledgement"
  END AS has_cr_funder_record_PRETTY,

  ------ 3.10 CONTRIBUTED TABLE: PREPRINT
  enriched_doi_table.academic_observatory.coki.oa.coki.other_platform_categories.preprint as has_preprint,
  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa.coki.other_platform_categories.preprint THEN "Has a preprint"
    ELSE "No preprint identified"
  END AS has_preprint_PRETTY,

  ------ 3.11 CONTRIBUTED TABLE: OPEN DATA
  enriched_doi_table.contributed_oddpub.is_open_data as has_open_data_oddpub, -- pulled from enriched data BOOL
  CASE
    WHEN enriched_doi_table.contributed_oddpub.is_open_data THEN "Links to open data (via ODDPUB)"
    ELSE "No links to open data found"
  END AS has_open_data_oddpub_PRETTY,

  ------ 3.12 CONTRIBUTED TABLE: OPEN CODE
  enriched_doi_table.contributed_oddpub.is_open_code as has_open_code_oddpub, -- pulled from enriched data BOOL
  CASE
    WHEN enriched_doi_table.contributed_oddpub.is_open_code THEN "Links to open code (via ODDPUB)"
    ELSE "No links to open code found"
  END AS has_open_code_oddpub_PRETTY,

  ------ 3.13 URLs for FULL TEXT
  (SELECT STRING_AGG(URL, " ") FROM UNNEST(enriched_doi_table.academic_observatory.crossref.link)) AS crossref_fulltext_URL_CONCAT,
  
  ------ 3.14 ABSTRACTS from any sources
  enriched_doi_table.academic_observatory.crossref.abstract AS abstract_crossref,
  clintrial_extract.abstract_pubmed,

   ------ 3.15 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
  clintrial_extract.CROSSREF_clintrial_fromfield_found,
  clintrial_extract.CROSSREF_clintrial_fromfield_idlist,

  ------ 3.16 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF Abstract search for trial numbers
  clintrial_extract.CROSSREF_clintrial_fromabstract_found,
  clintrial_extract.CROSSREF_clintrial_fromabstract_idlist,
  
  ------ 3.17 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - PUBMED - contained in fields		
  clintrial_extract.PUBMED_clintrial_fromfield_found,
  clintrial_extract.PUBMED_clintrial_fromfield_idlist,

  ------ 3.18 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - PUBMED - Abstract search for trial numbers
  clintrial_extract.PUBMED_clintrial_fromabstract_found,
  clintrial_extract.PUBMED_clintrial_fromabstract_idlist,

  ------ 3.19 CLINICAL TRIAL NUMBERS ASSOCIATED WITH ALL/ANY  data sources
  clintrial_extract.ANYSOURCE_clintrial_found,
  clintrial_extract.ANYSOURCE_clintrial_idlist,

  CASE
    WHEN clintrial_extract.ANYSOURCE_clintrial_found
    THEN "Trial-ID found in any publication in Pubmed or Crossref"
    ELSE "No Trial-ID found in any publication in Pubmed or Crossref"
    END as ANYSOURCE_clintrial_found_PRETTY,

  ------ 3.20 PUBMED TABLE: Databank names - details
  clintrial_extract.PUBMED_opendata_fromfield_found,
  clintrial_extract.PUBMED_opendata_fromfield_idlist,
  CASE
    WHEN clintrial_extract.PUBMED_opendata_fromfield_found
    THEN "Databank-ID found in Pubmed"
    ELSE "No Databank-ID number found in Pubmed"
    END as PUBMED_opendata_fromfield_found_PRETTY,

  -----------------------------------------------------------------------
  -- 3.21: Join the enriched and tidied DOI table to the target DOIs 
  -------- from The Neuro's publication dataset
  -----------------------------------------------------------------------
 FROM
   contributed_dois
   LEFT JOIN enriched_doi_table
   on LOWER(contributed_dois.doi) = LOWER(enriched_doi_table.academic_observatory.doi)

 ORDER BY published_year DESC, enriched_doi_table.academic_observatory.doi ASC

 ), # END OF #3 main_select

-----------------------------------------------------------------------
--- 4: Extract the The Neuro's publication DOIs that have Trial-IDs that are 
--- found in the The Neuro's list of trials. This can be re-used from the
--- file 'dashboard_data_trials' Step #2
-----------------------------------------------------------------------
trials_matching_pub_dois_flat AS (
    SELECT 
      PUBSDATA_doi_flat,
      TRIM(STRING_AGG(nct_id, ' ')) AS TRIALSDATA_matching_doi_CONCAT,
      PUBSDATA_doi_found
    FROM
    ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
    `university-of-ottawa.neuro_dashboard_data_archive.dashboard_data_ver1o_2024_01_19_trials`,
    UNNEST(SPLIT(TRIM(PUBSDATA_doi)," ")) as PUBSDATA_doi_flat
    WHERE PUBSDATA_doi_found
    GROUP BY PUBSDATA_doi_flat, PUBSDATA_doi_found
    ) # END #4 trials_matching_pub_dois_flat

-----------------------------------------------------------------------
--- 5: Calc additional variables that require the previous steps
--- This include linking The Neuro's publication DOIs that have Trial-IDs that are 
--- found in the The Neuro's list of trials, which was flatted in Step 4
-----------------------------------------------------------------------
SELECT
  main_select.*,

  --- 5.1 Match ALL DOIs from The Neuro's publications that have Trial-IDs 
  --- (from ANY source Crossref/Pubmed) that are on the list of Trial-IDs provided for The Neuro
  --- Note: This is NOT the list of Trial-IDs from Pubmed/Crossref
  --- Note: Multiple Trial-IDs from the trial list might match each DOI,
  --- Note: This is the reverse of a calculation that we do for in the TrialID script

  TRIALSDATA_matching_doi_CONCAT,
  CASE
    WHEN contributed_trials.PUBSDATA_doi_found = TRUE
    THEN TRUE
    ELSE FALSE
    END as TRIALDATA_trialids_found_in_pubs,

  CASE
    WHEN contributed_trials.PUBSDATA_doi_found = TRUE
    THEN "Trial dataset Trial-IDs found The Neuro's publications"
    ELSE "Trial dataset Trial-IDs not found in The Neuro's publications"
    END as TRIALDATA_trialids_found_in_pubs_PRETTY,
  
  ----- 5.2 UTILITY - add variables for the script version and data files
  var_SQL_script_name,
  var_data_dois,
  var_data_trials,
  var_data_oddpub,

  FROM main_select
  LEFT JOIN `trials_matching_pub_dois_flat` as contributed_trials
  ON lower(main_select.doi_academicobservatory) = lower(contributed_trials.PUBSDATA_doi_flat)

) # End create table

