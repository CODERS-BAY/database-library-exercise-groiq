DROP DATABASE IF EXISTS library_variants;
CREATE DATABASE library_variants;
USE library_variants;

-- variant 2: current loan has its own table, so i can set a fk to loan

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
    FOREIGN KEY (bid) REFERENCES book (bid)
);

CREATE TABLE current_loan
(
    bid INT PRIMARY KEY,
    lid INT UNIQUE NULL DEFAULT NULL,
    FOREIGN KEY (bid) REFERENCES book (bid),
    FOREIGN KEY (lid) REFERENCES loan (lid)
);

DELIMITER GO

CREATE TRIGGER new_book
    AFTER INSERT
    ON book
    FOR EACH ROW
BEGIN
    INSERT INTO current_loan (bid, lid) VALUES (new.bid, NULL);
END GO

CREATE TRIGGER loan_book
    AFTER
        INSERT
    ON loan
    FOR EACH ROW
BEGIN
    UPDATE current_loan SET lid = new.lid WHERE bid = new.bid;
END GO

-- assuming that the only update is returning a book
CREATE TRIGGER return_book
    AFTER UPDATE
    ON loan
    FOR EACH ROW
BEGIN
    UPDATE current_loan SET lid = NULL WHERE bid = old.bid;
END GO

-- checking book status is still not too complicated

CREATE VIEW book_status AS
SELECT bid, CASE WHEN lid IS NULL THEN 'available' ELSE 'on loan' END AS status
FROM loan;

CREATE VIEW book_title_with_status AS
SELECT b.bid,
       b.btitle,
       CASE WHEN cl.lid IS NULL THEN 'available' ELSE 'on loan' END AS status
FROM book b
         JOIN current_loan cl ON b.bid = cl.bid;

/*
contra: because cl.lid can be null, i cannot set a fk on the *combination* of bid and lid.
Thus I can check that the loan exists, but not that it is in the correct book.
This invalidates the entire point of the fk.
 */

INSERT INTO book (bid, btitle)
VALUES (1, 'novel for the centuries'),
       (2, 'boring drivel');

INSERT INTO loan (lid, bid)
VALUES (1, 2);

DELETE FROM current_loan WHERE bid = 2;
UPDATE current_loan
SET lid = 1
WHERE bid = 1;

SELECT b1.bid as cl_bid,
       b1.btitle as cl_title,
       cl.bid,
       cl.lid,
       l.lid,
       l.bid,
       b2.bid as l_bid,
       b2.btitle as l_title
FROM book b1
         JOIN current_loan cl ON b1.bid = cl.bid
         JOIN loan l ON l.lid = cl.lid
         JOIN book b2 ON l.bid = b2.bid;

-- in short, this variant introduces complications that don't really help matters.
