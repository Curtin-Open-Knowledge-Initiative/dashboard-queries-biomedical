-------------------------------------------
-- Montreal Neuro - Dashboard query
-------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'montreal_neuro_ver1h_2023_07_04';

-----------------------------------------------------------------------
-- 1. ENRICH ACADEMIC OBSERVATORY WITH UNNPAYWALL AND CONTRIBUTED TABLE
-----------------------------------------------------------------------
WITH
enriched_doi_table AS (
  SELECT
    academic_observatory,
    contributed,
    unpaywall,
    pubmed,
    CASE -- This could be done below but it makes the query below more readable to do it here
      WHEN academic_observatory.crossref.published_month > 12 THEN null
      ELSE DATE(academic_observatory.crossref.published_year, academic_observatory.crossref.published_month, 1)
      END as cr_published_date,
    (
      SELECT g.oa_date -- This needs to be done up here so it is available below but raises general questions about intermediate processing and where it should be done in the query structure
      FROM UNNEST(unpaywall.oa_locations) as g
      WHERE g.host_type="repository"
      ORDER BY g.oa_date ASC LIMIT 1
      ) as first_green_oa_date
  
------ TABLES.
  FROM `academic-observatory.observatory.doi20230618` as academic_observatory
    # Contributed data is any extra data that is not in the Academic Observatory
    LEFT JOIN `university-of-ottawa.montreal_neuro_data_raw.raw20230217_theneuro_oddpub_screening_tidy` as contributed
      ON LOWER(academic_observatory.doi) = LOWER(contributed.doi)
    # Unpaywall is only included here as the required fields are not yet in the Academic Observatory
    LEFT JOIN `academic-observatory.unpaywall.unpaywall` as unpaywall
      ON LOWER(academic_observatory.doi) = LOWER(unpaywall.doi)
    # PubMed is only included here as the required fields are not yet in the Academic Observatory
    LEFT JOIN `university-of-ottawa.montreal_neuro_data_processed.pubmed_extract` as pubmed
      ON LOWER(academic_observatory.doi) = LOWER(pubmed_doi)
),
-------------------------------------------
-- 2. PREPARE DOI SUBSET
-------------------------------------------
# target DOIs is the DOI subset of interest. Used to subset the Academic Observatory
target_dois AS (
  SELECT DISTINCT(doi)
  FROM
    `university-of-ottawa.montreal_neuro_data_raw.raw20230217_theneuro_dois_20102022_tidy_long`
    -- {{doi_table}} WHERE "http://ror.org/XXXXX" in (SELECT identifier FROM UNNEST(affiliations.institutions))
    -- {{doi_table}} WHERE "10.XXXXX" in (SELECT identifier FROM UNNEST(affiliations.funders))
)

