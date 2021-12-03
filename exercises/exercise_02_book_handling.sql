-- List all books by a specific author

SELECT text_title, subject_id
FROM textx t
         JOIN authorship a ON t.text_id = a.text_id
WHERE a.author_id = 1
  AND t.is_book = TRUE;

-- Add a book by a known author

INSERT INTO textx (text_title, subject_id, is_book) VALUES ('Introduction to thermodynamics', 1, 1);
SELECT last_insert_id() into @last_insert;
INSERT INTO book (book_id, publisher_id, shelf_id) VALUES (@last_insert, 1, 1);
INSERT INTO book_copy (book_id) VALUES (@last_insert);
INSERT INTO authorship (author_id, text_id) VALUES (1, @last_insert);

-- new books come in

INSERT INTO book_copy (book_id, copy_number) VALUES (@last_insert, 2), (@last_insert, 3), (@last_insert, 4);

-- A book comes in with three authors (one is new)

INSERT INTO textx (text_title, subject_id, is_book) VALUES ('Advanced mechanics', 1, 1);
SELECT last_insert_id() into @last_insert;
INSERT INTO book (book_id, publisher_id, shelf_id) VALUES (@last_insert, 1, 1);
INSERT INTO book_copy (book_id) VALUES (@last_insert);
INSERT INTO authorship (author_id, text_id) VALUES (1, @last_insert);
INSERT INTO authorship (author_id, text_id) VALUES (2, @last_insert);
INSERT INTO author (author_name) values ('Pavel LaCrique');
SELECT last_insert_id() INTO @last_author;
INSERT INTO authorship (author_id, text_id) VALUES (@last_author, @last_insert);

