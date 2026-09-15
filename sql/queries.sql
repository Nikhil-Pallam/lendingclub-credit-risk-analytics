-- ============================================================================
-- LendingClub Credit Risk Analytics — SQL Analysis
-- ============================================================================
-- Author: Nikhil Pallam
-- Purpose: Re-derive key credit risk findings using SQL, demonstrating core
--          and intermediate SQL competency (aggregation, filtering, window
--          functions, and multi-table comparison) against the same dataset
--          analyzed in depth in Python.
--
-- Data source: accepted_final.csv / rejected_final.csv — the cleaned,
--              feature-engineered outputs of the Python analysis phase
--              (see /notebooks/LendingClub_Credit_Risk_Analysis.ipynb).
--
-- Scope note: accepted_loans contains only RESOLVED loans (Fully Paid /
--             Charged Off), matching the scope decided during the Python
--             phase. This means accepted_loans is NOT the full accepted
--             population — see the note on Query 5 candidates below for
--             why this matters.
-- ============================================================================


-- ============================================================================
-- SETUP: Database, tables, and data load
-- ============================================================================

-- Enable local file loading (required on both server and client side —
-- in MySQL Workbench, also add OPT_LOCAL_INFILE=1 under
-- Connection > Advanced > Others)
SET GLOBAL local_infile = 1;

DROP DATABASE IF EXISTS lendingclub;
CREATE DATABASE lendingclub;
USE lendingclub;

CREATE TABLE accepted_loans (
    id BIGINT,
    loan_status VARCHAR(20),
    issue_year INT,
    loan_amnt DECIMAL(10,2),
    term VARCHAR(20),
    int_rate DECIMAL(5,2),
    installment DECIMAL(10,2),
    grade CHAR(1),
    sub_grade VARCHAR(3),
    purpose VARCHAR(30),
    emp_length VARCHAR(15),
    home_ownership VARCHAR(15),
    annual_inc DECIMAL(12,2),
    verification_status VARCHAR(20),
    dti DECIMAL(6,2),
    addr_state CHAR(2),
    fico_range_low INT,
    fico_range_high INT,
    earliest_cr_line VARCHAR(10),
    open_acc INT,
    pub_rec INT,
    revol_bal DECIMAL(12,2),
    revol_util DECIMAL(6,2),
    total_acc INT,
    mort_acc DECIMAL(5,1),
    pub_rec_bankruptcies DECIMAL(5,1),
    delinq_2yrs INT,
    is_charged_off TINYINT,
    dti_band VARCHAR(10),
    fico_score DECIMAL(6,1),
    fico_band VARCHAR(10),
    earliest_cr_line_parsed VARCHAR(30),
    earliest_cr_year INT,
    credit_history_years INT,
    credit_history_band VARCHAR(10),
    grade_pts INT,
    fico_pts INT,
    dti_pts INT,
    risk_score INT,
    risk_tier VARCHAR(15)
);

CREATE TABLE rejected_loans (
    amount_requested DECIMAL(10,2),
    application_date DATE,
    loan_title VARCHAR(100),
    risk_score DECIMAL(6,1) NULL,
    dti_raw VARCHAR(10),
    zip_code VARCHAR(10),
    state CHAR(2),
    employment_length VARCHAR(15),
    policy_code DECIMAL(3,1),
    app_year INT,
    dti_clean DECIMAL(6,2)
);

-- Update file paths below to match your local file locations
LOAD DATA LOCAL INFILE '/path/to/accepted_final.csv'
INTO TABLE accepted_loans
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- risk_score is loaded via a user variable + NULLIF so that empty values
-- become true SQL NULL rather than being coerced to 0 (MySQL's default
-- behavior for empty strings in numeric columns would otherwise silently
-- corrupt any AVG()/analysis on this column)
LOAD DATA LOCAL INFILE '/path/to/rejected_final.csv'
INTO TABLE rejected_loans
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(amount_requested, application_date, loan_title, @risk_score, dti_raw, zip_code, state, employment_length, policy_code, app_year, dti_clean)
SET risk_score = NULLIF(@risk_score, '');

-- Sanity check: expect 1,115,803 and 24,191,792 respectively
SELECT COUNT(*) AS accepted_count FROM accepted_loans;
SELECT COUNT(*) AS rejected_count FROM rejected_loans;


-- ============================================================================
-- QUERY 1: Charge-Off Rate by Grade
-- ============================================================================
-- Business question: Is LendingClub's own risk grading well-calibrated?
-- Finding: Charge-off rate climbs steadily and near-linearly from Grade A
-- (6.10%) to Grade G (52.55%) — confirming the grading system is genuinely
-- predictive of default risk.

