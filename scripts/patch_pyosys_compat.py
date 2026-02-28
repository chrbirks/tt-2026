#!/usr/bin/env python3
"""Patch librelane's ys_common.py for pyosys API compatibility.

Yosys 0.58 rewrote pyosys from SWIG to pybind11, changing the Python API:
  Old (SWIG):     ys.Pass.call__YOSYS_NAMESPACE_RTLIL_Design__...(design, cmds)
  New (pybind11):  ys.run_pass("cmd args", design)

LibreLane 3.0.0.dev44 hardcodes the old SWIG call.  This script patches
_Design_run_pass() to try pybind11 first, falling back to SWIG.
"""

import os
import site
import sys

PATCHED_MARKER = "# patched by patch_pyosys_compat.py"


def find_ys_common_files():
    """Find all ys_common.py files across venv, user, and system site-packages."""
    search_dirs = set()

    for p in site.getsitepackages():
        search_dirs.add(p)

    user_site = site.getusersitepackages()
    if isinstance(user_site, str):
        search_dirs.add(user_site)

    for p in sys.path:
        if "site-packages" in p or "dist-packages" in p:
            search_dirs.add(p)

    results = []
    for base in search_dirs:
        candidate = os.path.join(base, "librelane", "scripts", "pyosys", "ys_common.py")
        if os.path.isfile(candidate):
            results.append(candidate)
    return results


def patch_file(filepath):
    """Patch a single ys_common.py file using line-by-line search."""
    with open(filepath, "r") as f:
        lines = f.readlines()

    if any(PATCHED_MARKER in line for line in lines):
        print(f"  [skip] {filepath} (already patched)")
        return False

    # Find the line defining _Design_run_pass
    func_line_idx = None
    for i, line in enumerate(lines):
        if "def _Design_run_pass" in line:
            func_line_idx = i
            break

    if func_line_idx is None:
        print(f"  [skip] {filepath} (_Design_run_pass not found)")
        print(f"         first 5 lines: {[l.rstrip() for l in lines[:5]]}")
        return False

    # Detect the indentation from the def line
    def_line = lines[func_line_idx]
    indent = ""
    for ch in def_line:
        if ch in (" ", "\t"):
            indent += ch
        else:
            break

    # Find the end of the function body: first line that is NOT more indented
    # than the def line (and is not blank)
    body_end = func_line_idx + 1
    while body_end < len(lines):
        line = lines[body_end]
        stripped = line.strip()
        if stripped == "":
            # blank line — could be inside the function, keep scanning
            body_end += 1
            continue
        # Check if this line is still part of the body (more indented than def)
        if line.startswith(indent) and len(line) > len(indent) and line[len(indent)] in (" ", "\t"):
            body_end += 1
        else:
            break

    # Build the replacement function
    replacement_lines = [
        f"{indent}def _Design_run_pass(self, command):\n",
        f"{indent}    {PATCHED_MARKER}\n",
        f"{indent}    if hasattr(ys, 'run_pass'):\n",
        f"{indent}        ys.run_pass(\" \".join(command), self)\n",
        f"{indent}    else:\n",
        f"{indent}        ys.Pass.call__YOSYS_NAMESPACE_RTLIL_Design__std_vector_string_(self, list(command))\n",
    ]

    new_lines = lines[:func_line_idx] + replacement_lines + lines[body_end:]

    with open(filepath, "w") as f:
        f.writelines(new_lines)

    print(f"  [patched] {filepath} (replaced lines {func_line_idx+1}-{body_end})")
    return True


def main():
    files = find_ys_common_files()
    if not files:
        print("No ys_common.py files found - librelane may not be installed.")
        print("Searched site-packages directories:")
        for p in sorted(set(site.getsitepackages())):
            print(f"  {p}")
        sys.exit(1)

    print(f"Found {len(files)} ys_common.py file(s):")
    patched = 0
    for f in files:
        if patch_file(f):
            patched += 1

    if patched:
        print(f"\nPatched {patched} file(s) for pyosys API compatibility.")
    else:
        print("\nNo files needed patching.")


if __name__ == "__main__":
    main()
