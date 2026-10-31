----------------------------------------------------------------------------------
-- The following query will create a database named hospital.
-- Additionally, it will populate it with following tables:
-- Users, roles, user_roles, employees, rooms, equipment, patients, appointments, 
-- diagnoses, treatments, prescriptions, prescription_cs_log, invoice, payments
----------------------------------------------------------------------------------
CREATE DATABASE hospital;
GO

USE hospital;
GO

------------------------
-- Users table creation
------------------------
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    username VARCHAR(20) NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(254) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    created_at DATETIME2
);

------------------------
-- Roles table creation
------------------------
CREATE TABLE roles (
    role_id INT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL,
    description VARCHAR(MAX)
);

-----------------------------
-- User_Roles table creation
-----------------------------
CREATE TABLE user_roles (
    user_role_id INT PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    role_id INT REFERENCES roles(role_id)
);

----------------------------
-- Employees table creation
----------------------------
CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    staff_position VARCHAR(100) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(254) NOT NULL
);

------------------------
-- Rooms table creation
------------------------
CREATE TABLE rooms (
    room_id INT PRIMARY KEY,
    room_number VARCHAR(10) NOT NULL,
    room_side VARCHAR(2) NOT NULL,
    room_status VARCHAR(50) NOT NULL,
    special_notes TEXT
);

----------------------------
-- Equipment table creation
----------------------------
CREATE TABLE equipment (
    equipment_id INT PRIMARY KEY,
    equipment_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL
);

---------------------------
-- Patients table creation
----------------------------
CREATE TABLE patients (
    patient_id INT PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    pcp_employee_id INT REFERENCES employees(employee_id),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(20) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(254) NOT NULL,
    address VARCHAR(MAX)
);

-------------------------------
-- Appointments table creation
-------------------------------
CREATE TABLE appointments (
    appointment_id INT PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    employee_id INT REFERENCES employees(employee_id),
    room_id INT REFERENCES rooms(room_id),
    equipment_id INT REFERENCES equipment(equipment_id),
    appointment_date DATETIME2,
    purpose TEXT,
    status VARCHAR(50) NOT NULL
);

----------------------------
-- Diagnoses table creation
----------------------------
CREATE TABLE diagnoses (
    diagnosis_id INT PRIMARY KEY,
    appointment_id INT REFERENCES appointments(appointment_id),
    patient_id INT REFERENCES patients(patient_id),
    description TEXT NOT NULL,
    diagnosis_date DATE NOT NULL
);

-----------------------------
-- Treatments table creation
-----------------------------
CREATE TABLE treatments (
    treatment_id INT PRIMARY KEY,
    appointment_id INT REFERENCES appointments(appointment_id),
    patient_id INT REFERENCES patients(patient_id),
    description TEXT,
    cost DECIMAL(10,2) NOT NULL
);

--------------------------------
-- Prescriptions table creation
--------------------------------
CREATE TABLE prescriptions (
    prescription_id INT PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    employee_id INT REFERENCES employees(employee_id),
    drug_name VARCHAR(125) NOT NULL,
    dosage VARCHAR(100) NOT NULL,
    is_controlled_substance BIT,
    status VARCHAR(50) NOT NULL,
    created_at DATETIME2
);

-----------------------------------------------------
-- Prescriptions controlled substance table creation
-----------------------------------------------------
CREATE TABLE prescription_cs_log (
    log_id INT PRIMARY KEY,
    prescription_id INT REFERENCES prescriptions(prescription_id),
    user_id INT REFERENCES users(user_id),
    patient_id INT REFERENCES patients(patient_id),
    timestamp DATETIME2,
    description TEXT
);

--------------------------
-- Invoice table creation
--------------------------
CREATE TABLE invoice (
    invoice_id INT PRIMARY KEY,
    patient_id INT REFERENCES patients(patient_id),
    appointment_id INT REFERENCES appointments(appointment_id),
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    invoice_date DATE NOT NULL
);

---------------------------
-- Payments table creation
---------------------------
CREATE TABLE payments (
    payment_id INT PRIMARY KEY,
    invoice_id INT REFERENCES invoice(invoice_id),
    patient_id INT REFERENCES patients(patient_id),
    amount_paid DECIMAL(10,2) NOT NULL,
    payment_date DATETIME2 NOT NULL,
    payment_method VARCHAR(50) NOT NULL
);
GO

-- TRIGGER: Log Controlled Substance Prescriptions
-- Runs automatically after any Insert, Update, or Delete on prescriptions
CREATE TRIGGER trg_prescription_cs_audit
ON prescriptions
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Keeps the server from sending extra background alerts
    SET NOCOUNT ON;

    -----------------------------------------------------------------
    --LOG NEW PRESCRIPTIONS (INSERT)
    -----------------------------------------------------------------
    INSERT INTO prescription_cs_log (log_id, prescription_id, user_id, patient_id, timestamp, description)
    SELECT 
        (SELECT ISNULL(MAX(log_id), 0) FROM prescription_cs_log) + ROW_NUMBER() OVER (ORDER BY inserted_table.prescription_id),
        inserted_table.prescription_id,
        employees.user_id,        
        inserted_table.patient_id,
        SYSDATETIME(),            
        'Created controlled substance prescription for: ' + inserted_table.drug_name
    FROM inserted AS inserted_table
    JOIN employees ON inserted_table.employee_id = employees.employee_id
    WHERE inserted_table.is_controlled_substance = 1; -- Only fires if it is a controlled substance


    -----------------------------------------------------------------
    --LOG MODIFIED PRESCRIPTIONS (UPDATE)
    -----------------------------------------------------------------
    INSERT INTO prescription_cs_log (log_id, prescription_id, user_id, patient_id, timestamp, description)
    SELECT 
        (SELECT ISNULL(MAX(log_id), 0) FROM prescription_cs_log) + ROW_NUMBER() OVER (ORDER BY inserted_table.prescription_id),
        inserted_table.prescription_id,
        employees.user_id,
        inserted_table.patient_id,
        SYSDATETIME(),
        'Updated controlled substance prescription for: ' + inserted_table.drug_name
    FROM inserted AS inserted_table
    JOIN employees ON inserted_table.employee_id = employees.employee_id
    WHERE inserted_table.is_controlled_substance = 1;


    -----------------------------------------------------------------
    --LOG DELETED PRESCRIPTIONS (DELETE)
    -----------------------------------------------------------------
    INSERT INTO prescription_cs_log (log_id, prescription_id, user_id, patient_id, timestamp, description)
    SELECT 
        (SELECT ISNULL(MAX(log_id), 0) FROM prescription_cs_log) + ROW_NUMBER() OVER (ORDER BY deleted_table.prescription_id),
        deleted_table.prescription_id,
        employees.user_id,
        deleted_table.patient_id,
        SYSDATETIME(),
        'Deleted controlled substance prescription for: ' + deleted_table.drug_name
    FROM deleted AS deleted_table
    JOIN employees ON deleted_table.employee_id = employees.employee_id
    WHERE deleted_table.is_controlled_substance = 1 
      AND NOT EXISTS (SELECT 1 FROM inserted WHERE inserted.prescription_id = deleted_table.prescription_id);
END;
GO