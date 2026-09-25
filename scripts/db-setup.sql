CREATE DATABASE lab2174;
USE lab2174;

CREATE TABLE usuarios (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50),
    email VARCHAR(100)
);

INSERT INTO usuarios(nombre,email)
VALUES
('Leonardo','leo@lab2174.local'),
('Usuario1','usuario1@lab2174.local'),
('Usuario2','usuario2@lab2174.local');

CREATE USER 'labweb'@'10.21.74.130' IDENTIFIED BY 'Lab2174-DB!';
GRANT SELECT ON lab2174.* TO 'labweb'@'10.21.74.130';
FLUSH PRIVILEGES;
