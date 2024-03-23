-- *************************************************** CUSTOMER SUBSCRIPTION MANAGEMENT SYSTEM *******************************************************************

-- =======================================================================================================
-- CREATE THE DATABASE
-- =======================================================================================================
CREATE DATABASE IF NOT EXISTS CL_Management;

-- =======================================================================================================
-- USE THE DATABASE
-- =======================================================================================================
use cl_management;

-- =======================================================================================================
-- DDL STATEMENTS FOR EACH OF THE TABLES
-- =======================================================================================================

--- USER
CREATE TABLE USER (
    user_id VARCHAR(20) PRIMARY KEY,
    user_name VARCHAR(50),
    age INT,
    email_id VARCHAR(50),
    region VARCHAR(20),
    category VARCHAR(20),
    gender VARCHAR(20)
);

-- PRODUCT
CREATE TABLE PRODUCT (
    product_id VARCHAR(64) PRIMARY KEY,
    product_name VARCHAR(30)
);

-- CHANNEL
CREATE TABLE CHANNEL (
    channel_id VARCHAR(30) PRIMARY KEY,
    channel_name VARCHAR(30)
);

-- SUBSCRIPTION
CREATE TABLE SUBSCRIPTION (
    user_id VARCHAR(20) NOT NULL,
    subscription_id VARCHAR(64) PRIMARY KEY,
    product_id VARCHAR(64),
    channel_id VARCHAR(30),
    start_date DATE,
    end_Date DATE,
    FOREIGN KEY (product_id) REFERENCES PRODUCT(product_id),
	FOREIGN KEY (channel_id) REFERENCES CHANNEL(channel_id),
    FOREIGN KEY (user_id) references user(user_id)
);

-- REVENUE 
CREATE TABLE REVENUE (
    revenue_id VARCHAR(64) PRIMARY KEY,
    revenue_type VARCHAR(20),
    gross_arr_in_usd DECIMAL(10, 2),
    subscription_id VARCHAR(64),
    FOREIGN KEY (Subscription_id) REFERENCES SUBSCRIPTION(Subscription_id)
);

-- ENGAGEMENT (Weak Entity)
CREATE TABLE ENGAGEMENT (
	User_id  VARCHAR(20),
    user_type VARCHAR(20),
    engagement_index DECIMAL(10,2),
    FOREIGN KEY (user_id) REFERENCES USER(user_id)
);

-- ACTIVITIES 
CREATE TABLE ACTIVITIES (
    activity_id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(20),
    activity_date Date,
    activity_type varchar(30),
    FOREIGN KEY (User_id) REFERENCES USER(User_id)
);

-- PRODUCT_UPDATES
CREATE TABLE PRODUCT_UPDATES (
    update_id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(20),
    update_name VARCHAR(200),
    FOREIGN KEY (user_id) REFERENCES USER(user_id)
);

-- FEEDBACK
CREATE TABLE FEEDBACK (
    feedback_id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(20),
    feedback_date DATE,
    feedback TEXT,
    FOREIGN KEY (user_id) REFERENCES USER(User_id)
);

-- CAMPAIGN_TOUCH
CREATE TABLE CAMPAIGN_TOUCH (
    campaign_id INT PRIMARY KEY,
    campaign_name VARCHAR(30),
    campaign_Type VARCHAR(30)
);

-- TOUCHED_BY
CREATE TABLE TOUCHED_BY (
    user_id VARCHAR(20),
    campaign_id INT,
    touch_date DATE,
    FOREIGN KEY (user_id) REFERENCES USER(user_id),
    FOREIGN KEY (campaign_id) REFERENCES CAMPAIGN_TOUCH(campaign_id)
);

-- PREFERENCES
CREATE TABLE PREFERENCES (
    preference_id VARCHAR(64) PRIMARY KEY,
    preference_name TEXT
);

-- PREFERS
CREATE TABLE PREFERS (
    user_id VARCHAR(20),
    preference_id VARCHAR(64),
    FOREIGN KEY (user_id) REFERENCES USER(user_id),
    FOREIGN KEY (preference_id) REFERENCES PREFERENCES(preference_id)
);

-- =======================================================================================================
-- FUNCTIONS
-- =======================================================================================================

-- FUNCTION TO GET THE REVENUE GENERATED BY A USER

DELIMITER $$
CREATE FUNCTION get_user_revenue(user_id VARCHAR(20))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE revenue DECIMAL(10,2) DEFAULT 0;
  SELECT SUM(r.Gross_arr_in_usd) INTO @revenue
  FROM USER u JOIN SUBSCRIPTION s ON u.User_id = s.User_id
  JOIN REVENUE r ON s.Subscription_id = r.Subscription_id
  WHERE u.user_id = user_id;
  RETURN @revenue;
END$$
DELIMITER ;

