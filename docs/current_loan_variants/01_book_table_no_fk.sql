DROP DATABASE IF EXISTS library_variants;
CREATE DATABASE library_variants;
USE library_variants;

-- variant 1: current loan tracked in book, no fk

CREATE TABLE book
(
    bid          INT PRIMARY KEY,
    btitle       VARCHAR(64) NOT NULL,
    current_loan INT         NULL UNIQUE
);

CREATE TABLE loan
(
    lid       INT PRIMARY KEY,
    bid       INT       NOT NULL,
    picked_up TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    returned  TIMESTAMP NULL     DEFAULT NULL,
    FOREIGN KEY (bid) REFERENCES book (bid)
);


DELIMITER GO

CREATE TRIGGER loan_book
    AFTER
        INSERT
    ON loan
    FOR EACH ROW
BEGIN
    UPDATE book SET current_loan = new.lid WHERE bid = new.bid;
END GO

-- assuming that the only update is returning a book
CREATE TRIGGER return_book
    AFTER UPDATE
    ON loan
    FOR EACH ROW
BEGIN
    UPDATE book SET current_loan = NULL WHERE bid = old.bid;
END GO

delimiter ;

-- pro: easy to check book status
CREATE VIEW book_status AS
SELECT bid,
       CASE WHEN current_loan IS NULL THEN 'available' ELSE 'on loan' END AS status
FROM book;

-- contra: cannot set fk book.current_loan -> loan.lid without deferred check

INSERT INTO book (bid, btitle)
VALUES (1, 'my book');
INSERT INTO loan (lid, bid)
VALUES (1, 1);
UPDATE book
SET current_loan = 400
WHERE bid = 1;

SELECT b.bid, b.btitle, b.current_loan, l1.lid, l2.lid
FROM book b
         JOIN loan l1 ON b.bid = l1.bid
         LEFT JOIN loan l2 ON b.current_loan = l2.lid;
