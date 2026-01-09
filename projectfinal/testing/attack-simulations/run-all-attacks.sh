#!/bin/bash
# run-all-attacks.sh - Run all attack simulations
# Zero Trust Architecture Capstone Project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  ZTA Attack Simulation Suite"
echo "========================================"
echo ""
echo "This script will run all attack simulations to validate"
echo "the Zero Trust Architecture implementation."
echo ""
echo "Attack scenarios:"
echo "  T1: Credential Theft - Stolen token replay"
echo "  T2: Lateral Movement - Pod-to-pod unauthorized access"
echo "  T3: Cross-Cloud Access - Unauthorized hybrid cloud access"
echo "  T4: RBAC Bypass - Role escalation attempts"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

echo ""
echo "========================================"
echo "  T1 & T4: RBAC Bypass Tests"
echo "========================================"
bash "$SCRIPT_DIR/rbac-bypass.sh" || true

echo ""
echo "========================================"
echo "  T2: Lateral Movement Test"
echo "========================================"
bash "$SCRIPT_DIR/lateral-movement.sh" || true

echo ""
echo "========================================"
echo "  T3: Cross-Cloud Access Test"
echo "========================================"
bash "$SCRIPT_DIR/cross-cloud-access.sh" || true

echo ""
echo "========================================"
echo "  All Attack Simulations Complete"
echo "========================================"
echo ""
echo "Summary:"
echo "  - If all attacks were BLOCKED, your ZTA implementation is working correctly"
echo "  - Any SUCCESS results indicate potential security vulnerabilities"
echo ""
echo "Review the output above for detailed results of each test."
