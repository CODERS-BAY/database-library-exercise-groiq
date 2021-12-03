/*
Repeatable DDL statements, i.e. anything that's not a table
*/

USE library;

-- demo: how to determine loan status (one line per loan, *not* per book copy)
DROP VIEW IF EXISTS loan_overview;
CREATE VIEW loan_overview AS
SELECT p.loan_id,
       (
           CASE
               WHEN returned IS NOT NULL THEN 'returned'
               WHEN picked_up IS NOT NULL THEN
                   CASE
                       WHEN due_date < CURRENT_DATE THEN 'overdue'
                       ELSE 'on loan'
                       END
               WHEN reservation_canceled_at IS NOT NULL THEN 'canceled reservation'
               WHEN reserved_at IS NOT NULL THEN 'reserved'
               ELSE 'data error'
               END
           ) AS loan_status,
       (
                   (returned IS NOT NULL) * 1 +
                   (picked_up IS NOT NULL) * 2 +
                   (due_date IS NOT NULL AND due_date < CURRENT_DATE) * 4 +
                   (reservation_canceled_at IS NOT NULL) * 8 +
                   (reserved_at IS NOT NULL) * 16
           ) AS status_code,
       p.book_id,
       p.copy_number,
       p.customer_id,
       r.reserved_at,
       r.reservation_canceled_at,
       l.picked_up,
       l.returned,
       l.due_date
FROM loan_process AS p
         LEFT JOIN reservation AS r ON p.loan_id = r.loan_id
         LEFT JOIN loan AS l ON p.loan_id = l.loan_id;

DELIMITER GO

DROP TRIGGER IF EXISTS loan_makes_copy_unavailable GO
CREATE TRIGGER loan_makes_copy_unavailable
    BEFORE INSERT
    ON loan_process
    FOR EACH ROW
