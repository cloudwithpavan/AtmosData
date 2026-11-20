CREATE DATABASE IF NOT EXISTS atmosdata_ops;
USE atmosdata_ops;

CREATE TABLE IF NOT EXISTS city_master (
    city_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL UNIQUE,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ingestion_audit (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id VARCHAR(64) NOT NULL,
    city_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    gcs_object VARCHAR(1024),
    error_message TEXT,
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    INDEX idx_ingestion_run (run_id),
    INDEX idx_ingestion_city_time (city_name, started_at)
);

CREATE TABLE IF NOT EXISTS pipeline_audit (
    pipeline_audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    dag_id VARCHAR(250) NOT NULL,
    run_id VARCHAR(250) NOT NULL,
    status VARCHAR(20) NOT NULL,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    error_message TEXT,
    UNIQUE KEY uq_pipeline_run (dag_id, run_id)
);

CREATE TABLE IF NOT EXISTS error_log (
    error_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    component VARCHAR(100) NOT NULL,
    error_type VARCHAR(250),
    error_message TEXT NOT NULL,
    logged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO city_master (city_name, latitude, longitude) VALUES
('Hyderabad', 17.385000, 78.486700),
('Bengaluru', 12.971600, 77.594600),
('Mumbai', 19.076000, 72.877700),
('Delhi', 28.613900, 77.209000),
('Chennai', 13.082700, 80.270700)
ON DUPLICATE KEY UPDATE
latitude = VALUES(latitude), longitude = VALUES(longitude);
