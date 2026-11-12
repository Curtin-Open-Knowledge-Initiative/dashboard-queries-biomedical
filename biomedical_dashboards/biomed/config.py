import os
from datetime import datetime
from typing import List, Union

from git import Repo


class Partner:
    """A single partner's configuration for the workflow

    :param institution_id: The internal ID given to this partner.
    :param partner_trials_aact_table: The name of the partner input trials aact table.
    :param partner_dois_table: The name of the partner input doi table.
    :param partner_oddpub_table: The name of the partner input oddpub table.
    :param year_cutoff_start: Pubs with published_year < this are excluded from output.
    :param year_cutoff_end: Pubs with published_year > this are excluded from output.
    """

    def __init__(
        self,
        *,
        institution_id: str,
        partner_dois_table: str,
        partner_trials_aact_table: str,
        partner_oddpub_table: str,
        year_cutoff_start: Union[int, str],
        year_cutoff_end: Union[int, str],
    ):
        self.institution_id = institution_id
        self.partner_dois_table = partner_dois_table
        self.partner_trials_aact_table = partner_trials_aact_table
        self.partner_oddpub_table = partner_oddpub_table
        self.year_cutoff_start = year_cutoff_start
        self.year_cutoff_end = year_cutoff_end

    @property
    def output_dataset(self):
        """Dataset that we will output the tables to from our queries"""
        return f"{self.institution_id}_data"

    @property
    def latest_dataset(self):
        """Dataset that we will output the latest tables to at the end of the workflow"""
        return f"{self.institution_id}_data_latest"

    @property
    def static_dataset(self):
        """Dataset containing data from partners that we will operate on"""
        return f"{self.institution_id}_from_partners"

    @property
    def alltrials_query_fname(self):
        """File name of the alltrials query file"""
        return f"{self.institution_id}_alltrials.sql"

    @property
    def trials_query_fname(self):
        """File name of the trials query file"""
        return f"{self.institution_id}_trials.sql"

    @property
    def pubs_query_fname(self):
        """File name of the pubs query file"""
        return f"{self.institution_id}_pubs.sql"

    @staticmethod
    def from_dict(partner: dict):
        """Constructs a partner object from a dictionary. Checks that it is valid"""

        errors: List[str] = []

        if not partner.get("institution_id"):
            errors.append("Partner construction missing attribute: institution_id")
        if not partner.get("partner_dois_table"):
            errors.append("Partner construction missing attribute: partner_dois_table")
        if not partner.get("partner_trials_aact_table"):
            errors.append("Partner construction missing attribute: partner_trials_aact_table")
        if not partner.get("partner_oddpub_table"):
            errors.append("Partner construction missing attribute: partner_oddpub_table")

        if errors:
            msg: str = "\n".join(errors) + f"\nSupplied dict: {partner}"
            raise RuntimeError(f"Encountered error(s) in partner construction: {msg}")
        return Partner(
            institution_id=partner["institution_id"],
            partner_dois_table=partner["partner_dois_table"],
            partner_trials_aact_table=partner["partner_trials_aact_table"],
            partner_oddpub_table=partner["partner_oddpub_table"],
            year_cutoff_start=partner.get("year_cutoff_start", 1),  # Default to 1 if not provided (all years),
            year_cutoff_end=partner.get("year_cutoff_end", 3000),  # Default to 3000 if not provided (all years)
        )

    def to_dict(self) -> dict:
        return dict(
            institution_id=self.institution_id,
            partner_dois_table=self.partner_dois_table,
            partner_trials_aact_table=self.partner_trials_aact_table,
            partner_oddpub_table=self.partner_oddpub_table,
            year_cutoff_start=self.year_cutoff_start,
            year_cutoff_end=self.year_cutoff_end,

        )


class Context:
    """Contains the contextual information of the workflow configuration

    :param dryrun: Whether to execute the created queries or not
    :param project: The GCP project to work in
    :param keyfile: The location of the keyfile credentials file
    :param output_dir: The output directory location
    :param run_version: The version to use as a table shard
    :param acob_doi_table: The version of the DOI table to use
    """

    def __init__(
        self, *, dryrun: bool, project: str, keyfile: str, output_dir: str, run_version: str, acob_doi_table: str
    ):
        self.dryrun = dryrun
        self.project = project
        self.keyfile = keyfile
        self.output_dir = output_dir
        self.run_version = run_version
        self.acob_doi_table = acob_doi_table
        self.workflow_hash = Repo(search_parent_directories=True).head.object.hexsha

        os.makedirs(self.output_dir, exist_ok=True)

    @property
    def generated_alltrials_name(self):
        """Name of the alltrials table resulting from our query"""
        return f"alltrials{self.run_version}"

    @property
    def generated_trials_name(self):
        """Name of the trials table resulting from our query"""
        return f"trials{self.run_version}"

    @property
    def generated_pubs_name(self):
        """Name of the pubs table resulting from our query"""
        return f"pubs{self.run_version}"

    @staticmethod
    def from_dict(cfg: dict):
        """Checks that the config is valid then constructs the Config object from the dictionary"""

        errors: List[str] = []

        # Type checking
        if not isinstance(cfg.get("dryrun"), bool):
            errors.append(f"'dryrun' must be either True, or False, got {cfg.get('dryrun')}")

        if cfg.get("dryrun") == False:
            if not cfg.get("keyfile"):
                errors.append("No keyfile provided.")
            elif not os.path.exists(cfg.get("keyfile")):
                errors.append(f"Keyfile: {cfg['keyfile']} does not exist.")

        if not cfg.get("project"):
            errors.append("No GCP project (project) provided.")
        if not cfg.get("output_dir"):
            errors.append("No output directory (output_dir) provided.")

        if not cfg.get("run_version"):
            errors.append("Run version (run_version) not provided.")
        else:
            try:
                datetime.strptime(str(cfg["run_version"]), "%Y%m%d").date()
            except Exception as e:
                errors.append(e.__str__())

        if not cfg.get("acob_doi_table"):
            errors.append("DOI table version (acob_doi_table) not provided.")
        else:
            try:
                datetime.strptime(str(cfg["acob_doi_table"]), "%Y%m%d").date()
            except Exception as e:
                errors.append(e.__str__())

        if errors:
            msg = "\n".join(errors)
            raise RuntimeError(f"Encountered error(s) in config construction: {msg}")

        return Context(
            project=cfg["project"],
            dryrun=cfg["dryrun"],
            keyfile=cfg.get("keyfile"),
            output_dir=cfg["output_dir"],
            run_version=cfg["run_version"],
            acob_doi_table=cfg["acob_doi_table"],
        )

    def to_dict(self) -> dict:
        return dict(
            dryrun=self.dryrun,
            project=self.project,
            keyfile=self.keyfile,
            output_dir=self.output_dir,
            run_version=self.run_version,
            acob_doi_table=self.acob_doi_table,
            workflow_hash=self.workflow_hash,
        )


class Config:
    """The workflow configuration. Made up of the context and the partners"""

    def __init__(self, *, context: Context, partners: List[Partner]):
        self.context = context
        self.partners = partners

    @staticmethod
    def from_dict(cfg: dict):
        """Checks that the config is valid then constructs the Config object from the dictionary"""

        errors: List[str] = []

        if not cfg.get("context"):
            errors.append("No context provided in configuration")
        if not cfg.get("partners"):
            errors.append("No partners provided in configuration")

        context = Context.from_dict(cfg["context"])
        partners = [Partner.from_dict(p) for p in cfg["partners"]]
        return Config(
            context=context,
            partners=partners,
        )
