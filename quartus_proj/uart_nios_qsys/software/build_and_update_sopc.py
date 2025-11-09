#!/usr/bin/env python3
"""
NIOS2 Build and SOPC Update Script

This script automates the following workflow:
1. Builds the NIOS2 BSP (Board Support Package)
2. Builds the NIOS2 application program
3. Generates the mem_init files (.hex)
4. Updates the SOPC/Qsys file with new memory initialization
"""

import os
import sys
import subprocess
from pathlib import Path

# ============================================================================
# CONFIGURATION - Modify these variables as needed
# ============================================================================

# Path to SOPC/Qsys file (relative to this script or absolute path)
SOPC_FILE = "../uart_nios.qsys"

# BSP directory name (relative to this script)
BSP_DIR = "fir_uart_nios_bsp"

# Application directory name (relative to this script)
APP_DIR = "fir_uart_nios"

# Build options
SKIP_CLEAN = False          # Set to True to skip clean step (faster rebuild)
SKIP_BSP_BUILD = False      # Set to True to skip BSP build (only build app)
SKIP_SOPC_UPDATE = False    # Set to True to skip SOPC update step

# ============================================================================


def run_command(cmd, cwd=None, shell=True):
    """Execute a command and handle errors"""
    print(f"\n{'='*60}")
    print(f"Running: {cmd}")
    print(f"Working directory: {cwd or os.getcwd()}")
    print(f"{'='*60}")

    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            shell=shell,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        print(result.stdout)
        if result.stderr:
            print(f"STDERR: {result.stderr}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Command failed with exit code {e.returncode}")
        print(f"STDOUT: {e.stdout}")
        print(f"STDERR: {e.stderr}")
        return False


def find_nios2eds():
    """Find NIOS2 EDS installation path"""
    # Common installation paths
    possible_paths = [
        os.environ.get('SOPC_KIT_NIOS2'),
        r"C:\intelFPGA_lite\20.1\nios2eds",
        r"C:\intelFPGA\20.1\nios2eds",
        r"C:\intelFPGA_lite\21.1\nios2eds",
        r"C:\intelFPGA\21.1\nios2eds",
        r"C:\altera\nios2eds",
    ]

    for path in possible_paths:
        if path and os.path.exists(path):
            print(f"Found NIOS2 EDS at: {path}")
            return path

    print("WARNING: NIOS2 EDS path not found automatically.")
    print("Please ensure nios2eds binaries are in your PATH or set SOPC_KIT_NIOS2 environment variable.")
    return None


def setup_nios2_environment():
    """Setup NIOS2 EDS environment variables"""
    nios2eds_path = find_nios2eds()

    if nios2eds_path:
        # Add NIOS2 EDS binaries to PATH
        bin_path = os.path.join(nios2eds_path, "bin")
        gnu_bin_path = os.path.join(nios2eds_path, "bin", "gnu", "H-x86_64-mingw32", "bin")

        current_path = os.environ.get('PATH', '')
        os.environ['PATH'] = f"{bin_path};{gnu_bin_path};{current_path}"
        os.environ['SOPC_KIT_NIOS2'] = nios2eds_path

        print(f"Updated PATH with NIOS2 EDS binaries")
        print(f"SOPC_KIT_NIOS2={nios2eds_path}")


def clean_bsp(bsp_dir):
    """Clean the BSP directory"""
    print(f"\n{'*'*60}")
    print("STEP: Cleaning BSP")
    print(f"{'*'*60}")

    return run_command("make clean", cwd=bsp_dir)


def build_bsp(bsp_dir):
    """Build the NIOS2 BSP"""
    print(f"\n{'*'*60}")
    print("STEP: Building BSP")
    print(f"{'*'*60}")

    # First, try to generate/update the BSP using nios2-bsp if settings.bsp exists
    settings_bsp = os.path.join(bsp_dir, "settings.bsp")
    if os.path.exists(settings_bsp):
        print(f"Regenerating BSP from {settings_bsp}")
        # This ensures the BSP is up to date with the SOPC file
        run_command(f"nios2-bsp-generate-files --bsp-dir {bsp_dir} --settings {settings_bsp}")

    # Build the BSP
    return run_command("make", cwd=bsp_dir)


def clean_app(app_dir):
    """Clean the application directory"""
    print(f"\n{'*'*60}")
    print("STEP: Cleaning Application")
    print(f"{'*'*60}")

    return run_command("make clean", cwd=app_dir)


def build_app(app_dir):
    """Build the NIOS2 application"""
    print(f"\n{'*'*60}")
    print("STEP: Building Application")
    print(f"{'*'*60}")

    return run_command("make", cwd=app_dir)


