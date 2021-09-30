drop database if exists library;
create database library;
use library;
create table subject_area (
    subject_id int primary key auto_increment,
    subject_name varchar(64)
);
create table shelf (
    shelf_id int primary key,
    subject_id int not null,
    journal_shelf_id int generated always as (if(subject_id is null, shelf_id, null)) stored unique,
    bookshelf_id int generated always as (if(subject_id is null, null, shelf_id)) stored unique,
    foreign key (subject_id) references subject_area (subject_id)
);
create table journal (
    journal_id int primary key auto_increment,
    journal_title varchar(64),
    shelf_id int,
    foreign key (shelf_id) references shelf (journal_shelf_id)
);
create table journal_issue (
    issue_id int primary key auto_increment,
    journal_id int,
    issue_number int,
    publish_date date,
    foreign key (journal_id) references journal (journal_id),
    unique (journal_id, issue_number),
    unique (journal_id, publish_date)
);
create table article (
    article_id int PRIMARY key auto_increment,
    article_title varchar(64),
    issue_id int,
    subject_id int,
    foreign key (issue_id) references journal_issue (issue_id),
    foreign key (subject_id) references subject_area (subject_id)
);
create table publisher (
    publisher_id int primary key auto_increment,
    publisher_name varchar(54)
);
-- suppose a book's various copies are *not* in various shelves
create table book (
    book_id int primary key auto_increment,
    publisher_id int,
    shelf_id int,
    foreign key (publisher_id) references publisher (publisher_id),
    foreign key (shelf_id) references shelf (bookshelf_id)
);
-- note that subject_id for books is set twice, once here and once through shelf. That's an issue.
create table text (
    text_id int primary key auto_increment,
    text_title varchar(64),
    subject_id int,
    is_book boolean,
    book_id int null as (if(is_book = true, text_id, null)) stored,
    article_id int null as (if(is_book = true, null, text_id)) stored,
    foreign key (subject_id) references subject_area (subject_id),
    foreign key (book_id) REFERENCES book (book_id),
    foreign key (article_id) references article (article_id)
);
create table author (
    author_id int PRIMARY key AUTO_INCREMENT,
    author_name varchar(64)
);
create table authorship (
    author_id int,
    text_id int,
    FOREIGN KEY (author_id) REFERENCES author (author_id),
    FOREIGN KEY (text_id) REFERENCES text (text_id),
    PRIMARY KEY (author_id, text_id)
);
create table keyword (kwd_id int primary key auto_increment);
create table kwd_synonym (
    synonym_id int primary key auto_increment,
    kwd_id int,
    snyonym_text varchar(64),
    foreign key (kwd_id) references keyword (kwd_id)
);
create table text_kwd (
    text_id int,
    kwd_id int,
    relevance int,
    FOREIGN KEY (text_id) REFERENCES text (text_id),
    FOREIGN KEY (kwd_id) REFERENCES keyword (kwd_id),
    PRIMARY KEY (text_id, kwd_id)
);
create table book_copy (
    book_id int,
    copy_count int,
    status int,
    -- available, reserved, on loan, in process
    FOREIGN KEY (book_id) REFERENCES book (book_id),
    PRIMARY KEY (book_id, copy_count)
);
-- variant: every employee has a customer account
create table customer (
    customer_id int PRIMARY key auto_increment,
    customer_name varchar(64),
    status int
);
create table employee (
    employee_id int primary key auto_increment,
    employee_name varchar(64)
);
create table counter_event (
    event_id int primary key auto_increment,
    customer_id int,
    employee_id int,
    event_time timestamp,
    fee_paid decimal(8, 2),
    foreign key (customer_id) references customer (customer_id),
    foreign key (employee_id) references employee (employee_id)
);
-- A reservation is part of a loan process. In theory, multiple books could be reserved at once, but this isn't tracked. However, multiple books can be handled at once.
-- todo change - attributes to reservation - such as reserved until --
create table loan (
    loan_id int primary key auto_increment,
    book_id int,
    copy_count int,
    reserved_at date null,
    -- since books are in shelves, you can loan one without reservation
    customer_id int,
    picked_up int null,
    returned int null,
    foreign key (book_id, copy_count) REFERENCES book_copy (book_id, copy_count),
    foreign key (customer_id) references customer (customer_id),
    foreign key (picked_up) references counter_event (event_id),
    foreign key (returned) references counter_event (event_id)
);
-- variant: identify a counter event by event id + customer id for added integrity. (unless i want to make possible that someone returns someone else's books.)