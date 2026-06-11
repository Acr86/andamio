"""Repository layout discovery.

The CLI can be invoked from any directory inside the platform repository.
Rather than guessing from the current working directory, we walk upwards
until we find the repository root marker (the catalog directory next to a
git root). Every other module resolves paths through this one.
"""

from __future__ import annotations

from pathlib import Path

CATALOG_DIR = "catalog"
SERVICES_DIR = "services"
TEMPLATES_DIR = "templates"
KUSTOMIZE_SERVICES_DIR = Path("deploy") / "kustomize" / "services"


class NotInsideRepoError(RuntimeError):
    """Raised when the CLI is executed outside the platform repository."""


def find_repo_root(start: Path | None = None) -> Path:
    current = (start or Path.cwd()).resolve()
    for candidate in (current, *current.parents):
        if (candidate / CATALOG_DIR).is_dir() and (candidate / ".git").exists():
            return candidate
    raise NotInsideRepoError(
        "Not inside the platform repository: could not find a 'catalog/' "
        "directory next to a git root in any parent directory."
    )


def catalog_dir(root: Path) -> Path:
    return root / CATALOG_DIR


def services_dir(root: Path) -> Path:
    return root / SERVICES_DIR


def templates_dir(root: Path) -> Path:
    return root / TEMPLATES_DIR


def kustomize_services_dir(root: Path) -> Path:
    return root / KUSTOMIZE_SERVICES_DIR
