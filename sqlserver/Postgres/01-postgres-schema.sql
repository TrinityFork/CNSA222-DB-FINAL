-----------------------------------------------------------------------------------------
-- The following query is to be ran after the creation of your hospital database. 
-- If you have not done that yet, do that now with the following commented out query.
-- CREATE DATABASE hospital;
-- Once your database is created, run this query.
-----------------------------------------------------------------------------------------
-- The following tables will be created:
-- Users, roles, user_roles, employees, rooms, equipment, patients, appointments, 
-- diagnoses, treatments, prescriptions, prescription_cs_log, invoice, payments
----------------------------------------------------------------------------------

------------------------
-- Users table creation
------------------------
CREATE TABLE users (
user_id INT PRIMARY KEY,
username VARCHAR(20) NOT NULL,
password VARCHAR(255) NOT NULL,
email VARCHAR(254) NOT NULL,
phone VARCHAR(20) NOT NULL,
created_at TIMESTAMP
);

------------------------
-- Roles table creation
------------------------
CREATE TABLE roles (
role_id INT PRIMARY KEY,
role_name VARCHAR(50) NOT NULL,
description VARCHAR
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
staff_position VARCHAR NOT NULL,
specialization VARCHAR NOT NULL,
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
room_status VARCHAR NOT NULL,
special_notes TEXT
);

----------------------------
-- Equipment table creation
----------------------------
CREATE TABLE equipment (
equipment_id INT PRIMARY KEY,
equipment_name VARCHAR NOT NULL,
status VARCHAR NOT NULL
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
gender VARCHAR NOT NULL,
phone VARCHAR(20) NOT NULL,
email VARCHAR(254) NOT NULL,
address VARCHAR
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
appointment_date TIMESTAMP,
purpose TEXT,
status VARCHAR NOT NULL
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
cost DECIMAL NOT NULL
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
is_controlled_substance BOOLEAN,
status VARCHAR NOT NULL,
created_at TIMESTAMP
);

-----------------------------------------------------
-- Prescriptions controlled substance table creation
-----------------------------------------------------
CREATE TABLE prescription_cs_log (
log_id INT PRIMARY KEY,
prescription_id INT REFERENCES prescriptions(prescription_id),
user_id INT REFERENCES users(user_id),
patient_id INT REFERENCES patients(patient_id),
timestamp TIMESTAMP,
description TEXT
);

--------------------------
-- Invoice table creation
--------------------------
CREATE TABLE invoice (
invoice_id INT PRIMARY KEY,
patient_id INT REFERENCES patients(patient_id),
appointment_id INT REFERENCES appointments(appointment_id),
total_amount DECIMAL NOT NULL,
status VARCHAR NOT NULL,
invoice_date DATE NOT NULL
);

---------------------------
-- Payments table creation
---------------------------
CREATE TABLE payments (
payment_id INT PRIMARY KEY,
invoice_id INT REFERENCES invoice(invoice_id),
patient_id INT REFERENCES patients(patient_id),
amount_paid DECIMAL NOT NULL,
payment_date TIMESTAMP NOT NULL,
payment_method VARCHAR(50) NOT NULL
);

-- TRIGGER: Log Controlled Substance Prescriptions
-- Runs automatically after any Insert, Update, or Delete on prescriptions
CREATE OR REPLACE FUNCTION fn_prescription_cs_audit()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id INT;
    v_next_log_id INT;
BEGIN
    -- Keeps the server from sending extra background alerts

    -----------------------------------------------------------------
    --LOG NEW PRESCRIPTIONS (INSERT)
    -----------------------------------------------------------------
    IF (TG_OP = 'INSERT') THEN
        IF NEW.is_controlled_substance = TRUE THEN
            -- Grabs the user ID linked to the employee/doctor
            SELECT user_id INTO v_user_id FROM employees WHERE employee_id = NEW.employee_id;
            
            -- Generates a unique log_id since your table doesn't use auto-increment
            SELECT COALESCE(MAX(log_id), 0) + 1 INTO v_next_log_id FROM prescription_cs_log;

            INSERT INTO prescription_cs_log (log_id, prescription_id, user_id, patient_id, timestamp, description)
            VALUES (
                v_next_log_id,
                NEW.prescription_id,
                v_user_id,
                NEW.patient_id,
                CURRENT_TIMESTAMP, -- Current timestamp of the action
                'Created controlled substance prescription for: ' || NEW.drug_name
            );
        END IF;
        RETURN NEW;

    -----------------------------------------------------------------
    --LOG MODIFIED PRESCRIPTIONS (UPDATE)
    -----------------------------------------------------------------
    ELSIF (TG_OP = 'UPDATE') THEN
        IF NEW.is_controlled_substance = TRUE THEN
            SELECT user_id INTO v_user_id FROM employees WHERE employee_id = NEW.employee_id;
            SELECT COALESCE(MAX(log_id), 0) + 1 INTO v_next_log_id FROM prescription_cs_log;

            INSERT INTO prescription_cs_log (log_id, prescription_id, user_id, patient_id, timestamp, description)
            VALUES (
                v_next_log_id,
                NEW.prescription_id,
                v_user_id,
                NEW.patient_id,
                CURRENT_TIMESTAMP,
                'Updated controlled substance prescription for: ' || NEW.drug_name
            );
        END IF;
        RETURN NEW;

    -----------------------------------------------------------------
    --LOG DELETED PRESCRIPTIONS (DELETE)
    -----------------------------------------------------------------
    ELSIF (TG_OP = 'DELETE') THEN
        IF OLD.is_controlled_substance = TRUE THEN
            SELECT user_id INTO v_user_id FROM employees WHERE employee_id = OLD.employee_id;
            SELECT COALESCE(MAX(log_id), 0) + 1 INTO v_next_log_id FROM prescription_cs_log;

            INSERT INTO prescription_cs_log (log_id, prescription_id, user_id, patient_id, timestamp, description)
            VALUES (
                v_next_log_id,
                OLD.prescription_id,
                v_user_id,
                OLD.patient_id,
                CURRENT_TIMESTAMP,
                'Deleted controlled substance prescription for: ' || OLD.drug_name
            );
        END IF;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------------
-- TRIGGER ATTACHMENT
-- Links the function to the prescriptions table for row-by-row tracking
-------------------------------------------------------------------------
CREATE TRIGGER trg_prescription_cs_audit
AFTER INSERT OR UPDATE OR DELETE ON prescriptions
FOR EACH ROW
EXECUTE FUNCTION fn_prescription_cs_audit();