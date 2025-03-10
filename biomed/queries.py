from datetime import date
from importlib import resources
from typing import Optional, Union

from jinja2 import Environment, BaseLoader, StrictUndefined


def alltrials(**kwargs) -> str:
    """Creates the all_trials query from its template

    :param version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :workflow_hash: A string identifier for the version of the script used to make the query
    """

    with resources.open_text("queries", "dashboard_query1_alltrials.sql.jinja2") as f:
        query_template = f.read()
    query = Environment(loader=BaseLoader(), undefined=StrictUndefined).from_string(query_template).render(**kwargs)

    return query


def trials(**kwargs) -> str:
    """Creates the all_trials query from its template

    :param version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :workflow_hash: A string identifier for the version of the script used to make the query
    """
    with resources.open_text("queries", "dashboard_query2_trials.sql.jinja2") as f:
        query_template = f.read()

    query = Template(query_template).render(**kwargs)

    return query


def pubs(
    *,
    run_version: date,
    doi_version: date,
    institution_id: str,
    workflow_hash: str,
    year_cutoff: Optional[Union[int, str]] = None,
) -> str:
    """Creates the all_trials query from its template

    :param version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :workflow_hash: A string identifier for the version of the script used to make the query
    """
    with resources.open_text("queries", "dashboard_query3_pubs.sql.jinja2") as f:
        query_template = f.read()

    query = Template(query_template).render(
        run_version=run_version,
        doi_version=doi_version,
        institution_id=institution_id,
        workflow_hash=workflow_hash,
        year_cutoff=year_cutoff,
    )

    return query


def orcid(
    *,
    run_version: date,
    doi_version: date,
    institution_id: str,
    workflow_hash: str,
    year_cutoff: Optional[Union[int, str]] = None,
) -> str:
    """Creates the all_trials query from its template

    :param version: The version as a date. Will be converted to a string YYYYMM for sharding
    :param doi_version: The doi table version as a date. Will be converted to a string YYYYMM for sharding
    :param institution_id: The internal identifier of the institution
    :workflow_hash: A string identifier for the version of the script used to make the query
    """
    with resources.open_text("queries", "dashboard_query4_orcid.sql.jinja2") as f:
        query_template = f.read()

    query = Template(query_template).render(
        run_version=run_version,
        doi_version=doi_version,
        institution_id=institution_id,
        workflow_hash=workflow_hash,
        year_cutoff=year_cutoff,
    )

    return query
