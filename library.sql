DROP DATABASE IF EXISTS library;
CREATE DATABASE library;
USE library;

-- subject areas

CREATE TABLE subject_area
(
    subject_id   INT PRIMARY KEY AUTO_INCREMENT,
    subject_name VARCHAR(64) NOT NULL
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

/*
note that subject_id for books is set twice, once here and once through shelf. That's an issue.
The alternative would be setting subject_id in bookshelf and in journal_article,
but that would make tracking text subjects quite a hassle.
 */
CREATE TABLE textx
(
    text_id    INT PRIMARY KEY,
    text_title VARCHAR(64)                                       NOT NULL,
    subject_id INT                                               NOT NULL,
    is_book    BOOLEAN                                           NOT NULL DEFAULT TRUE,
    book_id    INT AS (IF(is_book = TRUE, text_id, NULL)) STORED NULL UNIQUE,
    article_id INT AS (IF(is_book = TRUE, NULL, text_id)) STORED NULL UNIQUE,
    FOREIGN KEY (subject_id) REFERENCES subject_area (subject_id)
) COMMENT 'a single text; either a book or a journal article. X is appended because text is a reserved word.';

-- journals

CREATE TABLE journal
(
    journal_id          INT PRIMARY KEY AUTO_INCREMENT,
    journal_title       VARCHAR(64) NOT NULL,
    issue_name_template VARCHAR(64) NULL
        COMMENT 'optional. can hold a template for issue designation, eg. "01/2010", "Fall 2010",..., supposing template handling is up to the app',
    shelf_id            INT         NOT NULL,
    FOREIGN KEY (shelf_id) REFERENCES shelf (journal_shelf_id)
);
CREATE TABLE journal_issue
(
    issue_id     INT PRIMARY KEY AUTO_INCREMENT,
    journal_id   INT  NOT NULL,
    issue_number INT  NOT NULL,
    publish_date DATE NOT NULL,
    FOREIGN KEY (journal_id) REFERENCES journal (journal_id),
    UNIQUE (journal_id, issue_number),
    UNIQUE (journal_id, publish_date)
) COMMENT 'tracks a single issue of a journal by both publish date and an issue number.';
CREATE TABLE journal_article
(
    article_id    INT PRIMARY KEY AUTO_INCREMENT,
    article_title VARCHAR(64) NOT NULL,
    issue_id      INT         NOT NULL,
    FOREIGN KEY (issue_id) REFERENCES journal_issue (issue_id),
    FOREIGN KEY (article_id) REFERENCES textx (article_id)
);

-- books

CREATE TABLE publisher
(
    publisher_id   INT PRIMARY KEY AUTO_INCREMENT,
    publisher_name VARCHAR(54) NOT NULL
);
CREATE TABLE book
(
    book_id      INT PRIMARY KEY AUTO_INCREMENT,
    publisher_id INT NOT NULL,
    shelf_id     INT NOT NULL COMMENT 'assuming that all copies of a book are stored in the same place',
    FOREIGN KEY (publisher_id) REFERENCES publisher (publisher_id),
    FOREIGN KEY (shelf_id) REFERENCES shelf (bookshelf_id),
    FOREIGN KEY (book_id) REFERENCES textx (book_id)
);
CREATE TABLE book_copy
(
    book_id      INT,
    copy_number  INT              DEFAULT 1 COMMENT 'counter for multiple copies of the same book',
    is_available BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'tracks only whether a book is currently available. More information handled through a loan itself.',
    FOREIGN KEY (book_id) REFERENCES book (book_id),
    PRIMARY KEY (book_id, copy_number)
) COMMENT 'a copy of a book, identified by the book id + copy number';

-- authors

CREATE TABLE author
(
    author_id   INT PRIMARY KEY AUTO_INCREMENT,
    author_name VARCHAR(64) NOT NULL
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
    kwd_id      INT PRIMARY KEY AUTO_INCREMENT,
    kwd_content VARCHAR(64) NOT NULL
);
CREATE TABLE kwd_synonym
(
    kwd_a     INT,
    kwd_b     INT,
    match_pct DECIMAL(3, 2) NULL COMMENT 'optional: match (congruence) between kwds in percent',
    FOREIGN KEY (kwd_a) REFERENCES keyword (kwd_id),
    FOREIGN KEY (kwd_b) REFERENCES keyword (kwd_id),
    PRIMARY KEY (kwd_a, kwd_b),
    CONSTRAINT max_one_synonym_entry_per_kwd_pair CHECK (kwd_a < kwd_b)
) COMMENT 'synonymous keywords. Each pair is recorded once, and a kwd cannot be matched with itself. Optionally record congruency in percent.';
CREATE TABLE text_kwd
(
    text_id   INT,
    kwd_id    INT,
    relevance DECIMAL(3, 2) NULL COMMENT 'optional: relevance of the kwd for the text in percent',
    FOREIGN KEY (text_id) REFERENCES textx (text_id),
    FOREIGN KEY (kwd_id) REFERENCES keyword (kwd_id),
    PRIMARY KEY (text_id, kwd_id)
) COMMENT 'tags a text with a keyword. Optionally tracks kwd relevance in percent.';

-- people

CREATE TABLE customer_status
(
    status_id   INT PRIMARY KEY AUTO_INCREMENT,
    status_name VARCHAR(64) NOT NULL
);
INSERT INTO customer_status
    (status_name)
VALUES ('inactive / locked'),
       ('active'),
       ('overdue');
CREATE TABLE customer
(
    customer_id     INT PRIMARY KEY AUTO_INCREMENT,
    customer_name   VARCHAR(64) NOT NULL,
    customer_status INT         NOT NULL DEFAULT 1,
    FOREIGN KEY (customer_status) REFERENCES customer_status (status_id)
);
CREATE TABLE employee
(
    employee_id        INT PRIMARY KEY AUTO_INCREMENT,
    position           VARCHAR(64) NULL COMMENT 'optionally track employee position',
    salary_information VARCHAR(64) NULL COMMENT 'optionally track some salary information',
    FOREIGN KEY (employee_id) REFERENCES customer (customer_id)
) COMMENT 'Since an employee will probably want to loan books themselves, employees get a customer account';

-- loan handling

CREATE TABLE counter_event
(
    event_id    INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT           NOT NULL COMMENT 'each counter event is handled by one employee',
    event_time  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fee_paid    DECIMAL(5, 2) NULL     DEFAULT 0.0 COMMENT 'optional: track fees paid at counter',
    FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) COMMENT 'stores one customer interaction at the counter, where the customer can pay some fees and pick up and/or return multiple books';
CREATE TABLE loan_process
(
    loan_id     INT PRIMARY KEY AUTO_INCREMENT,
    book_id     INT NOT NULL,
    copy_number INT NOT NULL,
    customer_id INT NOT NULL,
    FOREIGN KEY (book_id, copy_number) REFERENCES book_copy (book_id, copy_number),
    FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
) COMMENT 'tracks a loan and/or reservation with book copy and customer';
-- I assume that reservations are online, because if the customer is present, they can just pick up a book.
-- So a reservation isn't connected to a counter event.
-- Multiple books could be reserved in a single session, but this isn't tracked.
CREATE TABLE reservation
(
    loan_id                 INT PRIMARY KEY,
    reserved_at             TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    reservation_canceled_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (loan_id) REFERENCES loan_process (loan_id)
);
CREATE TABLE loan
(
    loan_id   INT PRIMARY KEY,
    picked_up INT  NOT NULL,
    returned  INT  NULL DEFAULT NULL,
    due_date  DATE NULL DEFAULT NULL COMMENT 'due date is optional in case they want to calculate it from pickup date',
    FOREIGN KEY (loan_id) REFERENCES loan_process (loan_id),
    FOREIGN KEY (picked_up) REFERENCES counter_event (event_id),
    FOREIGN KEY (returned) REFERENCES counter_event (event_id)
);

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
