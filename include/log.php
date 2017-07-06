<?php 
 session_start();

  if(!isset($_SESSION['admin_id']))
    exit -1;

  require(dirname(__FILE__) . '/connect.php');
  require(dirname(__FILE__) . '/functions.php');
  
  if(isset($_GET['select'])){
     else if($_GET['select'] == "log" && isset($_GET['offset'], $_GET['limit'])){
      $offset = intval($_GET['offset']);
      $limit = intval($_GET['limit']);

      // Creation of the LIMIT for build different pages
      $page = "LIMIT $offset, $limit";

      // Select the logs
      $req_string = "SELECT *, (SELECT COUNT(*) FROM log) AS nb FROM log ORDER BY log_id DESC $page";
      $req = $bdd->prepare($req_string);
      $req->execute();

      $list = array();

      $data = $req->fetch();

      if($data) {
        $nb = $data['nb'];

        do {
          // Better in Kb or Mb
          $received = ($data['log_received'] > 100000) ? $data['log_received']/100000 . " MB" : $data['log_received']/100 . " KB";
          $sent = ($data['log_send'] > 100000) ? $data['log_send']/100000 . " MB" : $data['log_send']/100 . " KB";

          // We add to the array the new line of logs
          array_push($list, array(
                                  "log_id" => $data['log_id'],
                                  "user_id" => $data['user_id'],
                                  "log_trusted_ip" => $data['log_trusted_ip'],
                                  "log_trusted_port" => $data['log_trusted_port'],
                                  "log_remote_ip" => $data['log_remote_ip'],
                                  "log_remote_port" => $data['log_remote_port'],
                                  "log_start_time" => $data['log_start_time'],
                                  "log_end_time" => $data['log_end_time'],
                                  "log_received" => $received,
                                  "log_send" => $sent));


        } while ($data = $req->fetch());
      }
      else {
        $nb = 0;
      }
	  
	  ?>