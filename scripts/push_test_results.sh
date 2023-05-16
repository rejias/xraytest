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
    local url="https://rejias.atlassian.net/rest/raven/2.0/api/test/TEST-123/step"
    local client_id="684549FA28844AD8B50BCE63606E72C2"
    local client_secret="ccb5b4ee95064829b5728b76c94622c1b92e46dc6ec980d087836e04b5876576"
    local auth=$(printf "%s:%s" "$client_id" "$client_secret" | base64)
    
    local payload=$(cat <<EOF
{
    "testExecutionKey": "MY-PROJECT-123",
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
results_file="Solution1/UnitTestProject/TestResults/test-results.xml"
test_cases=$(parse_test_results "$results_file")
push_test_results_to_xray "$test_cases"