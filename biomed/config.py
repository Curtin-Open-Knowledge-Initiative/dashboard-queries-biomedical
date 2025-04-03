import os
from datetime import datetime
from typing import List, Union

from git import Repo


class Partner:
    """A single partner's configuration for the workflow

    :param institution_id: The internal ID given to this partner.
    :param orcid_table_name: The name of the partner input orcid table.
    :param trials_aact_table_name: The name of the partner input trials aact table.
    :param dois_table_name: The name of the partner input doi table.
    :param oddpub_table_name: The name of the partner input oddpub table.
    :param year_cutoff: The cutoff publication year for this partner.
    """

    def __init__(
        self,
        *,
        institution_id: str,
        orcid_table_name: str,
        dois_table_name: str,
        trials_aact_table_name: str,
        oddpub_table_name: str,
        year_cutoff: Union[int, str],
    ):
        self.institution_id = institution_id
        self.orcid_table_name = orcid_table_name
        self.dois_table_name = dois_table_name
        self.trials_aact_table_name = trials_aact_table_name
        self.oddpub_table_name = oddpub_table_name
        self.year_cutoff = year_cutoff

    @property
    def output_dataset(self):
        return f"{self.institution_id}_data"

    @property
    def latest_dataset(self):
        return f"{self.institution_id}_data_latest"

    @property
    def static_dataset(self):
        return f"{self.institution_id}_from_partners"

    @property
    def alltrials_query_fname(self):
        return f"{self.institution_id}_alltrials.sql"

    @property
    def trials_query_fname(self):
        return f"{self.institution_id}_trials.sql"

    @property
    def pubs_query_fname(self):
        return f"{self.institution_id}_pubs.sql"

    @property
    def orcid_query_fname(self):
        return f"{self.institution_id}_orcid.sql"

    @property
    def trials_latest_fname(self):
        return f"{self.institution_id}_trials_latest.sql"

    @property
    def pubs_latest_fname(self):
        return f"{self.institution_id}_pubs_latest.sql"

    @property
    def orcid_latest_fname(self):
        return f"{self.institution_id}_orcid_latest.sql"

    @staticmethod
    def from_dict(partner: dict):
        """Constructs a partner object from a dictionary. Checks that it is valid"""

        errors: List[str] = []

        if not partner.get("institution_id"):
            errors.append("Partner construction missing attribute: institution_id")
        if not partner.get("orcid_table_name"):
            errors.append("Partner construction missing attribute: orcid_table_name")
        if not partner.get("dois_table_name"):
            errors.append("Partner construction missing attribute: dois_table_name")
        if not partner.get("trials_aact_table_name"):
            errors.append("Partner construction missing attribute: trials_aact_table_name")
        if not partner.get("oddpub_table_name"):
            errors.append("Partner construction missing attribute: oddpub_table_name")

        if errors:
            msg: str = "\n".join(errors) + f"\nSupplied dict: {partner}"
            raise RuntimeError(f"Encountered error(s) in partner construction: {msg}")
        return Partner(
            institution_id=partner["institution_id"],
            orcid_table_name=partner["orcid_table_name"],
            dois_table_name=partner["dois_table_name"],
            trials_aact_table_name=partner["trials_aact_table_name"],
            oddpub_table_name=partner["oddpub_table_name"],
            year_cutoff=partner.get("year_cutoff", 1),  # Default to 1 if not provided (all years)
        )

    def to_dict(self) -> dict:
        return dict(
            institution_id=self.institution_id,
            orcid_table_name=self.orcid_table_name,
            dois_table_name=self.dois_table_name,
            trials_aact_table_name=self.trials_aact_table_name,
            oddpub_table_name=self.oddpub_table_name,
            year_cutoff=self.year_cutoff,
        )


class Context:
    """Contains the contextual information of the workflow configuration

    :param dryrun: Whether to execute the created queries or not
    :param project: The GCP project to work in
    :param keyfile: The location of the keyfile credentials file
    :param output_dir: The output directory location
    :param run_version: The version to use as a table shard
    :param doi_version: The version of the DOI table to use
    """

    def __init__(
        self, *, dryrun: bool, project: str, keyfile: str, output_dir: str, run_version: str, doi_version: str
    ):
        self.dryrun = dryrun
        self.project = project
        self.keyfile = keyfile
        self.output_dir = output_dir
        self.run_version = run_version
        self.doi_version = doi_version
        self.workflow_hash = Repo(search_parent_directories=True).head.object.hexsha

        os.makedirs(self.output_dir, exist_ok=True)

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

        if not cfg.get("doi_version"):
            errors.append("DOI table version (doi_version) not provided.")
        else:
            try:
                datetime.strptime(str(cfg["doi_version"]), "%Y%m%d").date()
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
            doi_version=cfg["doi_version"],
        )

    def to_dict(self) -> dict:
        return dict(
            dryrun=self.dryrun,
            project=self.project,
            keyfile=self.keyfile,
            output_dir=self.output_dir,
            run_version=self.run_version,
            doi_version=self.doi_version,
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
