CREATE USER '{{user}}'@'localhost' IDENTIFIED BY '{{password}}';
GRANT ALL PRIVILEGES ON *.* TO '{{user}}'@'localhost' WITH GRANT OPTION;

CREATE USER '{{user}}'@'%' IDENTIFIED BY '{{password}}';
GRANT ALL PRIVILEGES ON *.* TO '{{user}}'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;