-------------------------------------------
-- 3. EXTRACT AND TIDY FIELDS OF INTEREST
-------------------------------------------
SELECT
  ------ DOI TABLE: Misc METADATA
  enriched_doi_table.academic_observatory.doi,
  target_dois.doi as source_doi,
  enriched_doi_table.academic_observatory.crossref.published_year, -- from doi table
  CAST(enriched_doi_table.academic_observatory.crossref.published_year as int) as published_year_PRETTY,
  ARRAY_to_string(enriched_doi_table.academic_observatory.crossref.container_title, " ") as container_title_concat,

  ------ DOI TABLE: CROSSREF TYPE
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

  ------ DOI TABLE: OPEN ACCESS
  enriched_doi_table.academic_observatory.coki.oa_coki,
  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.publisher_only THEN "Publisher Open"
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.both THEN "Both"
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.other_platform_only THEN "Other Platform Open"
    ELSE "Closed"
  END as oa_coki_PRETTY,

  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.publisher_only THEN 0
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.both THEN 1
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.other_platform_only THEN 2
    ELSE 3
  END as oa_coki_GRAPHORDER,

  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.open THEN "Open"
    ELSE "Closed"
  END as oa_coki_open_PRETTY,
  
  ------ DOI TABLE: MADE AVAILABLE DATE / EMBARGO
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

  ------ DOI TABLE: PLAN-S COMPLIANT
  CASE
    WHEN NOT academic_observatory.coki.oa_coki.open THEN FALSE
    WHEN unpaywall.best_oa_location.license != "cc-by" THEN FALSE
    WHEN academic_observatory.coki.oa_coki.publisher THEN TRUE
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 1 then TRUE
    ELSE FALSE
  END as plans_compliant,

  CASE
    WHEN NOT academic_observatory.coki.oa_coki.open THEN "Not PlanS Compliant"
    WHEN unpaywall.best_oa_location.license != "cc-by" THEN "Not PlanS Compliant"
    WHEN academic_observatory.coki.oa_coki.publisher THEN "PlanS Compliant"
    WHEN DATE_DIFF(first_green_oa_date, cr_published_date, MONTH) < 1 then "PlanS Compliant"
    ELSE "Not PlanS Compliant"
  END as plans_compliant_PRETTY,

  ------ DOI TABLE: LICENSE
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

  ------ DOI TABLE: HAS CROSSREF CLINICAL TRIAL NUMBER (TRN)
  (SELECT array_agg(clinical_trial_number)[offset(0)]
     FROM UNNEST(enriched_doi_table.academic_observatory.crossref.clinical_trial_number))
     AS crossref_trn_clinical_trial_number,

  (SELECT array_agg(registry)[offset(0)]
     FROM UNNEST(enriched_doi_table.academic_observatory.crossref.clinical_trial_number))
     AS crossref_trn_registry,

  (SELECT array_agg(type)[offset(0)]
     FROM UNNEST(enriched_doi_table.academic_observatory.crossref.clinical_trial_number))
     AS crossref_trn_type,

  CASE
    WHEN ARRAY_LENGTH(enriched_doi_table.academic_observatory.crossref.clinical_trial_number) > 0 THEN TRUE
    ELSE FALSE
  END as has_crossref_trn,
  CASE
    WHEN ARRAY_LENGTH(enriched_doi_table.academic_observatory.crossref.clinical_trial_number) > 0 THEN "TRN found in Crossref metadata"
    ELSE "No TRN in Crossref metadata"
  END as has_crossref_trn_PRETTY,

  ------ DOI TABLE: ABSTRACT HAS CLINICAL TRIAL NUMBER (TRN)
  REGEXP_CONTAINS(UPPER(enriched_doi_table.academic_observatory.crossref.abstract), r'NCT0\\d{7}') as has_clinical_trial_gov_trn,
  CASE
    WHEN REGEXP_CONTAINS(UPPER(enriched_doi_table.academic_observatory.crossref.abstract), r'NCT0\\d{7}') THEN "Has clinical trial number"
    ELSE "No trial number found"
  END as has_clinical_trial_gov_trn_PRETTY,

  REGEXP_EXTRACT_ALL(UPPER(enriched_doi_table.academic_observatory.crossref.abstract), r'NCT0\\d{7}') as clinical_trial_gov_trns,

  ------ DOI TABLE: PUBLISHER ORCID
  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.crossref.author) as auth WHERE auth.ORCID is not null) > 0 THEN TRUE
    ELSE FALSE
  END AS has_publisher_orcid,

  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.crossref.author) as auth WHERE auth.ORCID is not null) > 0 THEN "Has publisher ORCID"
    ELSE "Does not have publisher ORCID"
  END AS has_publisher_orcid_PRETTY,

  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.authors) as authors where authors.identifier is not null) > 0 THEN TRUE
    ELSE FALSE
  END AS in_orcid_record,

  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.authors) as authors where authors.identifier is not null) > 0 THEN "In an ORCID record"
    ELSE "Not in any ORCID record"
  END AS in_orcid_record_PRETTY,

  ------ DOI TABLE: CROSSREF FUNDER RECORD
  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.funders) as funders where funders.identifier is not null) > 0 THEN TRUE
    ELSE FALSE
  END AS has_cr_funder_record,

  CASE
    WHEN (SELECT COUNT(1) from UNNEST(enriched_doi_table.academic_observatory.affiliations.funders) as funders where funders.identifier is not null) > 0 THEN "Has funder acknowledgement"
    ELSE "No funder acknowledgement"
  END AS has_cr_funder_record_PRETTY,

  ------ CONTRIBUTED TABLE: PREPRINT
  enriched_doi_table.academic_observatory.coki.oa_coki.other_platform_categories.preprint as has_preprint,
  CASE
    WHEN enriched_doi_table.academic_observatory.coki.oa_coki.other_platform_categories.preprint THEN "Has a preprint"
    ELSE "No preprint identified"
  END AS has_preprint_PRETTY,

  ------ CONTRIBUTED TABLE: OPEN DATA
  enriched_doi_table.contributed.is_open_data as has_open_data_oddpub, -- pulled from enriched data BOOL
  CASE
    WHEN enriched_doi_table.contributed.is_open_data THEN "Links to open data (via ODDPUB)"
    ELSE "No links to open data found"
  END AS has_open_data_oddpub_PRETTY,

  ------ CONTRIBUTED TABLE: OPEN CODE
  enriched_doi_table.contributed.is_open_code as has_open_code_oddpub, -- pulled from enriched data BOOL
  CASE
    WHEN enriched_doi_table.contributed.is_open_code THEN "Links to open code (via ODDPUB)"
    ELSE "No links to open code found"
  END AS has_open_code_oddpub_PRETTY,

  ------ ABSTRACTS from any sources
  enriched_doi_table.academic_observatory.crossref.abstract AS abstract_crossref,
  pubmed.pubmed_Abstract AS abstract_pubmed,

  ------ URLs for FULL TEXT
  (SELECT STRING_AGG(URL, " ") FROM UNNEST(enriched_doi_table.academic_observatory.crossref.link)) AS crossref_fulltext_URL_CONCAT,
 
  ------ PUBMED TABLE: Clinical Trial Registry, Data Banks, and Accession Numbers
  (SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) AS pubmed_DataBankNames_concat,
 # (SELECT STRING_AGG(id, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) AS pubmed_AccessionNumbers_concat,
  #pubmed.pubmed_DataBankNames_concat,
 # pubmed.pubmed_DataBankList,
  #pubmed.pubmed_DataBankList.name,
  #pubmed.pubmed_DataBankList.id,

  ------ PUBMED TABLE: Clinical Trial Registry - details
  IF(REGEXP_CONTAINS((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)), 
  'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR'),
  TRUE, FALSE) AS has_pubmed_ClinTrialReg,

  IF(REGEXP_CONTAINS((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)), 
  'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR'),
  "Found in a PubMed Clinical Trial Registry", "Not found in a PubMed Clinical Trial Registry") 
  AS has_pubmed_ClinTrialReg_PRETTY,

  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%ANZCTR%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_ANZCTR,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%ChiCTR%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_ChiCTR,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%CRiS%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_CRiS,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%ClinicalTrials.gov%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_ClinicalTrialsGov,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%CTRI%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_CTRI,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%DRKS%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_DRKS,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%EudraCT%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_EudraCT,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%IRCT%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_IRCT,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%ISRCTN%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_ISRCTN,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%JapicCTI%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_JapicCTI,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%JMACCT%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_JMACCT,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%JPRN%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_JPRN,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%NTR%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_NTR,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%PACTR%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_PACTR,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%ReBec%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_ReBec,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%REPEC%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_REPEC,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%RPCEC%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_RPCEC,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%SLCTR%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_SLCTR,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%TCTR%', TRUE, FALSE) AS has_pubmed_ClinTrialReg_TCTR,
  IF((
    (SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) 
    LIKE '%UMIN-CTR%') OR (
      (SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) 
      LIKE '%UMIN CTR%'), TRUE, FALSE) AS has_pubmed_ClinTrialReg_UMINCTR,

  ------ PUBMED TABLE: ABSTRACT HAS ID from a Clinical Trial Registry
  # NOTE, THERE ARE OTHER IDS TO SEARCH ON
 # REGEXP_CONTAINS(UPPER(pubmed.pubmed_Abstract), r'NCT0\\d{7}') as has_pubmed_ClinTrialReg_ID,
 # CASE
 #   WHEN REGEXP_CONTAINS(UPPER(pubmed.pubmed_Abstract), r'NCT0\\d{7}') THEN "Has PubMed Clinical Trial Registry ID"
 #   ELSE "No PubMed Clinical Trial Registry ID found"
 # END as has_pubmed_ClinTrialReg_ID_PRETTY,
 # REGEXP_EXTRACT_ALL(UPPER(pubmed.pubmed_Abstract), r'NCT0\\d{7}') as clinical_trial_gov_trns2,

  ------ PUBMED TABLE: Databank names - details

  IF(REGEXP_CONTAINS((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)), 
  'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein'),
  TRUE, FALSE) AS has_open_data_pubmed,

  IF(REGEXP_CONTAINS((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)), 
  'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein'),
  "Found in a PubMed Databank", "Not found in a PubMed Databank") 
  AS has_open_data_pubmed_PRETTY,

  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%BioProject%', TRUE, FALSE) AS has_open_data_pubmed_BioProject,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%dbGaP%', TRUE, FALSE) AS has_open_data_pubmed_dbGaP,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%dbSNP%', TRUE, FALSE) AS has_open_data_pubmed_dbSNP,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%dbVar%', TRUE, FALSE) AS has_open_data_pubmed_dbVar,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%Dryad%', TRUE, FALSE) AS has_open_data_pubmed_Dryad,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%figshare%', TRUE, FALSE) AS has_open_data_pubmed_figshare,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%GDB%', TRUE, FALSE) AS has_open_data_pubmed_GDB,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%GENBANK%', TRUE, FALSE) AS has_open_data_pubmed_GENBANK,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%GEO%',TRUE, FALSE) AS has_open_data_pubmed_GEO,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%OMIM%', TRUE, FALSE) AS has_open_data_pubmed_OMIM,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%PIR%', TRUE, FALSE) AS has_open_data_pubmed_PIR,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%PubChem-BioAssay%', TRUE, FALSE) AS has_open_data_pubmed_PubChem_BioAssay,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%PubChem-Compound%', TRUE, FALSE) AS has_open_data_pubmed_PubChem_Compound,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%PubChem-Substance%', TRUE, FALSE) AS has_open_data_pubmed_PubChem_Substance,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%RefSeq%', TRUE, FALSE) AS has_open_data_pubmed_RefSeq,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%SRA%', TRUE, FALSE) AS has_open_data_pubmed_SRA,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%SWISSPROT%', TRUE, FALSE) AS has_open_data_pubmed_SWISSPROT,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%UniMES%', TRUE, FALSE) AS has_open_data_pubmed_UniMES,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%UniParc%', TRUE, FALSE) AS has_open_data_pubmed_UniParc,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%UniProtKB%', TRUE, FALSE) AS has_open_data_pubmed_UniProtKB,
  IF((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%UniRef%', TRUE, FALSE) AS has_open_data_pubmed_UniRef,
  IF(((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%Protein%') OR ((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)) LIKE '%PDB%'), TRUE, FALSE) AS has_open_data_pubmed_Protein_PDB,

------ UTILITY - add a variable for the script version
  var_SQL_script_name,
-------------------------------------------
-- 4. JOIN ENRICHED AND TIDIED DOI TABLE TO THE TARGET DOIS
------------------------------------------
 FROM
   target_dois
   LEFT JOIN enriched_doi_table
   on LOWER(target_dois.doi) = LOWER(enriched_doi_table.academic_observatory.doi)

 ORDER BY published_year DESC, enriched_doi_table.academic_observatory.doi ASC
