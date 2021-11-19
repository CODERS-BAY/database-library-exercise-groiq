DROP DATABASE IF EXISTS library;
CREATE DATABASE library;
USE library;

/*
For simplicity I'll pretend that non-null is the default, 
so a field is supposed to be nullable only if explicitly stated. 
*/

-- subject areas 

CREATE TABLE subject_area
(
    subject_id   INT PRIMARY KEY AUTO_INCREMENT,
    subject_name VARCHAR(64)
);

-- shelves

CREATE TABLE shelf
(
    shelf_id         INT PRIMARY KEY,
    subject_id       INT                                                    NULL
        COMMENT 'connects a book shelf (as opposed to a journal shelf) to a subject. Identifies a book shelf.',
    journal_shelf_id INT AS (IF(subject_id IS NULL, shelf_id, NULL)) STORED NULL UNIQUE
        COMMENT 'null for a bookshelf, shelf_id for a journal shelf',
    bookshelf_id     INT AS (IF(subject_id IS NULL, NULL, shelf_id)) STORED NULL UNIQUE
        COMMENT 'shelf_id for a bookshelf, null for a journal shelf',
    FOREIGN KEY (subject_id) REFERENCES subject_area (subject_id)
);

-- texts

-- note that subject_id for books is set twice, once here and once through shelf. That's an issue.
CREATE TABLE textx
(
    text_id    INT PRIMARY KEY,
    text_title VARCHAR(64),
    subject_id INT,
    is_book    BOOLEAN,
    book_id    INT AS (IF(is_book = TRUE, text_id, NULL)) STORED NULL UNIQUE,
    article_id INT AS (IF(is_book = TRUE, NULL, text_id)) STORED NULL UNIQUE,
    FOREIGN KEY (subject_id) REFERENCES subject_area (subject_id)
) COMMENT 'a single text; either a book or a journal article. X is appended because text is a reserved word.';

-- journals

CREATE TABLE journal
(
    journal_id          INT PRIMARY KEY AUTO_INCREMENT,
    journal_title       VARCHAR(64),
    issue_name_template VARCHAR(64)
        COMMENT 'can hold a template for issue designation, eg. "01/2010", "Fall 2010",..., supposing template handling is up to the app',
    shelf_id            INT,
    FOREIGN KEY (shelf_id) REFERENCES shelf (journal_shelf_id)
);
CREATE TABLE journal_issue
(
    issue_id     INT PRIMARY KEY AUTO_INCREMENT,
    journal_id   INT,
    issue_number INT,
    publish_date DATE,
    FOREIGN KEY (journal_id) REFERENCES journal (journal_id),
    UNIQUE (journal_id, issue_number),
    UNIQUE (journal_id, publish_date)
) COMMENT 'tracks a single issue of a journal by both publish date and an issue number.';
CREATE TABLE article
(
    article_id    INT PRIMARY KEY AUTO_INCREMENT,
    article_title VARCHAR(64),
    issue_id      INT,
    FOREIGN KEY (issue_id) REFERENCES journal_issue (issue_id),
    FOREIGN KEY (article_id) REFERENCES textx (article_id)
);

-- books

CREATE TABLE publisher
(
    publisher_id   INT PRIMARY KEY AUTO_INCREMENT,
    publisher_name VARCHAR(54)
);
-- assuming that all copies of a book are stored in the same place
CREATE TABLE book
(
    book_id      INT PRIMARY KEY AUTO_INCREMENT,
    publisher_id INT,
    shelf_id     INT,
    FOREIGN KEY (publisher_id) REFERENCES publisher (publisher_id),
    FOREIGN KEY (shelf_id) REFERENCES shelf (bookshelf_id),
    FOREIGN KEY (book_id) REFERENCES textx (book_id)
);
CREATE TABLE book_copy
(
    book_id      INT,
    copy_number  INT COMMENT 'counter for multiple copies of the same book',
    is_available BOOLEAN DEFAULT TRUE COMMENT 'tracks only whether a book is currently available. More information handled through a loan itself.',
    FOREIGN KEY (book_id) REFERENCES book (book_id),
    PRIMARY KEY (book_id, copy_number)
) COMMENT 'a copy of a book, identified by the book id + copy number';

