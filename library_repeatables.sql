
/*
Repeatable DDL statements, i.e. anything that's not a table
*/

use library;

-- demo: how to determine loan status
CREATE VIEW loan_overview AS
SELECT p.book_id,
       p.copy_number,
       p.customer_id,
       r.reserved_at,
       r.reservation_canceled_at,
       l.picked_up,
       l.returned,
       l.due_date,
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
           ) AS status_code
FROM loan_process AS p
         LEFT JOIN reservation AS r ON p.loan_id = r.loan_id
         LEFT JOIN loan AS l ON p.loan_id = l.loan_id;


