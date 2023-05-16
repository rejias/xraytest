#!/bin/bash

parse_test_results() {
    local results_file="$1"
    local file_extension="${results_file##*.}"

    if [[ $file_extension == "xml" ]]; then
        # Parse XML file
        test_cases=()
        while IFS= read -r testcase; do
            name=$(echo "$testcase" | sed -n 's/.*name="\([^"]*\)".*/\1/p')
            duration=$(echo "$testcase" | sed -n 's/.*time="\([^"]*\)".*/\1/p')
            status="PASS"
            if [[ $testcase == *"<failure"* ]]; then
                status="FAIL"
            fi
            test_cases+=("{\"test_case\":\"$name\",\"status\":\"$status\",\"duration\":$duration}")
        done < <(grep -o '<testcase[^>]*>.*<\/testcase>' "$results_file")
    elif [[ $file_extension == "json" ]]; then
        # Parse JSON file
        test_cases=$(jq -c '.tests[] | {test_case: .name, status: .result, duration: .time}' "$results_file")
    else
        echo "Unsupported file format"
        exit 1
    fi

    echo "$test_cases"
}

push_test_results_to_xray() {
    local test_cases="$1"
    local url="https://your-xray-instance/rest/raven/1.0/import/execution"
    local auth="username:password"
    local payload=$(cat <<EOF
{
    "testExecutionKey": "MY-PROJECT-123",
    "testEnvironments": ["my-test-environment"],
    "testExecIssueKey": "MY-TEST-EXEC-1",
    "info": {
        "summary": "Test Execution Summary",
        "description": "Test Execution Description"
    },
    "tests": [$test_cases]
}
EOF
)

    local response=$(curl -s -X POST -u "$auth" -H "Content-Type: application/json" -d "$payload" "$url")
    local status_code=$(echo "$response" | jq -r '.status')

    if [[ $status_code != "200" ]]; then
        echo "Failed to push test results to Xray API"
        exit 1
    fi
}

# Example usage
results_file="test-results.xml"
test_cases=$(parse_test_results "$results_file")
push_test_results_to_xray "$test_cases"