-- FUNCTION TO GET THE REVENEUE GENERATED BY A PRODUCT

DELIMITER $$
CREATE FUNCTION product_revenue(
  prod_name VARCHAR(64)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE product_revenue DECIMAL(10,2);
  SELECT SUM(gross_arr_in_usd)
  INTO product_revenue
  FROM revenue JOIN subscription USING (subscription_id)
  JOIN product using(product_id) WHERE product_name = prod_name;
  RETURN product_revenue;
END$$
DELIMITER ;

-- FUNCTION TO GET THE ENGAGEMENT OF A USER

DELIMITER $$
CREATE FUNCTION user_engagement()
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE unengaged_users INT DEFAULT 0;
  SELECT COUNT(DISTINCT user_id) INTO @unengaged_users
  FROM ENGAGEMENT WHERE engagement_index < 0.5;
  SET unengaged_users = @unengaged_users;
  RETURN unengaged_users;
END$$
DELIMITER ;

-- FUNCTION TO GET THE MOST POPULAR PRODUCT

DELIMITER $$
CREATE FUNCTION get_most_popular_product()
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
DECLARE most_popular_product VARCHAR(20) DEFAULT "";
	SELECT b.product_name INTO most_popular_product FROM subscription a 
	inner join product b on a.product_id = b.product_id
	GROUP BY b.product_name ORDER BY COUNT(DISTINCT a.user_id) DESC
		LIMIT 1;
RETURN most_popular_product;
END $$
DELIMITER ;

-- ===================================================================================================================================
-- STORED PROCEDURES
-- ===================================================================================================================================

-- STORED PROCEDURE GET THE DATE ON WHICH THE PRODUCT USAGE WAS MAXIMUM

DELIMITER $$
CREATE PROCEDURE get_peak_usage_date()
BEGIN
SELECT activity_date FROM activities 
		GROUP BY activity_date ORDER BY COUNT(DISTINCT user_id) DESC
		LIMIT 1;
END $$
DELIMITER ;

-- STORED PROCEDURE TO GET THOSE USERS WHO WERE NOT SENT AN EMAIL

DELIMITER $$
create procedure get_untouched_users()
BEGIN
  SELECT
    u.user_id, u.user_name
  FROM USER u LEFT JOIN TOUCHED_BY t ON u.user_id = t.user_id
  WHERE t.Campaign_id IS NULL;
END$$
DELIMITER ;

-- STORED PROCEDURE TO REMIND USERS ABOUT THEIR EXPIRY OF THE SUBSCRIPTION

DELIMITER $$
CREATE PROCEDURE job_expiration_reminder()
BEGIN
DECLARE rows_updated INT DEFAULT 0;
DECLARE finished INT DEFAULT 0;
DECLARE user_to_send VARCHAR(20) DEFAULT "";
DECLARE cur CURSOR FOR 
	SELECT user_id FROM subscription 
		WHERE end_date = DATE_ADD(CURRENT_DATE(), INTERVAL -1 DAY);
DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
OPEN cur;
SET finished = 0;
REPEAT
	FETCH cur into user_to_send;
		INSERT INTO touched_by VALUES (user_to_send, 10, CURRENT_DATE()); -- LETS SAY CAMPAIGN 10 WAS FOR EXPIRATION REMINDER
        SET rows_updated = rows_updated + 1;
UNTIL finished END REPEAT;
CLOSE cur;
END $$
DELIMITER ;

-- ==================================================================================================================================
-- TRIGGERS
-- ==================================================================================================================================

-- TRIGGER TO SEND A WELCOME EMAIL TO A NEWLY JOINED USER

CREATE TRIGGER send_welcome_email
AFTER INSERT ON user
FOR EACH ROW INSERT INTO touched_by VALUES (NEW.user_id, 4, current_time());

-- ==================================================================================================================================
-- VIEWS
-- ==================================================================================================================================

-- VIEW TO HAVE ONLY THE USERS WITH LOW ENGAGEMENT

CREATE VIEW low_engaged_users AS
SELECT e.user_id, e.user_type, e.engagement_index, a.activity_id, a.activity_date, a.activity_type
FROM ENGAGEMENT e
JOIN ACTIVITIES a ON e.user_id = a.user_id
WHERE e.engagement_index <= 0.25;

-- VIEW TO GET THE REVENUE GENERATED BY MARKETING CHANNELS

CREATE VIEW channel_revenue_summary AS
SELECT
    c.Channel_id, c.Channel_name, SUM(r.Gross_arr_in_usd) AS total_channel_revenue
FROM CHANNEL c
JOIN SUBSCRIPTION s ON c.Channel_id = s.Channel_id
JOIN REVENUE r ON s.Subscription_id = r.Subscription_id
GROUP BY c.Channel_id, c.Channel_name;

-- ***************************************************************** THE END **************************************************************************************





