 -- Customer borrows two books

 select * from book_copy WHERE book_id = 2;

 select * from loan_overview WHERE book_id = 2;

 call loan_unreserved_copy(2, 1, 1, NULL, 2, '2022-05-26');
 select max(event_id) into @pickup_event from counter_event;
 SELECT max(loan_id) into @loan_1 from loan_process;
 call loan_unreserved_copy(2, 2, 1, @pickup_event, null, '2022-05-26');
 SELECT max(loan_id) into @loan_2 from loan_process;

 select * from book_copy WHERE book_id = 2;

 select * from loan_overview WHERE book_id = 2;

 SELECT @pickup_event, @loan_1, @loan_2;


 -- Customer returns two books

 CALL return_copy(@loan_1, null, 3);
 select max(event_id) into @return_event from counter_event;
 CALL return_copy(@loan_2, @return_event, null);

 select * from book_copy WHERE book_id = 2;

 select * from loan_overview WHERE book_id = 2;

