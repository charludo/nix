"""Import the integration's pure modules without Home Assistant.

`protocol` and `clock` have no HA imports; the package's `__init__` does, so the
modules are loaded as part of a stand-in package instead.
"""

import importlib.util
import sys
import types
from pathlib import Path

PKG_DIR = Path(__file__).resolve().parent.parent / "custom_components" / "echo_wall_clock"

package = types.ModuleType("echo_wall_clock")
package.__path__ = [str(PKG_DIR)]
sys.modules["echo_wall_clock"] = package

for name in ("protocol", "clock"):
    spec = importlib.util.spec_from_file_location(f"echo_wall_clock.{name}", PKG_DIR / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[f"echo_wall_clock.{name}"] = module
    spec.loader.exec_module(module)