-- authors

CREATE TABLE author
(
    author_id   INT PRIMARY KEY AUTO_INCREMENT,
    author_name VARCHAR(64)
);
CREATE TABLE authorship
(
    author_id INT,
    text_id   INT,
    FOREIGN KEY (author_id) REFERENCES author (author_id),
    FOREIGN KEY (text_id) REFERENCES textx (text_id),
    PRIMARY KEY (author_id, text_id)
);

-- keywords

CREATE TABLE keyword
(
    kwd_id INT PRIMARY KEY AUTO_INCREMENT
);
CREATE TABLE kwd_synonym
(
    synonym_id   INT PRIMARY KEY AUTO_INCREMENT,
    kwd_id       INT,
    snyonym_text VARCHAR(64),
    FOREIGN KEY (kwd_id) REFERENCES keyword (kwd_id)
);
CREATE TABLE text_kwd
(
    text_id   INT,
    kwd_id    INT,
    relevance INT,
    FOREIGN KEY (text_id) REFERENCES textx (text_id),
    FOREIGN KEY (kwd_id) REFERENCES keyword (kwd_id),
    PRIMARY KEY (text_id, kwd_id)
);

-- people

CREATE TABLE customer_status
(
    status_id   INT PRIMARY KEY AUTO_INCREMENT,
    status_name VARCHAR(64)
);
INSERT INTO customer_status
    (status_name)
VALUES ('inactive / locked'),
       ('active'),
       ('overdue');
CREATE TABLE customer
(
    customer_id     INT PRIMARY KEY AUTO_INCREMENT,
    customer_name   VARCHAR(64),
    customer_status INT DEFAULT 1,
    FOREIGN KEY (customer_status) REFERENCES customer_status (status_id)
);
-- Since an employee will probably want to loan books themselves, employees get a customer account.
CREATE TABLE employee
(
    employee_id        INT PRIMARY KEY AUTO_INCREMENT,
    position           VARCHAR(64),
    salary_information VARCHAR(64),
    FOREIGN KEY (employee_id) REFERENCES customer (customer_id)
);

-- loan handling

CREATE TABLE counter_event
(
    event_id    INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT,
    event_time  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fee_paid    DECIMAL(8, 2),
    FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) COMMENT 'stores one customer interaction at the counter, where the customer can pay some fees and pick up and/or return multiple books';
CREATE TABLE loan_process
(
    loan_id     INT PRIMARY KEY AUTO_INCREMENT,
    book_id     INT,
    copy_number INT,
    customer_id INT,
    FOREIGN KEY (book_id, copy_number) REFERENCES book_copy (book_id, copy_number),
    FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
) COMMENT 'tracks a loan and/or reservation with book copy and customer';
-- I assume that all reservations are online, because if the customer is present, they can just pick up a book. 
-- So a reservation is never connected to a counter event. 
-- Multiple books could be reserved in a single session, but this isn't tracked.
CREATE TABLE reservation
(
    loan_id                 INT PRIMARY KEY,
    reserved_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reservation_canceled_at TIMESTAMP NULL,
    FOREIGN KEY (loan_id) REFERENCES loan_process (loan_id)
);
CREATE TABLE loan
(
    loan_id   INT PRIMARY KEY,
    picked_up INT,
    returned  INT NULL,
    due_date  DATE,
    FOREIGN KEY (loan_id) REFERENCES loan_process (loan_id),
    FOREIGN KEY (picked_up) REFERENCES counter_event (event_id),
    FOREIGN KEY (returned) REFERENCES counter_event (event_id)
);

-- sample: how to determine loan status
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
