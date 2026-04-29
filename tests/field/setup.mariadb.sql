DROP TABLE IF EXISTS `field_test`;

CREATE TABLE `field_test` (
    `ID`     INT,
    `NEEDLE` VARCHAR(50),
    `S1`     VARCHAR(50),
    `S2`     VARCHAR(50),
    `S3`     VARCHAR(50),
    PRIMARY KEY (`ID`)
);

INSERT INTO `field_test` VALUES
    (1, 'red',    'red',    'green',  'blue'),
    (2, 'green',  'red',    'green',  'blue'),
    (3, 'blue',   'red',    'green',  'blue'),
    (4, 'gold',   'red',    'green',  'blue'),
    (5, NULL,     'red',    'green',  'blue'),
    (6, 'green',  'red',    NULL,     'blue');
