#!/bin/bash

# Coverage Analysis Script for SwapUniswapV4Hook
# Parses lcov.info to extract uncovered lines, branches, and functions

set -e

HOOK_FILE="src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol"
LCOV_FILE="lcov.info"

echo "🔍 Analyzing coverage for SwapUniswapV4Hook..."

# Check if lcov.info exists
if [ ! -f "$LCOV_FILE" ]; then
    echo "❌ lcov.info not found. Run coverage command first:"
    echo "FOUNDRY_PROFILE=coverage forge coverage --match-contract SwapUniswapV4Hook --jobs 10 --ir-minimum --report lcov"
    exit 1
fi

echo "📊 Extracting coverage data from lcov.info..."

# Extract SwapUniswapV4Hook specific data
grep -A 1000 "SF:.*$HOOK_FILE" "$LCOV_FILE" | sed '/^SF:/d; /^end_of_record/q' > hook_coverage.tmp

# Function to extract line coverage
extract_line_coverage() {
    echo "=== LINE COVERAGE ==="
    
    # Get total lines
    TOTAL_LINES=$(grep "^LF:" hook_coverage.tmp | cut -d: -f2)
    COVERED_LINES=$(grep "^LH:" hook_coverage.tmp | cut -d: -f2)
    
    if [ -n "$TOTAL_LINES" ] && [ "$TOTAL_LINES" -gt 0 ]; then
        COVERAGE_PERCENT=$(( COVERED_LINES * 100 / TOTAL_LINES ))
        echo "Lines: $COVERED_LINES/$TOTAL_LINES ($COVERAGE_PERCENT%)"
        
        # Extract uncovered lines
        echo ""
        echo "🔴 UNCOVERED LINES:"
        grep "^DA:" hook_coverage.tmp | while IFS=: read -r prefix line_num hit_count; do
            if [ "$hit_count" = "0" ]; then
                echo "  Line $line_num: Not executed"
            fi
        done
    else
        echo "No line coverage data found"
    fi
}

# Function to extract branch coverage  
extract_branch_coverage() {
    echo ""
    echo "=== BRANCH COVERAGE ==="
    
    # Get total branches
    TOTAL_BRANCHES=$(grep "^BRF:" hook_coverage.tmp | cut -d: -f2 2>/dev/null || echo "0")
    COVERED_BRANCHES=$(grep "^BRH:" hook_coverage.tmp | cut -d: -f2 2>/dev/null || echo "0")
    
    if [ "$TOTAL_BRANCHES" -gt 0 ]; then
        BRANCH_PERCENT=$(( COVERED_BRANCHES * 100 / TOTAL_BRANCHES ))
        echo "Branches: $COVERED_BRANCHES/$TOTAL_BRANCHES ($BRANCH_PERCENT%)"
        
        # Extract uncovered branches
        echo ""
        echo "🔴 UNCOVERED BRANCHES:"
        grep "^BRDA:" hook_coverage.tmp | while IFS=: read -r prefix line_num block_num branch_num hit_count; do
            if [ "$hit_count" = "0" ] || [ "$hit_count" = "-" ]; then
                echo "  Line $line_num, Block $block_num, Branch $branch_num: Not taken"
            fi
        done
    else
        echo "No branch coverage data found"
    fi
}

# Function to extract function coverage
extract_function_coverage() {
    echo ""
    echo "=== FUNCTION COVERAGE ==="
    
    # Get total functions
    TOTAL_FUNCTIONS=$(grep "^FNF:" hook_coverage.tmp | cut -d: -f2 2>/dev/null || echo "0")
    COVERED_FUNCTIONS=$(grep "^FNH:" hook_coverage.tmp | cut -d: -f2 2>/dev/null || echo "0")
    
    if [ "$TOTAL_FUNCTIONS" -gt 0 ]; then
        FUNCTION_PERCENT=$(( COVERED_FUNCTIONS * 100 / TOTAL_FUNCTIONS ))
        echo "Functions: $COVERED_FUNCTIONS/$TOTAL_FUNCTIONS ($FUNCTION_PERCENT%)"
        
        # Extract uncovered functions
        echo ""
        echo "🔴 UNCOVERED FUNCTIONS:"
        # Get function names and their hit counts
        grep "^FN:" hook_coverage.tmp | while IFS=: read -r prefix line_num func_name; do
            # Check if this function was hit
            HIT=$(grep "^FNDA:.*,$func_name\$" hook_coverage.tmp | cut -d: -f2 | cut -d, -f1)
            if [ "$HIT" = "0" ] || [ -z "$HIT" ]; then
                echo "  $func_name (line $line_num): Not called"
            fi
        done
    else
        echo "No function coverage data found"
    fi
}

# Function to suggest test cases based on uncovered areas
suggest_test_cases() {
    echo ""
    echo "=== SUGGESTED TEST CASES ==="
    echo ""
    
    # Check for specific uncovered patterns
    grep "^DA:" hook_coverage.tmp | while IFS=: read -r prefix line_num hit_count; do
        if [ "$hit_count" = "0" ]; then
            # Get the actual line content (approximate)
            echo "📝 Line $line_num needs coverage - consider testing:"
            
            # Common patterns that need testing
            case $line_num in
                *) echo "    - Edge case or error condition on line $line_num" ;;
            esac
        fi
    done
}

# Main execution
extract_line_coverage
extract_branch_coverage  
extract_function_coverage
suggest_test_cases

# Cleanup
rm -f hook_coverage.tmp

echo ""
echo "✅ Coverage analysis complete!"
echo ""
echo "💡 To improve coverage:"
echo "1. Add tests for uncovered lines (error conditions)"
echo "2. Test both branches of conditionals"
echo "3. Call all functions in different scenarios"
echo "4. Test edge cases and boundary conditions"
echo ""
echo "Run coverage again with:"
echo "FOUNDRY_PROFILE=coverage forge coverage --match-contract SwapUniswapV4Hook --jobs 10 --ir-minimum --report lcov"