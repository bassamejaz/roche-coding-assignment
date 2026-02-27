"""
Test Script for Clinical Trial Data Agent

This script demonstrates the agent's capability to answer natural language
questions about adverse events data by running 3 example queries.
"""

import sys
import os
from datetime import datetime
from clinical_data_agent import ClinicalTrialDataAgent


def print_header(title):
    """Print a formatted header."""
    print("\n" + "=" * 80)
    print(f"  {title}")
    print("=" * 80)


def save_results_to_file(results, filename="question_4_python/outputs/test_results.txt"):
    """Save test results to a file."""
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with open(filename, 'w') as f:
        f.write("=" * 80 + "\n")
        f.write("Clinical Trial Data Agent - Test Results\n")
        f.write(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 80 + "\n\n")

        for i, result in enumerate(results, 1):
            f.write(f"\n{'='*80}\n")
            f.write(f"Test Query {i}\n")
            f.write(f"{'='*80}\n")
            f.write(f"Question: {result['question']}\n\n")

            if 'error' in result['result']:
                f.write(f"ERROR: {result['result']['error']}\n")
            else:
                f.write(f"Query Parameters:\n")
                f.write(f"  - Target Column: {result['result']['query_params']['target_column']}\n")
                f.write(f"  - Filter Value: {result['result']['query_params']['filter_value']}\n")
                f.write(f"  - Filter Type: {result['result']['query_params'].get('filter_type', 'contains')}\n")

                if result['result']['query_params'].get('additional_filters'):
                    f.write(f"  - Additional Filters: {result['result']['query_params']['additional_filters']}\n")

                f.write(f"\nResults:\n")
                f.write(f"  - Subject Count: {result['result']['subject_count']}\n")
                f.write(f"  - Total AE Records: {result['result']['total_ae_records']}\n")

                if result['result']['subject_count'] > 0:
                    f.write(f"\n  Subject IDs (first 20):\n")
                    for subj_id in result['result']['subject_ids'][:20]:
                        f.write(f"    - {subj_id}\n")

                    if result['result']['subject_count'] > 20:
                        f.write(f"    ... and {result['result']['subject_count'] - 20} more\n")

            f.write("\n")

        f.write("\n" + "=" * 80 + "\n")
        f.write("Test Completed Successfully\n")
        f.write("=" * 80 + "\n")


def main():
    """
    Main test function - runs 3 example queries demonstrating the agent's capabilities.
    """
    print_header("Clinical Trial Data Agent - Test Script")
    print(f"\nTimestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("\nThis script tests the GenAI assistant with 3 natural language queries")
    print("demonstrating its ability to understand clinical data questions.\n")

    # Check for API key
    if not os.getenv("OPENAI_API_KEY"):
        print("⚠️  Warning: OPENAI_API_KEY not found in environment variables.")
        print("   Please set it using: export OPENAI_API_KEY='your-key-here'")
        print("   Or create a .env file in question_4_python/")
        sys.exit(1)

    # Initialize agent
    print("\n[Initializing Agent]")
    print("Loading ADAE dataset and initializing LLM...")

    try:
        agent = ClinicalTrialDataAgent("question_4_python/adae.csv")
        print("✓ Agent initialized successfully\n")
    except FileNotFoundError:
        print("✗ Error: adae.csv not found. Please ensure the file exists in question_4_python/")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Error initializing agent: {e}")
        sys.exit(1)

    # Define test queries
    test_queries = [
        # Query 1: Test severity mapping (AESEV)
        "Give me the subjects who had Adverse events of Moderate severity",

        # Query 2: Test condition/term mapping (AETERM)
        "Show me all subjects who experienced Headache",

        # Query 3: Test body system mapping (AESOC)
        "Which subjects had adverse events in the Cardiac disorders system?"
    ]

    # Run queries and collect results
    results = []

    for i, question in enumerate(test_queries, 1):
        print_header(f"Test Query {i} of {len(test_queries)}")

        try:
            result = agent.ask(question)
            results.append({
                "question": question,
                "result": result,
                "status": "success"
            })

            # Print summary
            if "error" not in result:
                print(f"✓ Query completed successfully")
                print(f"  Found {result['subject_count']} subjects with matching criteria")
            else:
                print(f"✗ Query failed: {result['error']}")

        except Exception as e:
            print(f"✗ Error executing query: {e}")
            results.append({
                "question": question,
                "result": {"error": str(e)},
                "status": "failed"
            })

        # Add spacing between queries
        if i < len(test_queries):
            print("\n" + "-" * 80)

    # Print overall summary
    print_header("Test Summary")
    successful = sum(1 for r in results if r['status'] == 'success' and 'error' not in r['result'])
    print(f"\nTotal Queries: {len(test_queries)}")
    print(f"Successful: {successful}")
    print(f"Failed: {len(test_queries) - successful}\n")

    # Print summary table
    print("Query Results Summary:")
    print("-" * 80)
    print(f"{'Query':<50} {'Subjects Found':<15} {'Status':<15}")
    print("-" * 80)

    for r in results:
        query_short = r['question'][:47] + "..." if len(r['question']) > 50 else r['question']
        subjects = r['result'].get('subject_count', 'N/A')
        status = "✓ Success" if r['status'] == 'success' and 'error' not in r['result'] else "✗ Failed"
        print(f"{query_short:<50} {str(subjects):<15} {status:<15}")

    print("-" * 80)

    # Save results to file
    print("\n[Saving Results]")
    try:
        save_results_to_file(results)
        print("✓ Detailed results saved to: question_4_python/outputs/test_results.txt")
    except Exception as e:
        print(f"✗ Error saving results: {e}")

    print("\n" + "=" * 80)
    print("Test Script Completed")
    print("=" * 80)
    print("\nNext Steps:")
    print("  1. Review the detailed results in question_4_python/outputs/test_results.txt")
    print("  2. Try additional queries by importing and using the ClinicalTrialDataAgent class")
    print("  3. Customize the agent for your specific clinical data needs\n")


if __name__ == "__main__":
    main()