BEGIN
    DECLARE old_is_available BOOLEAN DEFAULT NULL;

    SELECT is_available
    INTO old_is_available
    FROM book_copy
    WHERE book_id = new.book_id
      AND book_copy.copy_number = new.copy_number;

    IF NOT old_is_available = 1 THEN
        SET @message = CONCAT(
                'Error: book #', new.book_id, ', copy #', new.copy_number,
                ' was either not found or is not available.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message;
    END IF;

    UPDATE book_copy
    SET is_available = 0
    WHERE book_id = new.book_id
      AND copy_number = new.copy_number;
END;
GO

DROP TRIGGER IF EXISTS canceling_reservation_makes_copy_available;
GO
CREATE TRIGGER canceling_reservation_makes_copy_available
    BEFORE UPDATE
    ON reservation
    FOR EACH ROW
BEGIN
    DECLARE old_is_available BOOLEAN DEFAULT NULL;
    DECLARE book_id_p INT;
    DECLARE copy_count_p INT;

    IF old.reservation_canceled_at IS NOT NULL OR new.reservation_canceled_at IS NULL THEN
        SET @message = CONCAT('error: updating reservation for loan #', old.loan_id,
                              ': the only valid update is to set cancellation timestamp when previously unset, but old timestamp is ',
                              IFNULL(old.reservation_canceled_at, 'NULL'), ' and new timestamp is ',
                              IFNULL(new.reservation_canceled_at, 'NULL'));
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message;
    END IF;

    SELECT c.is_available, c.book_id, c.copy_number
    INTO old_is_available, book_id_p, copy_count_p
    FROM book_copy c
             JOIN loan_process l ON c.book_id = l.book_id AND c.copy_number = l.copy_number
    WHERE l.loan_id = old.loan_id;

    IF NOT old_is_available = 0 THEN
        SET @message = CONCAT(
                'Error: reservation #', old.loan_id, ': book #', book_id_p, ', copy #', copy_count_p,
                ' was either not found or was marked as available.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message;
    END IF;

    UPDATE book_copy SET is_available = 1 WHERE book_id = book_id_p AND copy_number = copy_count_p;
END;
GO

DROP TRIGGER IF EXISTS return_makes_copy_available GO
CREATE TRIGGER return_makes_copy_available
    BEFORE UPDATE
    ON loan
    FOR EACH ROW
returning_copy:
BEGIN
    DECLARE old_is_available BOOLEAN DEFAULT NULL;
    DECLARE book_id_p INT;
    DECLARE copy_count_p INT;

    -- I assume that changing due date is valid,
    -- so the logic here is not the same as with canceling reservation.
    IF old.returned IS NOT NULL OR new.returned IS NULL THEN
        LEAVE returning_copy;
    END IF;

    SELECT c.is_available, c.book_id, c.copy_number
    INTO old_is_available, book_id_p, copy_count_p
    FROM book_copy c
             JOIN loan_process l ON c.book_id = l.book_id AND c.copy_number = l.copy_number
    WHERE l.loan_id = old.loan_id;

    IF NOT old_is_available = 0 THEN
        SET @message = CONCAT(
                'Error: returning loan #', old.loan_id, ': book #', book_id_p, ', copy #', copy_count_p,
                ' was either not found or was marked as available.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @message;
    END IF;

    UPDATE book_copy SET is_available = 1 WHERE book_id = book_id_p AND copy_number = copy_count_p;
END;
GO

DROP PROCEDURE IF EXISTS check_or_create_counter_event;
GO
CREATE PROCEDURE check_or_create_counter_event(INOUT event_id_p INT, employee_id_p INT)
    MODIFIES SQL DATA
    COMMENT 'if event_id is null, inserts a counter event and fills in the id'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    IF event_id_p IS NULL
    THEN
        INSERT INTO counter_event (employee_id) VALUES (employee_id_p);
        SET event_id_p = LAST_INSERT_ID();
    END IF;
END;
GO

DROP PROCEDURE IF EXISTS reserve_copy;
GO
CREATE PROCEDURE reserve_copy(book_id_p INT, copy_number_p INT, customer_id_p INT)
    MODIFIES SQL DATA
    COMMENT 'reserves a book for loaning'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    START TRANSACTION;

    INSERT INTO loan_process (book_id, copy_number, customer_id) VALUES (book_id_p, copy_number_p, customer_id_p);
    INSERT INTO reservation (loan_id) VALUES (LAST_INSERT_ID());
    COMMIT;
END;
GO

DROP PROCEDURE IF EXISTS loan_copy GO
CREATE PROCEDURE loan_copy(loan_id_p INT, counter_event_p INT, employee_id_p INT, due_date_p DATE)
    MODIFIES SQL DATA
    COMMENT 'creates a loan for a copy with an existing loan_process'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    CALL check_or_create_counter_event(counter_event_p, employee_id_p);

    INSERT INTO loan (loan_id, picked_up, due_date) VALUES (loan_id_p, counter_event_p, due_date_p);
END
GO

DROP PROCEDURE IF EXISTS loan_unreserved_copy GO
CREATE PROCEDURE loan_unreserved_copy(book_id_p INT, copy_number_p INT, customer_id_p INT, counter_event_p INT,
                                      employee_id_p INT, due_date_p DATE)
    MODIFIES SQL DATA
    COMMENT 'creates a loan for a book that has no reservation (thus no loan_process).'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    START TRANSACTION;

    INSERT INTO loan_process (book_id, copy_number, customer_id) VALUES (book_id_p, copy_number_p, customer_id_p);
    CALL loan_copy(LAST_INSERT_ID(), counter_event_p, employee_id_p, due_date_p);
    COMMIT;
END
GO


DROP PROCEDURE IF EXISTS return_copy;
CREATE PROCEDURE return_copy(loan_id_p INT, counter_event_p INT, employee_id_p INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    START TRANSACTION ;

    CALL check_or_create_counter_event(counter_event_p, employee_id_p);
    UPDATE loan SET returned = counter_event_p WHERE loan_id = loan_id_p;
    COMMIT;
END
GO

DELIMITER ;

