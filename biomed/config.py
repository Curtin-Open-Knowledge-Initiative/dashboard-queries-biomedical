import os
from datetime import datetime, date
from typing import List


class Partner:
    """A single partner's configuration for the workflow"""

    def __init__(self, *, name: str):
        self.name = name

    @staticmethod
    def from_dict(partner: dict):
        """Constructs a partner object from a dictionary. Checks that it is valid"""

        errors: List[str] = []

        if not partner.get("name"):
            errors.append("Partner construction missing attribute: name")

        if errors:
            msg: str = "\n".join(errors) + f"\nSupplied dict: {partner}"
            raise RuntimeError(f"Encountered error(s) in partner construction: {msg}")
        return Partner(name=partner["name"])


class Context:
    """Contains the contextual information of the workflow configuration"""

    def __init__(self, *, dryrun: bool, keyfile: str, output_dir: str, doi_version: date):
        self.dryrun = dryrun
        self.keyfile = keyfile
        self.output_dir = output_dir
        self.doi_version = doi_version

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

        if not cfg.get("output_dir"):
            errors.append("No output directory (output_dir) provided.")
        if not cfg.get("doi_version"):
            errors.append("No output directory (output_dir) provided.")
        else:
            try:
                doi_version = datetime.strptime(str(cfg["doi_version"]), "%Y%m%d").date()
            except Exception as e:
                errors.append(e.__str__())

        if errors:
            msg = "\n".join(errors)
            raise RuntimeError(f"Encountered error(s) in config construction: {msg}")

        return Context(
            dryrun=cfg.get("dryrun"),
            keyfile=cfg.get("keyfile"),
            output_dir=cfg.get("output_dir"),
            doi_version=doi_version,
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
