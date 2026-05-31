-- PostgreSQL schema + data for gestion_produits (dev version)
-- Colonnes en minuscules (sans quotes) -> compatible avec les requêtes PHP
-- non-quotées. La compat de casse côté résultats est gérée par CompatStatement
-- dans connect.php.

BEGIN;

DROP TABLE IF EXISTS ressources CASCADE;
DROP TABLE IF EXISTS produits CASCADE;
DROP TABLE IF EXISTS utilisateurs CASCADE;

CREATE TABLE produits (
  pro_id          SERIAL PRIMARY KEY,
  pro_lib         VARCHAR(200) NOT NULL,
  pro_prix        DECIMAL(10,2) NOT NULL,
  pro_description TEXT
);

CREATE TABLE ressources (
  re_id   SERIAL PRIMARY KEY,
  re_type VARCHAR(100) NOT NULL,
  re_url  VARCHAR(1000) NOT NULL,
  re_nom  VARCHAR(100),
  pro_id  INT NOT NULL REFERENCES produits(pro_id) ON DELETE CASCADE
);

CREATE TABLE utilisateurs (
  us_id       SERIAL PRIMARY KEY,
  us_login    VARCHAR(100) NOT NULL UNIQUE,
  us_password VARCHAR(100) NOT NULL
);

INSERT INTO produits (pro_id, pro_lib, pro_prix, pro_description) VALUES
  (1,'Pédales Shimano XT M8040 M/L',74.99,'Pédales plates SHIMANO XT PD-M8040 destinées à un usage All Mountain/Enduro.'),
  (2,'Selle FIZIK ARIONE VERSUS Rails Kium',59.99,'Selle FIZIK Arione Versus, profil long et plat, canal central évidé.'),
  (3,'Chaussures VTT MAVIC CROSSMAX SL PRO THERMO Noir',164.99,'Chaussures Cross Max SL Pro Thermo MAVIC, étanchéité Gore-Tex.'),
  (4,'Pack GPS GARMIN EDGE 1030 + Ceinture Cardio',519.99,'GPS Garmin Edge 1030 avec ceinture cardio SS3 textile.'),
  (5,'Fourche DVO SAPPHIRE 29',549.99,'Fourche DVO Sapphire 29" Trail/All Mountain, débattement 140 mm.');
SELECT setval(pg_get_serial_sequence('produits','pro_id'), (SELECT MAX(pro_id) FROM produits));

INSERT INTO ressources (re_id, re_type, re_url, re_nom, pro_id) VALUES
  (43,'img','uploads/5-19b235d023eef2281304433f0d4438b6.jpg',NULL,5),
  (44,'img','uploads/5-b02cbdbc96d5c9a20526763576f56a11.jpg',NULL,5),
  (45,'img','uploads/5-8e258524bf0f2aae28647a1aa8a77a8c.jpg',NULL,5),
  (46,'img','uploads/4-a21d716bdfda2004d50171559c4b1b92.jpg',NULL,4),
  (47,'img','uploads/4-1cb57a6c1de5c2573679654054a2b3b0.jpg',NULL,4),
  (48,'img','uploads/4-438b7f4eec56d20aca694793882909ac.jpg',NULL,4),
  (49,'img','uploads/1-707116622e5d4fe50dfc6391af4a5421.jpg',NULL,1),
  (50,'img','uploads/1-7f8aacccd9c522281c58e5eb90cbb6a8.jpg',NULL,1),
  (51,'img','uploads/1-987e17d65fb62e5fece343304d7be827.jpg',NULL,1),
  (53,'img','uploads/2-5dfd065b9d05455732d122cdc3b64e27.jpg',NULL,2),
  (54,'img','uploads/2-7e38160b643cf0e21ff445c9594e77d7.jpg',NULL,2),
  (55,'img','uploads/2-2228cc7d3b9f647bfa31dd4ebf0f3885.jpg',NULL,2),
  (60,'img','uploads/3-c518a7a917d0c35dd1d46331b62f6df8.jpg',NULL,3),
  (61,'img','uploads/3-f6f0e00161c27468b39bda23969b19a5.jpg',NULL,3),
  (62,'img','uploads/3-2b2b730177e21ac71bcb8cda0359c34a.jpg',NULL,3);
SELECT setval(pg_get_serial_sequence('ressources','re_id'), (SELECT MAX(re_id) FROM ressources));

INSERT INTO utilisateurs (us_id, us_login, us_password) VALUES
  (1,'admin','5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8');
SELECT setval(pg_get_serial_sequence('utilisateurs','us_id'), (SELECT MAX(us_id) FROM utilisateurs));

COMMIT;
