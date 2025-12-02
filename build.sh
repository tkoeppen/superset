#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Apache Superset Build Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    exit 1
fi
echo "Node.js version: $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed${NC}"
    exit 1
fi
echo "npm version: $(npm --version)"

# Check Python - prefer Python 3.10-3.12 as per pyproject.toml
PYTHON=""
for py_cmd in python3.12 python3.11 python3.10 python3; do
    if command -v $py_cmd &> /dev/null; then
        PYTHON=$py_cmd
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

PYTHON_VERSION=$($PYTHON --version 2>&1 | awk '{print $2}')
echo "Using Python: $PYTHON (version $PYTHON_VERSION)"

# Create and activate virtual environment
echo -e "\n${YELLOW}Setting up virtual environment...${NC}"
VENV_DIR="$SCRIPT_DIR/build-venv"

if [ -d "$VENV_DIR" ]; then
    echo "Removing existing build virtual environment..."
    rm -rf "$VENV_DIR"
fi

echo "Creating virtual environment with $PYTHON..."
$PYTHON -m venv "$VENV_DIR"

echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "Virtual environment activated: $(which python)"
echo "Python version in venv: $(python --version)"

# Install build dependencies
echo "Installing build dependencies..."
pip install --upgrade pip setuptools wheel build

# Build frontend
echo -e "\n${YELLOW}Building frontend assets...${NC}"
cd superset-frontend

echo "Installing frontend dependencies..."
time npm ci

echo "Building production assets..."
time npm run build

cd "$SCRIPT_DIR"
echo -e "${GREEN}✓ Frontend build complete${NC}"

# Build Python package
echo -e "\n${YELLOW}Building Python package...${NC}"

echo "Creating distribution packages..."
time python -m build

# Deactivate virtual environment
deactivate

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

# List built packages
if [ -d "dist" ]; then
    echo -e "\n${YELLOW}Built packages:${NC}"
    ls -lh dist/

    echo -e "\n${YELLOW}To install the package:${NC}"
    echo "  pip install dist/apache_superset-*.whl"
    echo ""
    echo -e "${YELLOW}Or install source distribution:${NC}"
    echo "  pip install dist/apache_superset-*.tar.gz"
    echo ""
    echo -e "${YELLOW}Note:${NC} Build virtual environment can be removed with:"
    echo "  rm -rf build-venv"
else
    echo -e "${RED}Warning: dist/ directory not found${NC}"
fi

echo ""
