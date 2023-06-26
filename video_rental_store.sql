--Selection of customers whom have paid late-fees, with the duration of their rental, amount paid, and a count of how many times the customer was late
SELECT DISTINCT CONCAT(first_name, ' ', last_name) AS full_name, title, LEFT(description, 50 - POSITION(' ' IN REVERSE(LEFT(description, 50)))) AS description,
rental.rental_date::date, (rental.rental_date::date+rental_duration) AS exp_return_date, rental.return_date::date AS return_date_actual, rental_duration, (rental.return_date - rental.rental_date)::INTERVAL AS rent_duration_actual, rental_rate, amount, 
COUNT(customer.customer_id) OVER(PARTITION BY CONCAT(first_name, ' ', last_name)) AS number_of_late_returns
FROM customer
LEFT JOIN rental
ON customer.customer_id = rental.customer_id
LEFT JOIN inventory
ON rental.inventory_id = inventory.inventory_id
LEFT JOIN film
ON film.film_id = inventory.film_id
LEFT JOIN payment
ON payment.rental_id = rental.rental_id
WHERE amount > rental_rate
GROUP BY 1,2,3,4,5,6,7,8,9,10, customer.customer_id
ORDER BY full_name ASC;

-- Customers, the films they rented, how many times they rented a film, and the total amount paid per customer
SELECT title, COUNT(rental.rental_id) AS times_rented, CONCAT(first_name, ' ', last_name) AS full_name,
SUM(amount) AS sum_of_amount
FROM film
LEFT JOIN inventory
ON film.film_id = inventory.film_id
LEFT JOIN rental
ON inventory.inventory_id = rental.inventory_id
LEFT JOIN payment
ON payment.rental_id = rental.rental_id
LEFT JOIN customer
ON customer.customer_id = rental.customer_id
GROUP BY 1, first_name, last_name
HAVING COUNT(rental.rental_id) != 0 AND SUM(amount) IS NOT NULL
ORDER BY times_rented DESC;

--List of customers whom never returned rented films, along with the total cost to the customer to replace the rental in addition to the rental fee
WITH A AS (
SELECT DISTINCT customer.customer_id, CONCAT(first_name, ' ', last_name) AS full_name
FROM customer)

SELECT A.full_name, (replacement_cost + amount) AS total_amount
FROM A
LEFT JOIN rental
ON A.customer_id = rental.customer_id
LEFT JOIN payment
ON payment.rental_id = rental.rental_id
LEFT JOIN inventory
ON inventory.inventory_id = rental.inventory_id
LEFT JOIN film
ON film.film_id = inventory.film_id
WHERE rental.return_date IS NULL
GROUP BY 1,2
ORDER BY total_amount DESC;

--Summed count of rentals between the weekday and weekend
WITH A AS
(SELECT rental_id, EXTRACT(isodow FROM rental_date) AS iso_dow
FROM rental),
B AS
(SELECT rental.rental_id, CASE WHEN iso_dow BETWEEN 1 AND 5 THEN 'Weekday' ELSE 'Weekend' END AS dow_status
FROM A
LEFT JOIN rental
ON A.rental_id=rental.rental_id)
SELECT dow_status, SUM(CASE WHEN iso_dow BETWEEN 1 AND 5 THEN 1
					  WHEN iso_dow BETWEEN 6 AND 7 THEN 1 END) dow_count
FROM B
LEFT JOIN A
ON B.rental_id = A.rental_id
GROUP BY dow_status;

--Most rented movies per category
SELECT category.name, CASE WHEN SUM((SELECT COUNT(rental_id) FROM rental)) = MAX((SELECT COUNT(rental_id) FROM rental)) THEN title END AS most_rented
FROM category
LEFT JOIN film_category
ON category.category_id = film_category.category_id
LEFT JOIN film
ON film.film_id = film_category.film_id
LEFT JOIN inventory
ON inventory.film_id = film.film_id
LEFT JOIN rental
ON rental.inventory_id=inventory.inventory_id
GROUP BY category.name, title
HAVING CASE WHEN SUM((SELECT COUNT(rental_id) FROM rental)) = MAX((SELECT COUNT(rental_id) FROM rental)) THEN title END IS NOT NULL
ORDER BY category.name ASC;

--Percentage of rentals per country
WITH A AS
(SELECT country_id, country, COUNT(country) AS country_ct
FROM country
GROUP BY 1,2)
SELECT country, ROUND((SUM(country_ct)/(SELECT COUNT(*) FROM rental)*100.0),2) AS country_perc
FROM A
LEFT JOIN city
ON A.country_id=city.country_id
INNER JOIN address
ON city.city_id=address.city_id
INNER JOIN customer
ON address.address_id=customer.address_id
INNER JOIN rental
ON customer.customer_id=rental.customer_id
GROUP BY 1, country_ct
ORDER BY country_perc DESC;
-- Upper First Quartile of films rented 
WITH A AS
(SELECT inventory.film_id, title, COUNT(rental_id) AS rented, DENSE_RANK() OVER(ORDER BY COUNT(rental_id) DESC) AS rank
FROM film
LEFT JOIN inventory
ON film.film_id=inventory.film_id
LEFT JOIN rental
ON inventory.inventory_id=rental.inventory_id
GROUP BY title, inventory.film_id
ORDER BY rented DESC),
B AS
(SELECT film_id, title, rented, A.rank, NTILE(3) OVER(ORDER BY rented DESC) AS quart_3
FROM A
ORDER BY rented DESC)
SELECT B.title, A.rented, A.rank
FROM A
LEFT JOIN B
ON A.film_id = B.film_id
WHERE quart_3 = 1;
-- Top Ten Categorical Rentals divided between different Stores
WITH A AS
(SELECT store.store_id, category.name AS category_name, COUNT(rental_id) FILTER(WHERE store.store_id = 1) AS rented
FROM rental
LEFT JOIN inventory
ON rental.inventory_id=inventory.inventory_id
LEFT JOIN film_category
ON inventory.film_id=film_category.film_id
LEFT JOIN category 
ON film_category.category_id=category.category_id
LEFT JOIN store
ON inventory.store_id=store.store_id
WHERE store.store_id != 2
GROUP BY 1,2
ORDER BY rented DESC),
B AS
(SELECT store.store_id, category.name AS category_name, COUNT(rental_id) FILTER(WHERE store.store_id = 2) AS rented
FROM rental
LEFT JOIN inventory
ON rental.inventory_id=inventory.inventory_id
LEFT JOIN film_category
ON inventory.film_id=film_category.film_id
LEFT JOIN category 
ON film_category.category_id=category.category_id
LEFT JOIN store
ON inventory.store_id=store.store_id
WHERE store.store_id != 1
GROUP BY 1,2
ORDER BY rented DESC)

SELECT DISTINCT A.store_id, A.category_name, A.rented
FROM A
UNION
SELECT DISTINCT B.store_id, B.category_name, B.rented
FROM B
ORDER BY rented DESC
LIMIT 10
