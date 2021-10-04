drop database if exists library;
create database library;
use library;

/*
For simplicity I'll pretend that non-null is the default, 
so a field is supposed to be nullable only if explicitly stated. 
*/

-- subject areas 

create table subject_area (
    subject_id int primary key auto_increment,
    subject_name varchar(64)
);

-- shelves

create table shelf (
    shelf_id int primary key,
    subject_id int null 
		comment 'connects a book shelf (as opposed to a journal shelf) to a subject. Identifies a book shelf.',
    journal_shelf_id int as (if(subject_id is null, shelf_id, null)) stored null unique
		comment 'null for a bookshelf, shelf_id for a journal shelf',
    bookshelf_id int as (if(subject_id is null, null, shelf_id)) stored null unique
		comment 'shelf_id for a bookshelf, null for a journal shelf',
    foreign key (subject_id) references subject_area (subject_id)
);

-- texts

-- note that subject_id for books is set twice, once here and once through shelf. That's an issue.
create table text (
    text_id int primary key,
    text_title varchar(64),
    subject_id int,
    is_book boolean,
    book_id int as (if(is_book = true, text_id, null)) stored null unique,
    article_id int as (if(is_book = true, null, text_id)) stored null unique,
    foreign key (subject_id) references subject_area (subject_id)
);

-- journals

create table journal (
    journal_id int primary key auto_increment,
    journal_title varchar(64),
    issue_name_template varchar(64) 
		comment 'can hold a template for issue designation, eg. "01/2010", "Fall 2010",...',
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
) comment 'tracks a single issue of a journal by both publish date and an issue number.';
create table article (
    article_id int PRIMARY key auto_increment,
    article_title varchar(64),
    issue_id int,
    subject_id int,
    foreign key (issue_id) references journal_issue (issue_id),
    foreign key (article_id) references text (article_id)
);

-- books

create table publisher (
    publisher_id int primary key auto_increment,
    publisher_name varchar(54)
);
-- assuming that all copies of a book are stored in the same place
create table book (
    book_id int primary key auto_increment,
    publisher_id int,
    shelf_id int,
    foreign key (publisher_id) references publisher (publisher_id),
    foreign key (shelf_id) references shelf (bookshelf_id),
    foreign key (book_id) references text (book_id)
);
create table book_copy (
    book_id int,
    copy_count int comment 'counts multiple copies of the same book',
    is_available boolean default true comment 'tracks only if a book is available for loan. More information are handled in a loan itself.',
    FOREIGN KEY (book_id) REFERENCES book (book_id),
    PRIMARY KEY (book_id, copy_count)
);

-- authors

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

-- keywords

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

-- people

create table customer_status (
	status_id int primary key auto_increment,
    status_name varchar(64)
);
insert into customer_status 
	(status_name) 
values 
	('inactive / locked'),
    ('active'),
    ('overdue');
create table customer (
    customer_id int primary key auto_increment,
    customer_name varchar(64),
    customer_status int default 1,
    foreign key (customer_status) references customer_status (status_id)
);
-- Since an employee will probably want to loan books themselves, employees get a customer account.
create table employee (
    employee_id int primary key auto_increment,
    position varchar(64),
    payment_information varchar(64),
    foreign key (employee_id) references customer (customer_id)
);

-- loan handling

create table counter_event (
    event_id int primary key auto_increment,
    customer_id int,
    employee_id int,
    event_time timestamp default current_timestamp,
    fee_paid decimal(8, 2),
    foreign key (customer_id) references customer (customer_id),
    foreign key (employee_id) references employee (employee_id)
) comment 'stores one customer interaction at the counter, where the customer can pay some fees and pick up and/or return multiple books';
-- Since reservations without loans are supposed to be an exception, I'll treat a reservation as an optional part of the loan process.
-- Multiple books could be reserved in a single session, but this isn't tracked.
create table loan_process (
	loan_id int primary key auto_increment,
    book_id int,
    copy_count int,
    customer_id int,
    foreign key (book_id, copy_count) references book_copy (book_id, copy_count),
    foreign key (customer_id) references customer (customer_id)
);
create table loan (
    loan_id int primary key auto_increment,
    reserved_at timestamp null default current_timestamp,
    reservation_canceled_at timestamp null,
    picked_up int null,
    returned int null,
    due_date date null,
    foreign key (picked_up) references counter_event (event_id),
    foreign key (returned) references counter_event (event_id)
);
/*
    loan_status varchar(16) as 
	(
		case
			when returned is not null then 
				'returned'
			when picked_up is not null then 
				'on loan'
			when reservation_canceled_at is not null then 
				'reservation canceled'
			else 
				'reserved'
        end
	) virtual,
*/
-- todo: check constraint: customer ids for loan and counter event must match (unless i want to make possible that someone returns someone else's books.)
-- todo: normalize into one table for loan, one for reservation and one that handles book and customer
create table reservation (
	loan_id int primary key,
    reserved_at timestamp default current_timestamp,
    expires_at timestamp,
    canceled_at timestamp null default null,
    expired_or_canceled timestamp as (ifnull(canceled_at, expires_at)),
    foreign key (loan_id) references loan (loan_id)
);
