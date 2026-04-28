DROP TABLE IF EXISTS `elt_test`;

CREATE TABLE `elt_test` (
    `ID`    INT,
    `IDX`   INT,
    `S1`    VARCHAR(50),
    `S2`    VARCHAR(50),
    `S3`    VARCHAR(50),
    PRIMARY KEY (`ID`)
);

INSERT INTO `elt_test` VALUES
    (1, 1,    'red',    'green',  'blue'),
    (2, 2,    'red',    'green',  'blue'),
    (3, 3,    'red',    'green',  'blue'),
    (4, 0,    'red',    'green',  'blue'),
    (5, 4,    'red',    'green',  'blue'),
    (6, NULL, 'red',    'green',  'blue');
