##1- Create a stored procedure which has employee number as the input and output their salary, #dayoff request.

delimiter //

create procedure employeecheck(inout pemployeeid int, out firstname varchar (45) , out salary int, out dayoff int)

BEGIN
	
    set firstname = (select emp.firstname from employee emp
						where pemployeeid = emp.employeeid
                        group by emp.firstname);
    
    
    set salary = (select s.amount from salary s
					join employee emp on emp.employeeid = s.employeeid
						where pemployeeid = emp.employeeid
						group by s.amount);
					
    
    set dayoff = (select sum(datediff(enddate, startdate)) as 'dayoff' from employeerequest
						where pemployeeid = employeeid);
              
END //

delimiter ;

#2- Show the top 3 employee salaries for each role.

set @rank = 1;
set @co = '';

select employeeid, firstname, role, amount, corank from (
select *, @rank := if(@co = role, @rank+1, 1) as corank, @co := role from 
	(select emp.employeeid, emp.firstname, emp.role, s.amount from employee emp
	join salary s on s.employeeid = emp.employeeid
    order by emp.role, amount desc)sq1)sq2
where corank <= 3;
    

#3- Show the total number of class each employee taught and total number of hours teaching. Group by employee. Note, show only swimming or strength training classes.

select emp.employeeid, emp.firstname, emp.lastname, count(c.classname) as 'Total Class', sum(c.duration) as 'Total Hours' from employee emp
	join class_calender c1 on c1.employeeid = emp.employeeid
    join classtype c on c.classtypeid = c1.classtypeid
    where c.classname = 'swimming' or c.classname = 'strength'
    group by employeeid;

#1 Top 3 classes as per the Overall duration

SELECT *
FROM
(SELECT Class_Name,No_of_Classes,Duration,concat(Total_Duration,' ','hrs') AS 'Overall_Duration',
DENSE_RANK() OVER (ORDER BY Total_Duration desc) as 'Ranking'
FROM
(Select 
classname AS 'Class_Name',COUNT(*) as 'No_of_Classes',concat(duration,' ','Hrs') as 'Duration',
(COUNT(*)*duration) AS 'Total_Duration'
FROM
class_calender as cc
Join classtype as ct on cc.classtypeid=ct.classtypeid
GROUP BY classname) sq
) r1
WHERE Ranking <= 3;

#2 Top 5 Employee who have highest request durations

SELECT *
FROM
(SELECT *,
DENSE_RANK() OVER (ORDER BY Request_count desc) as 'Ranking'
FROM
(Select 
e.employeeid AS 'Employee_No',concat(firstname,' ',lastname) as 'Employee_Name',sum(datediff(enddate,startdate)) as 'Request_count'
FROM
employeerequest as er
join employee as e on er.employeeid=e.employeeid
GROUP BY e.employeeid
order by sum(datediff(enddate,startdate)) desc)sq
) r1
WHERE Ranking <= 5;

#3 Count Workers for each day within the date range

delimiter \\
CREATE PROCEDURE Worker_in_a_day(
in startdate date,in enddate date
 )
begin
select dayname(date) as 'Day',count(memberid) as 'Members_Count' from class_attendance as ca
join class_calender as c on c.classid=ca.classid
where date between startdate and enddate
group by dayname(date)
order by count(memberid) desc;

end \\

delimiter ;

#1 Number of times Employee has worked with in date range ordered by role and Employee Name

drop procedure if exists Person_worktimes;
delimiter \\

create procedure Person_worktimes(
IN start_date date,in end_date date 
 ) 
begin
Select role,Employee, count(*) as 'No_of_times_employee_worked', date from 
(select concat(firstname,' ',lastname) as 'Employee',role,date  from admin_calender as ad
join employee as e1 on e1.employeeid=ad.employeeid
union all 
select concat(firstname,' ',lastname) as 'Employee',role, date from class_calender as cc
join employee as e2 on e2.employeeid=cc.employeeid
union all
select concat(firstname,' ',lastname) as 'Employee',role, date from maintenance_schedule as ms
join employee as e3 on e3.employeeid=ms.employeeid
)sq
where date between start_date and end_date
group by role,Employee
order by role,Employee
 ;
end\\
delimiter ;

#2 Checking if an employee’s salary is more than average salary within the role

drop function if exists salary_status;

delimiter \\
create function salary_status(salary  dec(10,2), avg_salary dec(10,2)) returns varchar(100)
begin
	declare salary_s varchar(100);