def generate_mem_init(app_dir, bsp_dir):
    """Generate memory initialization files (.hex)"""
    print(f"\n{'*'*60}")
    print("STEP: Generating Memory Initialization Files")
    print(f"{'*'*60}")

    # The mem_init_generate command creates .hex files from the .elf
    elf_file = os.path.join(app_dir, os.path.basename(app_dir) + ".elf")

    if not os.path.exists(elf_file):
        print(f"ERROR: ELF file not found: {elf_file}")
        return False

    print(f"Using ELF file: {elf_file}")

    # Generate mem_init files
    # This will create .hex files in the application directory
    cmd = f"elf2hex {elf_file} --base=0x00000000 --end=0x00007FFF --width=32 --little-endian-lanes --create-lanes=0,1,2,3"
    success = run_command(cmd, cwd=app_dir)

    if success:
        # Also try using mem_init_generate if available (creates files in specific format)
        mem_init_cmd = f"nios2-elf-mem-init-generate --infile={elf_file}"
        run_command(mem_init_cmd, cwd=app_dir)

    return success


def update_sopc_memory(sopc_file):
    """Update SOPC/Qsys file with new memory initialization"""
    print(f"\n{'*'*60}")
    print("STEP: Updating SOPC/Qsys Memory Initialization")
    print(f"{'*'*60}")

    if not os.path.exists(sopc_file):
        print(f"ERROR: SOPC file not found: {sopc_file}")
        return False

    print(f"SOPC file: {sopc_file}")

    # Use qsys-generate to update the memory initialization
    # This command updates the Qsys system with new mem init files
    cmd = f"qsys-generate {sopc_file} --synthesis=VERILOG"

    return run_command(cmd, cwd=os.path.dirname(sopc_file))


def main():
    # Setup paths from configuration variables
    script_dir = os.path.dirname(os.path.abspath(__file__))
    bsp_dir = os.path.join(script_dir, BSP_DIR)
    app_dir = os.path.join(script_dir, APP_DIR)

    # Handle SOPC file path (can be relative or absolute)
    if os.path.isabs(SOPC_FILE):
        sopc_file = SOPC_FILE
    else:
        sopc_file = os.path.abspath(os.path.join(script_dir, SOPC_FILE))

    print(f"\n{'#'*60}")
    print("NIOS2 Build and SOPC Update Script")
    print(f"{'#'*60}")
    print(f"BSP Directory: {bsp_dir}")
    print(f"App Directory: {app_dir}")
    print(f"SOPC File: {sopc_file}")
    print(f"{'#'*60}\n")

    # Verify directories exist
    if not os.path.exists(bsp_dir):
        print(f"ERROR: BSP directory not found: {bsp_dir}")
        sys.exit(1)

    if not os.path.exists(app_dir):
        print(f"ERROR: Application directory not found: {app_dir}")
        sys.exit(1)

    # Setup NIOS2 EDS environment
    setup_nios2_environment()

    # Build process
    steps_passed = []
    steps_failed = []

    try:
        # Step 1: Clean and build BSP
        if not SKIP_BSP_BUILD:
            if not SKIP_CLEAN:
                if clean_bsp(bsp_dir):
                    steps_passed.append("Clean BSP")
                else:
                    steps_failed.append("Clean BSP")

            if build_bsp(bsp_dir):
                steps_passed.append("Build BSP")
            else:
                steps_failed.append("Build BSP")
                raise Exception("BSP build failed")
        else:
            print("\nSkipping BSP build...")

        # Step 2: Clean and build application
        if not SKIP_CLEAN:
            if clean_app(app_dir):
                steps_passed.append("Clean Application")
            else:
                steps_failed.append("Clean Application")

        if build_app(app_dir):
            steps_passed.append("Build Application")
        else:
            steps_failed.append("Build Application")
            raise Exception("Application build failed")

        # Step 3: Generate memory initialization files
        if generate_mem_init(app_dir, bsp_dir):
            steps_passed.append("Generate Memory Init Files")
        else:
            steps_failed.append("Generate Memory Init Files")
            print("WARNING: Memory init file generation had issues")

        # Step 4: Update SOPC file
        if not SKIP_SOPC_UPDATE:
            if update_sopc_memory(sopc_file):
                steps_passed.append("Update SOPC Memory")
            else:
                steps_failed.append("Update SOPC Memory")
                print("WARNING: SOPC update had issues")
        else:
            print("\nSkipping SOPC update...")

    except Exception as e:
        print(f"\n{'='*60}")
        print(f"BUILD FAILED: {e}")
        print(f"{'='*60}")

    # Summary
    print(f"\n{'#'*60}")
    print("BUILD SUMMARY")
    print(f"{'#'*60}")

    if steps_passed:
        print("\nPassed steps:")
        for step in steps_passed:
            print(f"   {step}")

    if steps_failed:
        print("\nFailed steps:")
        for step in steps_failed:
            print(f"   {step}")
        print(f"\n{'#'*60}")
        print("BUILD FAILED - See errors above")
        print(f"{'#'*60}")
        sys.exit(1)
    else:
        print(f"\n{'#'*60}")
        print("BUILD SUCCESSFUL!")
        print(f"{'#'*60}")
        print("\nNext steps:")
        print("1. In Quartus: Processing � Update Memory Initialization File")
        print("2. In Quartus: Processing � Start � Start Assembler")
        print("3. This will create a new SOF file with the updated program")
        sys.exit(0)


if __name__ == "__main__":
    main()
