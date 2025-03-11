from importlib import resources

from jinja2 import Environment, BaseLoader, StrictUndefined


def query_alltrials(**kwargs) -> str:
    """Creates the all_trials query from its template

    The template expects the following as kwargs:
    :param run_version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :param workflow_hash: A string identifier for the version of the script used to make the query
    :param cutoff_year: An optional int/str that works as a cutoff for publication year
    """

    with resources.open_text("queries", "dashboard_query1_alltrials.sql.jinja2") as f:
        query_template = f.read()

    query = Environment(loader=BaseLoader(), undefined=StrictUndefined).from_string(query_template).render(**kwargs)
    return query


def query_trials(**kwargs) -> str:
    """Creates the trials query from its template

    The template expects the following as kwargs:
    :param run_version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :workflow_hash: A string identifier for the version of the script used to make the query
    :param trials_aact_table_name: The name of the static partner trials_aact table
    :param dois_table_name: The name of the static partner dois table
    """
    with resources.open_text("queries", "dashboard_query2_trials.sql.jinja2") as f:
        query_template = f.read()

    query = Environment(loader=BaseLoader(), undefined=StrictUndefined).from_string(query_template).render(**kwargs)
    return query


def query_pubs(**kwargs) -> str:
    """Creates the pubs query from its template

    The template expects the following as kwargs:
    :param run_version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :param workflow_hash: A string identifier for the version of the script used to make the query
    :param dois_table_name: The name of the static partner dois table
    :param oddpub_table_name: The name of the static partner oddpub table
    """
    with resources.open_text("queries", "dashboard_query3_pubs.sql.jinja2") as f:
        query_template = f.read()

    query = Environment(loader=BaseLoader(), undefined=StrictUndefined).from_string(query_template).render(**kwargs)
    return query


def query_orcid(**kwargs) -> str:
    """Creates the orcid query from its template

    The template expects the following as kwargs:
    :param run_version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :workflow_hash: A string identifier for the version of the script used to make the query
    :param orcid_table_name: The name of the static partner orcid table
    """
    with resources.open_text("queries", "dashboard_query4_orcid.sql.jinja2") as f:
        query_template = f.read()

    query = Environment(loader=BaseLoader(), undefined=StrictUndefined).from_string(query_template).render(**kwargs)
    return query
