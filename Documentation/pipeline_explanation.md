# Pipeline Explanation

This document explains the implementation of the **ETL data pipeline** used to process data from the **Silver Layer to the Gold Layer** within the Medallion Architecture.

The pipeline is implemented using **Python and SQL**, and is designed to support scalable, configurable, and auditable data processing.

---

# Pipeline Overview

The ETL pipeline performs the following operations:

1. Read global ETL batch parameters
2. Initialize audit logging
3. Fetch ETL configuration metadata
4. Process tables based on execution order
5. Perform FULL or DELTA data loads
6. Load transformed data into the Gold layer
7. Record ETL audit information
8. Generate ETL execution summary

---

# Data Flow
Source Systems
↓
Bronze Layer (Raw Data)
↓
Silver Layer (Transformed Data)
↓
Python ETL Processing
↓
Gold Layer (Analytics Tables)
↓
Reporting & Dashboards

---

# ETL Execution Process

## Step 1: Read Global Batch Parameters

The pipeline begins by reading the **ETL batch execution details** from the audit control table.

This includes:

- Batch Run ID
- Run Start Time
- Run End Time
- Load Type (FULL or DELTA)
- Run Frequency

These parameters define how the ETL process should execute.

---

## Step 2: Create Master ETL Audit Record

Once the batch parameters are retrieved, a **master ETL audit record** is created.

This audit record tracks:

- ETL run ID
- start time
- status
- number of processed tables
- error messages (if any)

This ensures full traceability of ETL runs.

---

## Step 3: Read ETL Configuration Table

The pipeline reads a **configuration table** which defines the metadata for each table to be processed.

Configuration parameters include:

- Source system
- Target table name
- Target schema
- SQL transformation template
- Execution order
- Ingestion strategy
- Load keys
- Incremental extraction columns

This makes the pipeline **metadata-driven**, allowing new tables to be added without modifying the code.

---

# Table Processing Logic

Tables are processed sequentially based on the **execution order** defined in the configuration table.

For each table:

1. An ETL audit record is created.
2. SQL queries are dynamically generated.
3. Data is extracted from the **Silver layer**.
4. Data is loaded into the **Gold layer**.

---

# Load Types

The pipeline supports two types of loads.

## FULL Load

A FULL load performs the following steps:

1. Truncate the target table in the Gold layer.
2. Extract all records from the Silver layer.
3. Load data in batches.
4. Insert all data into the target table.

This is typically used for:

- Initial loads
- Full data refresh

---

## DELTA Load

A DELTA load processes only **incremental changes**.

Steps include:

1. Retrieve the last processed timestamp.
2. Generate a WHERE clause for incremental extraction.
3. Extract only new or updated records.
4. Delete overlapping records if required.
5. Insert updated data into the Gold layer.

This significantly improves **pipeline performance** for large datasets.

---

# Batch Processing

To handle large data volumes efficiently, the pipeline processes data in **batches**.

Typical batch flow:

1. Execute SQL query with LIMIT and OFFSET.
2. Load chunk of records into memory.
3. Insert batch into the Gold table.
4. Repeat until all data is processed.

Benefits:

- Memory efficient
- Scalable for large tables
- Prevents long-running transactions

---

# Ingestion Strategies

The pipeline supports multiple ingestion strategies.

## TRUNCATE_INSERT

- Target table is truncated before loading.
- All records are reloaded.

Used for:

- FULL loads
- Dimension tables

---

## APPEND

- Existing data is preserved.
- Only new or updated records are inserted.

Used for:

- Incremental loads
- Fact tables

---

# Audit Logging

The pipeline maintains detailed **ETL audit logs**.

Audit information captured:

- ETL run ID
- source table
- target table
- number of records extracted
- number of records loaded
- processing status
- error messages

This allows easy monitoring and troubleshooting.

---

# Error Handling

The pipeline includes robust error handling.

If an error occurs:

- The error is logged
- Table status is marked as failed
- Processing continues for other tables
- The final summary reports failed tables

This ensures pipeline resilience.

---

# ETL Execution Summary

At the end of the pipeline execution, a summary is generated containing:

- Total tables processed
- Successful tables
- Failed tables
- Total records fetched
- Total records processed
- ETL duration

This summary provides quick visibility into pipeline performance.

---

# Key Features

- Metadata-driven ETL framework
- Support for FULL and DELTA loads
- Batch-based processing
- Automated audit logging
- Configurable ingestion strategies
- Robust error handling
- Scalable data processing

---

# Benefits of the Pipeline

### Scalability
Handles large datasets through batch processing.

### Flexibility
New tables can be added using configuration metadata.

### Reliability
Audit logs and error handling ensure reliable ETL execution.

### Performance
Incremental loads reduce unnecessary data processing.

---

This pipeline forms the core of the **Gold layer data processing**, enabling reliable and scalable analytics for the travel agency data platform.