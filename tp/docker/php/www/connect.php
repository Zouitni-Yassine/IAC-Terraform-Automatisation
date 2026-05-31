<?php
$dbtype       = getenv('DB_TYPE')     ?: 'mysql';
$host         = getenv('DB_HOST')     ?: 'db';
$default_port = ($dbtype === 'pgsql') ? '5432' : '3306';
$port         = getenv('DB_PORT')     ?: $default_port;
$username     = getenv('DB_USER')     ?: 'root';
$password     = getenv('DB_PASSWORD') ?: 'root';
$dbname       = getenv('DB_NAME')     ?: 'gestion_produits';

$dsn = "$dbtype:host=$host;port=$port;dbname=$dbname";

// PostgreSQL ramène les colonnes en lowercase (US_login -> us_login).
// L'app PHP attend du mixed-case (PRO_id, US_login, RE_url...).
// Cette PDOStatement remappe les clés à la volée — aucune modif côté queries
// ni côté code applicatif n'est nécessaire.
class CompatStatement extends PDOStatement {
    private static $colMap = [
        'us_id' => 'US_id', 'us_login' => 'US_login', 'us_password' => 'US_password',
        'pro_id' => 'PRO_id', 'pro_lib' => 'PRO_lib', 'pro_prix' => 'PRO_prix',
        'pro_description' => 'PRO_description',
        're_id' => 'RE_id', 're_type' => 'RE_type', 're_url' => 'RE_url', 're_nom' => 'RE_nom',
    ];
    protected function __construct() {}
    private function remap(array $row): array {
        $out = [];
        foreach ($row as $k => $v) {
            $out[self::$colMap[$k] ?? $k] = $v;
        }
        return $out;
    }
    public function fetch(int $mode = PDO::FETCH_DEFAULT, int $cursorOrientation = PDO::FETCH_ORI_NEXT, int $cursorOffset = 0): mixed {
        $row = parent::fetch($mode, $cursorOrientation, $cursorOffset);
        return is_array($row) ? $this->remap($row) : $row;
    }
    public function fetchAll(int $mode = PDO::FETCH_DEFAULT, mixed ...$args): array {
        $rows = parent::fetchAll($mode, ...$args);
        return array_map(fn($r) => is_array($r) ? $this->remap($r) : $r, $rows ?: []);
    }
}

try {
    $db = new PDO($dsn, $username, $password);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    if ($dbtype === 'pgsql') {
        $db->setAttribute(PDO::ATTR_STATEMENT_CLASS, [CompatStatement::class]);
    }
} catch (PDOException $e) {
    http_response_code(500);
    die("DB connection error: " . $e->getMessage());
}
?>