SELECT 
    grade,
    COUNT(*) AS total_loans,
    ROUND(AVG(is_charged_off) * 100, 2) AS charge_off_rate_pct
FROM accepted_loans
GROUP BY grade
ORDER BY grade;


-- ============================================================================
-- QUERY 2: Charge-Off Rate by State (Top 10 Riskiest)
-- ============================================================================
-- Business question: Which geographies carry the highest credit risk?
-- The HAVING clause filters out states with too few loans to produce a
-- statistically meaningful rate (minimum 100 loans).
-- Finding: Riskiest states cluster in the South (MS, AR, AL, LA, OK).
-- Notable anomaly: NY (89,676 loans — a large, reliable sample) shows an
-- elevated 23.30% rate despite a grade/purpose mix nearly identical to the
-- national average (see Python analysis, Phase 4.4) — unexplained by this
-- dataset alone.

SELECT 
    addr_state,
    COUNT(*) AS total_loans,
    ROUND(AVG(is_charged_off) * 100, 2) AS charge_off_rate_pct
FROM accepted_loans
GROUP BY addr_state
HAVING COUNT(*) >= 100
ORDER BY charge_off_rate_pct DESC
LIMIT 10;


-- ============================================================================
-- QUERY 3: Charge-Off Rate by Vintage (Issue Year)
-- ============================================================================
-- Business question: Has loan quality/underwriting shifted over time?
-- Finding: Charge-off rate rose from 18.45% (2014) to ~23% (2016-2017).
-- Caveat: The apparent drop in 2018 (15.74%) is a right-censoring artifact,
-- NOT real risk improvement — most 2018 loans haven't had time to resolve
-- given this dataset's snapshot cutoff (see Python analysis, Phase 4.3).
-- 2018 should be treated as an immature, unreliable data point.

SELECT 
    issue_year,
    COUNT(*) AS total_loans,
    ROUND(AVG(is_charged_off) * 100, 2) AS charge_off_rate_pct
FROM accepted_loans
GROUP BY issue_year
ORDER BY issue_year;


-- ============================================================================
-- QUERY 4: State Risk Ranking (Window Function)
-- ============================================================================
-- Demonstrates RANK() OVER (...), a window function that assigns a rank
-- without collapsing rows the way GROUP BY alone would — useful for
-- "top N with rank shown" style business requests.

SELECT 
    addr_state,
    total_loans,
    charge_off_rate_pct,
    RANK() OVER (ORDER BY charge_off_rate_pct DESC) AS risk_rank
FROM (
    SELECT 
        addr_state,
        COUNT(*) AS total_loans,
        ROUND(AVG(is_charged_off) * 100, 2) AS charge_off_rate_pct
    FROM accepted_loans
    GROUP BY addr_state
    HAVING COUNT(*) >= 100
) AS state_summary
ORDER BY risk_rank
LIMIT 10;


-- ============================================================================
-- QUERY 5: Accepted vs. Rejected — Average DTI Comparison
-- ============================================================================
-- Business question: Does debt-to-income ratio meaningfully separate
-- accepted from rejected applicants?
-- Finding: Rejected applicants average 26.94% DTI vs. accepted's 18.55% —
-- a real ~8-point gap, though with substantial overlap between the two
-- distributions (see Python analysis, Phase 7.2) — DTI is a real factor
-- in rejection, but not a hard cutoff.
--
-- Uses UNION ALL to combine results from two tables with no shared key —
-- a useful pattern for side-by-side cross-table comparisons.
--
-- Note: An overall accepted-vs-rejected APPROVAL RATE was deliberately
-- excluded from this SQL layer. accepted_loans here contains only
-- RESOLVED loans (1,115,803), not the full accepted population used in
-- the Python analysis (2,029,952, all statuses) — computing an approval
-- rate from these two tables directly would understate the true rate
-- (the correct 7.21% approval rate is reported in the Python analysis,
-- which had access to the full unfiltered accepted-loan count).

SELECT 
    'Accepted' AS loan_group,
    COUNT(*) AS total_count,
    ROUND(AVG(dti), 2) AS avg_dti
FROM accepted_loans

UNION ALL

SELECT 
    'Rejected' AS loan_group,
    COUNT(*) AS total_count,
    ROUND(AVG(dti_clean), 2) AS avg_dti
FROM rejected_loans;
