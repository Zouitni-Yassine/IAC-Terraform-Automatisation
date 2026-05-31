<?php
$dbtype       = getenv('DB_TYPE')     ?: 'mysql';
$host         = getenv('DB_HOST')     ?: 'db';
$default_port = ($dbtype === 'pgsql') ? '5432' : '3306';
$port         = getenv('DB_PORT')     ?: $default_port;
$username = getenv('DB_USER')     ?: 'root';
$password = getenv('DB_PASSWORD') ?: 'root';
$dbname   = getenv('DB_NAME')     ?: 'gestion_produits';

$dsn = "$dbtype:host=$host;port=$port;dbname=$dbname";

try {
    $db = new PDO($dsn, $username, $password);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    http_response_code(500);
    die("DB connection error: " . $e->getMessage());
}
?>
