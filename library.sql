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
create table document (
    text_id int primary key,
    text_title varchar(64),
    subject_id int,
    is_book boolean,
    book_id int as (if(is_book = true, text_id, null)) stored null unique,
    article_id int as (if(is_book = true, null, text_id)) stored null unique,
    foreign key (subject_id) references subject_area (subject_id)
) comment 'a single text; either a book or a journal article';

-- journals

create table journal (
    journal_id int primary key auto_increment,
    journal_title varchar(64),
    issue_name_template varchar(64) 
		comment 'can hold a template for issue designation, eg. "01/2010", "Fall 2010",..., supposing template handling is up to the app',
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
    foreign key (issue_id) references journal_issue (issue_id),
    foreign key (article_id) references document (article_id)
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
    foreign key (book_id) references document (book_id)
);
create table book_copy (
    book_id int,
    copy_count int comment 'counts multiple copies of the same book',
    is_available boolean default true comment 'tracks only whether a book is currently available. More information handled through a loan itself.',
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
    FOREIGN KEY (text_id) REFERENCES document (text_id),
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
    FOREIGN KEY (text_id) REFERENCES document (text_id),
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
    salary_information varchar(64),
    foreign key (employee_id) references customer (customer_id)
);

-- loan handling

create table counter_event (
    event_id int primary key auto_increment,
    employee_id int,
    event_time timestamp default current_timestamp,
    fee_paid decimal(8, 2),
    foreign key (employee_id) references employee (employee_id)
) comment 'stores one customer interaction at the counter, where the customer can pay some fees and pick up and/or return multiple books';
create table loan_process (
	loan_id int primary key auto_increment,
    book_id int,
    copy_count int,
    customer_id int,
    foreign key (book_id, copy_count) references book_copy (book_id, copy_count),
    foreign key (customer_id) references customer (customer_id)
) comment 'tracks a loan and/or reservation with book copy and customer';
-- I assume that all reservations are online, because if the customer is present, they can just pick up a book. 
-- So a reservation is never connected to a counter event. 
-- Multiple books could be reserved in a single session, but this isn't tracked.
create table reservation (
	loan_id int primary key,
    reserved_at timestamp default current_timestamp,
    reservation_canceled_at timestamp null,
    foreign key (loan_id) references loan_process (loan_id)
);
create table loan (
	loan_id int primary key,
    picked_up int,
    returned int null,
    due_date date,
    foreign key (loan_id) references loan_process (loan_id),
    foreign key (picked_up) references counter_event (event_id),
    foreign key (returned) references counter_event (event_id)
);

-- how to determine loan status
create view loan_overview as 
	select 
		p.book_id,
        p.copy_count,
        p.customer_id,
        r.reserved_at,
        r.reservation_canceled_at,
        l.picked_up,
        l.returned,
        l.due_date,
        (
			case 
			when returned is not null then 'returned' 
            when picked_up is not null then 
				case
				when due_date < current_date then 'overdue'
				else 'on loan'
				end
            when reservation_canceled_at is not null then 'canceled reservation' 
            when reserved_at is not null then 'reserved'
            else 'data error'
			end
		) as loan_status, 
        (
			(returned is not null) * 1 + 
			(picked_up is not null) * 2 + 
			(due_date is not null and due_date < current_date) * 4 + 
			(reservation_canceled_at is not null) * 8 + 
			(reserved_at is not null) * 16 
        ) as status_code
    from loan_process as p
    left join reservation as r on p.loan_id = r.loan_id 
    left join loan as l on p.loan_id = l.loan_id;
