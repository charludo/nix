"""Import the integration's pure modules without Home Assistant.

`timers` has no HA imports; the package's `__init__` does, so
the modules are loaded as part of a stand-in package instead.
"""

import importlib.util
import sys
import types
from pathlib import Path

PKG_DIR = Path(__file__).resolve().parent.parent / "custom_components" / "remembrance"

package = types.ModuleType("remembrance")
package.__path__ = [str(PKG_DIR)]
sys.modules["remembrance"] = package

for name in ("timers",):
    spec = importlib.util.spec_from_file_location(f"remembrance.{name}", PKG_DIR / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[f"remembrance.{name}"] = module
    spec.loader.exec_module(module)
