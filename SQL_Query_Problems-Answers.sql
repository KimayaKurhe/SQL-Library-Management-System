SELECT * FROM branch;
SELECT * FROM employee;
SELECT * FROM books;
SELECT * FROM members;
SELECT * FROM issued_status;
SELECT * FROM return_status;

-- Q.1) CRUD Operations

-- 1. Create new book record : '978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.'.    

INSERT INTO books(isbn, book_title, category, rental_price, status, author, publisher)
VALUES ('978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.');

SELECT * FROM books;

-- 2. Update an Existing Member's Address

UPDATE members SET member_address = '125 Main St'
WHERE member_id = 'C101';

SELECT * FROM members
ORDER BY member_id ASC;

-- 3. Delete a Record from the Issued Status Table.

DELETE FROM issued_status
WHERE issued_id = 'IS121';      --could be able to delete because this id not referencing to other table

SELECT * FROM issued_status
WHERE issued_id = 'IS121';

-- 4. Retrieve All Books Issued by a Specific Employee (emp id with 'E101').

SELECT b.isbn, b.book_title, i_s.issued_emp_id 
FROM books b JOIN issued_status i_s ON b.isbn = i_s.issued_book_isbn
WHERE i_s.issued_emp_id = 'E101';

-- 5. List Members Who Have Issued More Than One Book.

SELECT issued_member_id, COUNT(issued_id) AS books_issued 
FROM issued_status
GROUP BY issued_member_id
HAVING COUNT(issued_id)>1
ORDER BY 1 ASC;

-- Q.2) CTAS (Create Table As Select): Create Summary Tables: Used CTAS to generate new tables based on query results - each book and total book_issued_cnt.    

CREATE TABLE cnt_of_books_issued            -- if we delete this query still we can use that table
AS
SELECT b.isbn, b.book_title, COUNT(ist.issued_id) AS no_issued 
FROM books b LEFT JOIN issued_status ist ON b.isbn = ist.issued_book_isbn
GROUP BY 1,2;

SELECT * FROM cnt_of_books_issued;

-- Q.3) Retrieve All Books in a Specific Category.

SELECT * FROM books
WHERE category = 'Classic';

-- Q.4) count the total books of each category 

SELECT category, COUNT(DISTINCT(book_title)) AS books
FROM books
GROUP BY 1;

-- Q.5) Find Total Rental Income by Category

SELECT b.category, SUM(b.rental_price) AS rental_price, COUNT(*) AS times_issued
FROM books b JOIN issued_status ist ON b.isbn = ist.issued_book_isbn    -- can use RIGHT JOIN also
GROUP BY 1;

-- Q.6) List Members Who Registered in the Last 180 Days:

SELECT * FROM members
WHERE reg_date >=CURRENT_DATE - INTERVAL '180 DAYS';

-- SELECT CURRENT_DATE - INTERVAL '180 DAYS' AS date ;

-- Q.7) List Employees with their Branch Manager's Name and their branch details

SELECT 
	 e1.emp_id, 
	 e1.emp_name, 
	 e2.emp_name AS manager, 
	 b.* 
FROM employee e1 JOIN branch b ON e1.branch_id = b.branch_id 
	 JOIN employee e2 ON b.manager_id = e2.emp_id;

-- Q.8) Books with Rental Price Above a Certain Threshold

SELECT * FROM books
WHERE rental_price > 7;

-- Q.9) The List of Books Not Yet Returned

SELECT * 
FROM issued_status ist LEFT JOIN return_status rst ON ist.issued_id = rst.issued_id
WHERE rst.return_id IS NULL;


-- Inserting additional records for solving further queries

INSERT INTO issued_status(issued_id, issued_member_id, issued_book_name, issued_date, issued_book_isbn, issued_emp_id)
VALUES
('IS151', 'C118', 'The Catcher in the Rye', CURRENT_DATE - INTERVAL '24 days',  '978-0-553-29698-2', 'E108'),
('IS152', 'C119', 'The Catcher in the Rye', CURRENT_DATE - INTERVAL '13 days',  '978-0-553-29698-2', 'E109'),
('IS153', 'C106', 'Pride and Prejudice', CURRENT_DATE - INTERVAL '7 days',  '978-0-14-143951-8', 'E107'),
('IS154', 'C105', 'The Road', CURRENT_DATE - INTERVAL '32 days',  '978-0-375-50167-0', 'E101');

SELECT * FROM issued_status;

ALTER TABLE return_status
ADD COLUMN book_quality VARCHAR(15) DEFAULT('Good');

UPDATE return_status
SET book_quality = 'Damaged'
WHERE issued_id IN ('IS112', 'IS117', 'IS118');

SELECT * FROM return_status;


/* Q.10) Identify Members with Overdue Books
Write a query to identify members who have overdue books (assume a 30-day return period). Display the member's_id, member's name, book title, issue date, and days overdue. */

SELECT 
	 ist.issued_member_id, 
	 m.member_name, 
	 ist.issued_book_name, 
	 ist.issued_date, 
	 (CURRENT_DATE - ist.issued_date) AS over_dues
FROM issued_status ist JOIN members m ON ist.issued_member_id = m.member_id
	 LEFT JOIN return_status rst ON ist.issued_id = rst.issued_id
