USE library;

START TRANSACTION;

SET foreign_key_checks = 0;
TRUNCATE TABLE author;
TRUNCATE TABLE authorship;
TRUNCATE TABLE book;
TRUNCATE TABLE book_copy;
TRUNCATE TABLE counter_event;
TRUNCATE TABLE customer;
TRUNCATE TABLE employee;
TRUNCATE TABLE journal;
TRUNCATE TABLE journal_article;
TRUNCATE TABLE journal_issue;
TRUNCATE TABLE keyword;
TRUNCATE TABLE kwd_synonym;
TRUNCATE TABLE loan;
TRUNCATE TABLE loan_process;
TRUNCATE TABLE publisher;
TRUNCATE TABLE reservation;
TRUNCATE TABLE shelf;
TRUNCATE TABLE subject_area;
TRUNCATE TABLE text_kwd;
TRUNCATE TABLE textx;
TRUNCATE TABLE log;
SET foreign_key_checks = 1;

COMMIT;

START TRANSACTION;

INSERT INTO subject_area (subject_name)
VALUES ('Physics'),
       ('Chemistry'),
       ('Lolcats');

INSERT INTO shelf (shelf_id, subject_id)
VALUES (1, 1),
       (2, 2),
       (3, NULL),
       (4, NULL);

INSERT INTO textx (text_title, subject_id, is_book)
VALUES ('nuclear physics', 1, 1),
       ('organic chemistry', 2, 1),
       ('graviton research at CERN 2020', 1, 0),
       ('refining elastomers by oxidation', 2, 0);

INSERT INTO journal (journal_title, shelf_id)
VALUES ('Trantor University STEM Awards Papers', 3);

INSERT INTO journal_issue (journal_id, issue_number, publish_date)
VALUES (1, 1, '2020-10-30'),
       (1, 2, '2021-10-17');

INSERT INTO journal_article (article_id, issue_id)
VALUES (3, 1),
       (4, 2);

INSERT INTO publisher (publisher_name)
VALUES ('Westinghouse');

INSERT INTO book (book_id, publisher_id, shelf_id)
VALUES (1, 1, 1),
       (2, 1, 2);

INSERT INTO book_copy (book_id, copy_number)
VALUES (1, 1),
       (1, 2),
       (2, 1),
       (2, 2);

INSERT INTO author (author_name)
VALUES ('Pia Hollingsworth'),
       ('Peter Rourke'),
       ('Clara Hampton'),
       ('Charles Freeman');

INSERT INTO authorship (author_id, text_id)
VALUES (1, 1),
       (2, 1),
       (3, 2),
       (4, 2),
       (1, 3),
       (3, 4);

INSERT INTO keyword (kwd_content)
VALUES ('nuclear physics'),
       ('atomic physics'),
       ('elastomers'),
       ('organic chemistry'),
       ('textbook');

INSERT INTO kwd_synonym (kwd_a, kwd_b, match_pct)
VALUES (1, 2, 1.0);


INSERT INTO text_kwd (text_id, kwd_id)
VALUES (1, 1),
       (1, 2),
       (1, 5),
       (2, 4),
       (2, 5),
       (4, 3),
       (4, 4);

INSERT INTO customer (customer_name, customer_status)
VALUES ('John Doe Customer', 2),
       ('Master librarian', 2),
       ('Mr Clark', 2);

INSERT INTO employee (employee_id, position)
VALUES (2, 'Boss'),
       (3, 'Clerk');

INSERT INTO loan_process (book_id, copy_number, customer_id)
VALUES (1, 1, 1);

-- handle reservation later in an extra thing

INSERT INTO counter_event (employee_id, event_time)
VALUES (2, NOW()),
       (3, NOW());

INSERT INTO loan (loan_id, picked_up, returned, due_date)
VALUES (1, 1, 2, CURRENT_DATE);

COMMIT;

/*
 For tracking loan status, let's assume
 - one returned book
 - one overdue book
 - one book on loan
 - one canceled reservation
 - one reserved book
 */

INSERT INTO textx (text_title, subject_id)
VALUES ('The return of the textbook', 1),
       ('Time dilation in book loans', 1),
       ('The mechanics of travelling books', 1),
       ('Quantum tunneling in book reservations', 1),
       ('The Potential energy of reserved books', 1);

INSERT INTO book (book_id, publisher_id, shelf_id)
VALUES (5, 1, 1),
       (6, 1, 1),
       (7, 1, 1),
       (8, 1, 1),
       (9, 1, 1);

INSERT INTO book_copy (book_id)
VALUES (5),
       (6),
       (7),
       (8),
       (9);

-- not setting authorship and keywords for now

INSERT INTO loan_process (book_id, copy_number, customer_id)
VALUES (5, 1, 1),
       (6, 1, 1),
       (7, 1, 1),
       (8, 1, 1),
       (9, 1, 1);

UPDATE book_copy
SET current_loan = NULL
WHERE book_id = 5
   OR book_id = 8;

INSERT INTO reservation (loan_id, reserved_at, reservation_canceled_at)
VALUES (3, '2019-10-04', NULL),
       (5, '2019-10-04', '2020-04-03'),
       (6, '2019-10-04', NULL);

INSERT INTO counter_event (employee_id, event_time)
VALUES (2, '2019-03-14'),
       (3, '2019-04-16');

INSERT INTO loan (loan_id, picked_up, returned, due_date)
VALUES (2, 3, 4, '2019-11-26'),
       (3, 3, NULL, '2019-11-26'),
       (4, 3, NULL, '2022-11-26');