if salary > avg_salary then set salary_s='More than Avg' ;
elseif salary < avg_salary then set salary_s='Less than Avg';
 	elseif salary = avg_salary then set salary_s='Avg Salary';
   	else set salary_s = 'unknown';
end if;
return(salary_s);
end\\

delimiter ;

select concat(firstname,' ',lastname) as 'EmployeeName',
sq.role,amount,round(Avg_Sal,2) as 'Avg_Sal',salary_status(amount,Avg_Sal)
as 'Salary_Status'
from salary as s
	join employee as e on s.employeeid=e.employeeid
	join(select role,avg(amount) as 'Avg_Sal' from salary as s
		join employee as e on s.employeeid=e.employeeid
    		group by role)sq on e.role=sq.role
group by s.employeeid
order by concat(firstname,lastname)
;

#3 - How many times the Work Type has been repeated based on either month or year input in stored procedure 

drop procedure if exists Worktypecount;

delimiter \\
CREATE PROCEDURE Worktypecount(
in worktype varchar(100),in ye varchar(4),in mo varchar(100) 
 )
begin
select wt.Worktypename as 'Work Type',month,year,No_of_Work from worktype as wt
join (select Worktypename ,
monthname(date) as 'month',year(date) as 'year', 
count(*) 'No_of_Work' from maintenance_schedule as ms
join  worktype as wt on  wt.workid=ms.workid
group by Worktypename,monthname(date),year(date)
)sq on sq.Worktypename=wt.Worktypename
where wt.Worktypename=worktype and (year=ye or month=mo)
group by wt.Worktypename,month,year
;
end \\
delimiter ;

#1 - Which membership level brings in the most revenue per month? 

select m.membershipid, name as 'MembershipType', count(billingid) as 'MembershipCount', rate, (count(billingid))*rate as 'Total Revenue FY2018'  from membershipbilling mb
left join membership m on m.membershipid=mb.membershipid
    group by m.membershipid
    order by (count(billingid))*rate;
    
#2 - Which member hasnt shown up to a class they signed up for more than 3 times in a month? 

select monthname(date) as 'Month', firstname,lastname, count(c.memberid) as 'Total No Shows' from member m
join class_attendance c on c.memberid=m.memberid
join class_calender cc on cc.classid=c.classid
where c.attendance =0 and month(date) = month(now())
group by m.memberid;

#3 - ##What percentage did membership jump in January as compared to the average month?

select sq1.membershipid, sq1.name as 'MembershipType', membershipjan as 'Member Count in January',AvreageMembership as 'Average Member Count',(membershipjan-AvreageMembership)/AvreageMembership as 'Percent Increase'  from
              (select m.membershipid, name,count(billingid) as MembershipJan from membershipbilling mb
				left join membership m on m.membershipid=mb.membershipid  
				where month(startdate)= 1  
				group by m.membershipid) sq1
join (select m.membershipid, name as 'MembershipType', (count(billingid)/2) as AvreageMembership from membershipbilling mb
				left join membership m on m.membershipid=mb.membershipid  
				where month(startdate)= 11 or month(startdate)= 12  
				group by m.membershipid) sq2 on sq1.membershipid=sq2.membershipid;
    
#1 - Find out the number of times a member has been billed? order by Memberid

select m.memberid, m.firstname, m.lastname, m1.name as 'Membershiptype',count(*) as 'Numberoftimes Billed' from membershipbilling mb
	join member m on m.memberid = mb.memberid
    join membership m1 on m1.membershipid = mb.membershipid
    group by m.memberid
    order by m.memberid;

#2 - Create a function that returns a member's first name, last name,
# username, and password, with an input of member ID.

delimiter //

create procedure RecoverPassword(in pmemberid int(3))
BEGIN
select memberid, firstname, lastname, username, password from member
	where memberid = pmemberid;
END //
delimiter ;


#3 -  Which room hold least amount of classes?

select roomid, count(classname) as 'ClassCount' from classtype
	group by roomid
    order by count(classname) asc
    limit 1;
    
#1 - How many members does Denver Fitness Club have

select count(memberid) as 'MemberCount'
from member;


#2 - How many times has each employee requested off work?

select 
   firstname, lastname, employeerequest.employeeid, count(requestid) as 'TimeOff'
from employeerequest
inner join employee on employeerequest.employeeid = employee.employeeid
group by firstname;


#3 - which member attends the most classes - maybe do loyalty

select concat(firstname,lastname) as 'MemberName', sum(c.attendance) as 'attendance' from member m
join class_attendance c on c.memberid = m.memberid
join class_calender cc on cc.classid = c.classid
group by 'MemberName'
order by 'attendance' desc
limit 1;