WHERE rst.return_id IS NULL AND (CURRENT_DATE - ist.issued_date) > 30
ORDER BY 1;

/* Q.11) Update Book Status on Return
Write a query to update the status of books in the books table to "Yes" when they are returned (based on entries in the return_status table). 
Book of isbn = 978-0-7432-7357-1 not return yet
Let's consider that book return today */

-- creating procedure or function for automatically updating
CREATE OR REPLACE PROCEDURE add_return_record(p_return_id VARCHAR(10), p_issued_id VARCHAR(10), p_book_quality 														  VARCHAR(15))
LANGUAGE plpgsql
AS
$$

DECLARE 

	var_isbn VARCHAR(20);
	var_book_name VARCHAR(75);

BEGIN

	INSERT INTO return_status(return_id, issued_id, return_date, book_quality)
	VALUES (p_return_id, p_issued_id, CURRENT_DATE, p_book_quality);

	SELECT issued_book_isbn, issued_book_name
	INTO var_isbn, var_book_name
	FROM issued_status
	WHERE issued_id = p_issued_id;

	UPDATE books
	SET status = 'Yes'
	WHERE isbn = var_isbn;

	RAISE NOTICE 'Record of book "%" for returning have been save.', var_book_name;

END;
$$

CALL add_return_record('RS119', 'IS136', 'Good');

SELECT * FROM return_status;
SELECT * FROM books;

/* Q.12) Branch Performance Report
Create a query that generates a performance report for each branch, showing the number of books issued, the number of books returned, and the total revenue generated from book rentals. */

CREATE TABLE branch_report
AS
SELECT b.branch_id, 
	   b.manager_id, 
	   COUNT(ist.issued_id) AS no_books_issued,
	   COUNT(rst.return_id) AS no_books_return,
	   SUM(bk.rental_price) AS total_revenue
FROM issued_status ist JOIN employee e ON ist.issued_emp_id = e.emp_id
	 JOIN branch b ON e.branch_id = b.branch_id
	 LEFT JOIN return_status rst ON rst.issued_id = ist.issued_id
	 JOIN books bk ON ist.issued_book_isbn = bk.isbn
GROUP BY 1,2
ORDER BY 1 ASC;

SELECT * FROM branch_report;

/* Q.13) Create a Table of Active Members
Use the CREATE TABLE AS (CTAS) statement to create a new table active_members containing members who have issued at least one book in the last 2 months. */

CREATE TABLE active_mambers
AS
SELECT member_id
FROM members
WHERE member_id IN (
				      SELECT DISTINCT(issued_member_id) FROM issued_status
					  WHERE issued_date >= CURRENT_DATE - INTERVAL '2 month'
				   ) 

SELECT * FROM active_mambers;

/* Q.14) Find Employees with the Most Book Issues Processed
Write a query to find the top 3 employees who have processed the most book issues. Display the employee name, number of books processed, and their branch. */

SELECT e.emp_id, 
	   e.emp_name,
	   e.branch_id,
	   COUNT(ist.issued_id) AS no_books_issued
FROM issued_status ist JOIN employee e ON ist.issued_emp_id = e.emp_id
GROUP BY 1
ORDER BY COUNT(ist.issued_id) DESC
LIMIT 3;

/* Q.15) Stored Procedure Objective:
Create a stored procedure to manage the status of books in a library system. Description: Write a stored procedure that updates the status of a book in the library based on its issuance. The procedure should function as follows: The stored procedure should take the book_id as an input parameter. The procedure should first check if the book is available (status = 'yes'). If the book is available, it should be issued, and the status in the books table should be updated to 'no'. If the book is not available (status = 'no'), the procedure should return an error message indicating that the book is currently not available. */

CREATE OR REPLACE PROCEDURE issue_book_entry(p_issued_id VARCHAR(10) , p_issued_member_id VARCHAR(30), p_issued_book_isbn VARCHAR(50), p_ssued_emp_id VARCHAR(10))
LANGUAGE plpgsql
AS
$$

DECLARE
	var_status VARCHAR(10);
	var_title VARCHAR(75);

BEGIN

	-- checking book is available or not
	SELECT status, book_title INTO var_status, var_title
	FROM books
	WHERE isbn = p_issued_book_isbn;

	IF var_status = 'yes' THEN
		INSERT INTO issued_status(issued_id, issued_member_id, issued_book_name, issued_date, issued_book_isbn, 										 issued_emp_id)
		VALUES(p_issued_id, p_issued_member_id, var_title, CURRENT_DATE, p_issued_book_isbn, p_ssued_emp_id);

	UPDATE books
	SET status = 'no'
	WHERE isbn = p_issued_book_isbn;

	RAISE NOTICE 'Book Record added succesfully for Book : % ISBN : % ', var_title, p_issued_book_isbn;

	ELSE 
		RAISE NOTICE 'Book is not available of ISBN : % ', p_issued_book_isbn;

	END IF;

END;
$$

-- eg. "978-0-553-29698-2"

CALL issue_book_entry('IS155', 'C108', '978-0-553-29698-2', 'E104');
CALL issue_book_entry('IS156', 'C109', '978-0-553-29698-2', 'E104');


































