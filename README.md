# Medallion Architecture Overview

## Data Sources

**MB (MSSQL):** Business and application related data.

**Travea (Postgres):** Financial related data.

---

## Bronze Layer (Raw Data)

This layer stores data in its raw, unaltered format as ingested from the source systems.  
Storing raw data ensures **data provenance** and allows the pipeline to **reprocess data if required**.

---

## Silver Layer (Transformed Data)

In this layer, data transformations are applied to the raw data from the Bronze layer.

Transformations include:

- Data cleaning  
- Data formatting  
- Deduplication  
- Data enrichment  

The processed data is stored in a **structured format**, making it easier and more efficient for analytical processing.

---

## Gold Layer (Curated Data)

The Gold layer contains **refined and curated datasets** that are ready for analytics and reporting.

Key operations include:

- Aggregations
- Summary table creation
- Business metric generation

This layer is optimized for **fast query performance and analytical workloads**.

---

## Querying and Reporting

Data from the **Gold layer** is accessed using SQL queries.

This allows:

- Data analysts
- Business users

to build **dashboards and reports** that provide insights into the travel agency's business performance.

---

## Event Notification

At each stage of the data pipeline, **event notifications are sent to a dedicated Microsoft Teams channel**.

This enables:

- Real-time monitoring of pipeline execution
- Quick identification of failures
- Faster issue resolution

---

# Benefits of this Medallion Architecture

### Data Integrity
Ensures high data quality through validation and transformation processes.

### Scalability
Supports increasing data volumes and growing analytical needs.

### Performance
Optimizes data access for faster reporting and analytics queries.

### Maintainability
Provides a clear separation of concerns between raw, transformed, and curated data layers.

### Monitoring
Real-time event notifications help in monitoring pipeline health and troubleshooting issues quickly.

---

This Medallion Architecture provides a **robust and scalable framework** for managing the travel agency's data platform, ensuring **data accuracy, reliability, and actionable insights for business decision-making**.
