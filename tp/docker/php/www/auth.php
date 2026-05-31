<?php
    if (isset($_POST['US_login']) and isset($_POST['US_password'])) {
        session_start();
        include 'connect.php';

        $hashed = hash('sha256', $_POST['US_password']);

        $sql = "SELECT * FROM utilisateurs WHERE US_login = ? AND US_password = ?";
        $stmt = $db->prepare($sql);
        $stmt->bindParam(1, $_POST['US_login']);
        $stmt->bindParam(2, $hashed);
        $stmt->execute();
        $res = $stmt->fetchAll(PDO::FETCH_ASSOC);
        if ($res != false) {

            if ( count($res) > 0) {
                $utilisateur = $res[0];
                $_SESSION['login'] = $utilisateur['US_login'];
                header("Location: home.php");
            } else {
                header("Location: index.php");
            }
        } else {
            header("Location: BADUSER.html");
        }
    }

