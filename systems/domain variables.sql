

-- Set a variable name for a given domain (call it whatever you want) and set a string value in one of the following ways.
ALTER DATABASE postgres SET domain_name.variable_name = 'variable_value'; -- permenant
SET SESSION domain_name.variable_name = 'variable_value'; -- session temporary

-- then retrieve that variable string value, and optionally cast it as needed
select current_setting('domain_name.variable_name');
select current_setting('domain_name.variable_name')::INT;