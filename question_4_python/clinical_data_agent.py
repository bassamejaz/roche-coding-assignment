"""
Question 4: GenAI Clinical Data Assistant (LLM & LangChain)

Objective: Develop a Generative AI Assistant that translates natural language
           questions into structured Pandas queries for clinical trial data.

Features:
- Understands dataset schema dynamically
- Maps user intent to correct variables (severity → AESEV, condition → AETERM, etc.)
- Returns structured JSON with target_column and filter_value
- Executes Pandas queries and returns subject counts and IDs
"""

import pandas as pd
import os
from typing import Dict, List, Optional
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
import json
from dotenv import load_dotenv

load_dotenv()

class ClinicalTrialDataAgent:
    """
    A GenAI-powered agent that translates natural language queries about
    clinical trial adverse event data into structured Pandas queries.
    """

    def __init__(self, data_path: str, api_key: Optional[str] = None):
        """
        Initialize the Clinical Trial Data Agent.

        Args:
            data_path: Path to the ADAE CSV file
            api_key: OpenAI API key (if None, reads from environment)
        """
        # Load data
        self.df = pd.read_csv(data_path)

        # Set up OpenAI API
        if api_key:
            os.environ["OPENAI_API_KEY"] = api_key

        # Initialize LLM
        self.llm = ChatOpenAI(
            model="us.anthropic.claude-sonnet-4-20250514-v1:0",
            api_key=os.getenv("BEDROCK_PORTKEY_API_KEY"),
            base_url=os.getenv("PORTKEY_URL"),
            temperature=0
        )

        # Define schema information for the LLM
        self.schema_description = self._build_schema_description()


    def _build_schema_description(self) -> str:
        """
        Build a comprehensive description of the dataset schema for the LLM.
        """
        # Get sample values for key columns
        aesev_values = self.df['AESEV'].dropna().unique()[:10]
        aeterm_values = self.df['AETERM'].dropna().unique()[:20]
        aesoc_values = self.df['AESOC'].dropna().unique()[:15]
        actarm_values = self.df['ACTARM'].dropna().unique()

        schema_desc = f"""
CLINICAL TRIAL ADVERSE EVENT DATASET SCHEMA:

This dataset contains adverse event (AE) records from a clinical trial.
Each row represents one adverse event for one subject.

KEY COLUMNS AND THEIR MEANINGS:

1. USUBJID (Unique Subject Identifier)
   - Type: String
   - Description: Unique identifier for each subject in the study
   - Use: To count or list subjects

2. AESEV (Adverse Event Severity)
   - Type: Categorical
   - Description: Severity/intensity level of the adverse event
   - Possible values: {', '.join(map(str, aesev_values))}
   - Keywords that map to AESEV: severity, intensity, grade, serious, mild, moderate, severe

3. AETERM (Adverse Event Term)
   - Type: String
   - Description: Preferred term for the adverse event (specific condition/symptom)
   - Example values: {', '.join(map(str, aeterm_values[:10]))}
   - Keywords that map to AETERM: condition, symptom, event, specific AE, disease, disorder
   - Use: To find subjects with specific adverse events like "Headache", "Nausea", etc.

4. AESOC (Adverse Event System Organ Class)
   - Type: String
   - Description: Body system affected (high-level categorization)
   - Example values: {', '.join(map(str, aesoc_values[:8]))}
   - Keywords that map to AESOC: body system, organ class, system, category
   - Use: To find AEs affecting specific body systems like "Cardiac", "Respiratory", etc.

5. ACTARM (Actual Treatment Arm)
   - Type: String
   - Description: Treatment group the subject was assigned to
   - Possible values: {', '.join(map(str, actarm_values))}
   - Keywords that map to ACTARM: treatment, arm, group, dose

6. TRTEMFL (Treatment Emergent Flag)
   - Type: String (Y/N)
   - Description: Flag indicating if AE occurred during treatment
   - Use: Filter for treatment-emergent AEs (TRTEMFL == 'Y')

7. AESTDTC (AE Start Date)
   - Type: Date string
   - Description: Start date of the adverse event

IMPORTANT RULES:
- For questions about "severity" or "intensity" → use AESEV column
- For questions about specific conditions/symptoms → use AETERM column
- For questions about body systems/organ classes → use AESOC column
- For questions about treatment groups → use ACTARM column
- Always filter to unique USUBJID when counting subjects
"""
        return schema_desc

    def parse_question(self, question: str) -> Dict:
        """
        Parse a natural language question into a structured query.

        Args:
            question: Natural language question from user

        Returns:
            Dictionary with target_column, filter_value, and other query params
        """
        prompt = ChatPromptTemplate.from_template(
            template="""You are an expert clinical data analyst. Given a natural language question
about adverse events in a clinical trial, extract the query parameters needed to filter the dataset.

{schema_description}

Question: {question}

Analyze the question and determine:
1. Which column should be filtered (target_column)
2. What value to search for (filter_value)
3. Whether to use exact match or contains (filter_type: "exact" or "contains")
4. Any additional filters needed (additional_filters as a dict, e.g., {{"TRTEMFL": "Y"}})

Return ONLY a valid JSON object with these four fields. Example:
{{"target_column": "AESEV", "filter_value": "MODERATE", "filter_type": "exact", "additional_filters": {{"TRTEMFL": "Y"}}}}

JSON response:""",
            partial_variables={
                "schema_description": self.schema_description
            }
        )

        # Create chain and invoke
        chain = prompt | self.llm | StrOutputParser()
        response = chain.invoke({"question": question})

        # Parse JSON response
        try:
            # Clean up response (remove markdown code blocks if present)
            response = response.strip()
            if response.startswith("```json"):
                response = response[7:]
            if response.startswith("```"):
                response = response[3:]
            if response.endswith("```"):
                response = response[:-3]
            response = response.strip()

            result = json.loads(response)

            # Ensure all required fields exist
            if 'target_column' not in result:
                result['target_column'] = 'AETERM'
            if 'filter_value' not in result:
                result['filter_value'] = ''
            if 'filter_type' not in result:
                result['filter_type'] = 'contains'
            if 'additional_filters' not in result:
                result['additional_filters'] = {}

            # Parse additional_filters if it's a string
            if isinstance(result.get('additional_filters'), str):
                try:
                    result['additional_filters'] = json.loads(result['additional_filters'])
                except:
                    result['additional_filters'] = {}

            return result

        except json.JSONDecodeError as e:
            print(f"Warning: Failed to parse LLM response as JSON: {e}")
            print(f"Response was: {response}")
            # Return default values
            return {
                "target_column": "AETERM",
                "filter_value": question,
                "filter_type": "contains",
                "additional_filters": {}
            }

    def execute_query(self, query_params: Dict) -> Dict:
        """
        Execute a query on the dataframe based on parsed parameters.

        Args:
            query_params: Dictionary with target_column, filter_value, etc.

        Returns:
            Dictionary with count of subjects and list of subject IDs
        """
        df_filtered = self.df.copy()

        # Apply main filter
        target_col = query_params['target_column']
        filter_val = query_params['filter_value']
        filter_type = query_params.get('filter_type', 'contains')

        if target_col not in df_filtered.columns:
            return {
                "error": f"Column {target_col} not found in dataset",
                "available_columns": list(df_filtered.columns)
            }

        # Apply filter based on type
        if filter_type == 'exact':
            df_filtered = df_filtered[
                df_filtered[target_col].str.upper() == filter_val.upper()
            ]
        else:  # contains
            df_filtered = df_filtered[
                df_filtered[target_col].str.contains(
                    filter_val, case=False, na=False
                )
            ]

        # Apply additional filters
        additional_filters = query_params.get('additional_filters', {})
        for col, val in additional_filters.items():
            if col in df_filtered.columns:
                df_filtered = df_filtered[df_filtered[col] == val]

        # Get unique subjects
        unique_subjects = df_filtered['USUBJID'].unique().tolist()

        return {
            "query_params": query_params,
            "subject_count": len(unique_subjects),
            "subject_ids": unique_subjects,
            "total_ae_records": len(df_filtered)
        }

    def ask(self, question: str) -> Dict:
        """
        Main interface: Ask a natural language question and get results.

        Args:
            question: Natural language question

        Returns:
            Dictionary with query results
        """
        print(f"\n{'='*60}")
        print(f"Question: {question}")
        print(f"{'='*60}")

        # Parse question using LLM
        print("\n[Step 1] Parsing question with LLM...")
        query_params = self.parse_question(question)
        print(f"  → Target Column: {query_params['target_column']}")
        print(f"  → Filter Value: {query_params['filter_value']}")
        print(f"  → Filter Type: {query_params.get('filter_type', 'contains')}")
        if query_params.get('additional_filters'):
            print(f"  → Additional Filters: {query_params['additional_filters']}")

        # Execute query
        print("\n[Step 2] Executing Pandas query...")
        results = self.execute_query(query_params)

        if "error" in results:
            print(f"  ✗ Error: {results['error']}")
            return results

        print(f"  ✓ Found {results['subject_count']} subjects")
        print(f"  ✓ Total AE records: {results['total_ae_records']}")

        # Display sample subject IDs
        print(f"\n[Step 3] Results:")
        print(f"  Subject Count: {results['subject_count']}")
        if results['subject_count'] > 0:
            print(f"  Sample Subject IDs (first 10):")
            for subj_id in results['subject_ids'][:10]:
                print(f"    - {subj_id}")
            if results['subject_count'] > 10:
                print(f"    ... and {results['subject_count'] - 10} more")

        print(f"\n{'='*60}\n")

        return results


def main():
    """
    Example usage of the ClinicalTrialDataAgent.
    """
    # This is just a demo - see test_agent.py for full test script
    print("Clinical Trial Data Agent - Demo")
    print("=" * 60)

    # Initialize agent
    agent = ClinicalTrialDataAgent("question_4_python/adae.csv")

    # Example query
    result = agent.ask("Show me subjects who had moderate severity adverse events")

    print(f"\nFinal result: {result['subject_count']} subjects found")


if __name__ == "__main__":
    main()
