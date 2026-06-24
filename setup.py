"""Editable install setup for mastering_tool.

The Python code lives under the `tools/` directory, but it is exposed as the
package `mastering_tool.tools.*` so that absolute imports like
`from mastering_tool.tools.chain_dsl.schema import Chain` resolve correctly.
"""

from __future__ import annotations

from pathlib import Path
from setuptools import find_packages, setup

TOOLS_DIR = Path(__file__).parent / "tools"


def _discover() -> tuple[list[str], dict[str, str]]:
    """Return (packages, package_dir) mapping tools/ -> mastering_tool.tools.*."""
    if not TOOLS_DIR.exists():
        raise FileNotFoundError(f"tools directory not found: {TOOLS_DIR}")

    sub_packages = find_packages(where=str(TOOLS_DIR))
    packages: list[str] = ["mastering_tool.tools"]
    package_dir: dict[str, str] = {"mastering_tool.tools": "tools"}

    for pkg in sub_packages:
        full_name = f"mastering_tool.tools.{pkg}"
        packages.append(full_name)
        rel_path = pkg.replace(".", "/")
        package_dir[full_name] = str(Path("tools") / rel_path)

    return packages, package_dir


packages, package_dir = _discover()

setup(
    packages=packages,
    package_dir=package_dir,
    include_package_data=True,
    zip_safe=False,
)
