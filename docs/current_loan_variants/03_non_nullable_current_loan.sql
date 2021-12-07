DROP DATABASE IF EXISTS library_variants;
CREATE DATABASE library_variants;
USE library_variants;

-- variant 3: current_loan has its own table, cl.lid is non-nullable

CREATE TABLE book
(
    bid    INT PRIMARY KEY,
    btitle VARCHAR(64) NOT NULL
);

CREATE TABLE loan
(
    lid       INT PRIMARY KEY,
    bid       INT       NOT NULL,
    picked_up TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    returned  TIMESTAMP NULL     DEFAULT NULL,
    UNIQUE (lid, bid), -- needs an index to be a fk target
    FOREIGN KEY (bid) REFERENCES book (bid)
);

CREATE TABLE current_loan
(
    bid INT PRIMARY KEY,
    lid INT UNIQUE NOT NULL,
    FOREIGN KEY (bid, lid) REFERENCES loan (lid)
);

DELIMITER GO

CREATE TRIGGER loan_book
    AFTER
        INSERT
    ON loan
    FOR EACH ROW
BEGIN
    INSERT INTO current_loan (lid, bid)
    VALUES (new.lid, new.bid)
    ON DUPLICATE KEY UPDATE lid = new.lid;
END GO

-- pro: now it's guaranteed that the loan and current_loan tables are consistent

/*
 counter: it's no longer possible to quick-check book availability
 without diving into the details of the loan table
 */

CREATE VIEW book_status AS
SELECT c.bid,
       c.lid,
       l.lid,
       l.bid,
       picked_up,
       returned,
       CASE WHEN returned IS NULL THEN 'on loan' ELSE 'available' END AS status
FROM current_loan AS c
         JOIN loan AS l ON c.lid = l.lid;

CREATE VIEW book_title_with_status AS
SELECT b.bid,
       b.btitle,
       CASE WHEN l.returned IS NULL THEN 'on loan' ELSE 'available' END AS status
FROM book b
         JOIN current_loan cl ON b.bid = cl.bid
         JOIN loan l ON cl.lid = l.lid;

/*
 So, while this solution is better than the others in terms of integrity,
 it doesn't solve the issue of looking up a book and quickly getting its availability.
 */
