<?php
/**
 * ZEV Admin — Logout
 */

define('ZEV_ROOT', dirname(__DIR__));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Auth\AdminAuth;

AdminAuth::logout();
header('Location: /admin/login.php');
exit;
