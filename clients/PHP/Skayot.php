<?php

define('p_CONNECT',     0x01);
define('p_CONNACK',     0x02);
define('p_PUBLISH',     0x03);
define('p_PUBACK',      0x04);
define('p_SUBSCRIBE',   0x05);
define('p_SUBACK',      0x06);
define('p_UNSUBSCRIBE', 0x07);
define('p_UNSUBACK',    0x08);
define('p_DISCONNECT',  0x09);
define('p_SUBMSG',      0x0b);

define('p_PUBLISH_ENDTOPIC', 0x1a);
define('p_PUBLISH_ENDMSG', 0x1b);
define('p_SUBSCRIBE_ENDTOPIC', 0x1c);
define('p_UNSUBSCRIBE_ENDTOPIC', 0x1d);
define('p_SUBMSG_ENDTOPIC', 0x1e);
define('p_SUBMSG_ENDMSG', 0x1f);

define('p_ZERO', 0x00);

class Skayot {
	public $address;
	public $post;

	private $socket;

	function __construct($address, $port, $debug = false) {
		$this->address = $address;
		$this->port = $port;

		$this->socket = stream_socket_client("tcp://$address:$port", $errno, $errstr, 60, STREAM_CLIENT_CONNECT);

		if (!$this->socket) {
			error_log("stream_socket_create() $errno, $errstr \n");
			return false;
		}

		stream_set_timeout($this->socket, 5);
		stream_set_blocking($this->socket, 0);

		register_shutdown_function([$this, 'disconnect']);
		set_error_handler([$this, 'disconnectError']);

		$this->debug = $debug;
	}

	private function read($int = 8192, $nb = false){
		$string = "";
		$togo = $int;
		
		if($nb){
			return fread($this->socket, $togo);
		}
			
		while (!feof($this->socket) && $togo>0) {
			$fread = fread($this->socket, $togo);
			$string .= $fread;
			$togo = $int - strlen($string);
		}
		
		return $string;
	}

	public function connect() {
		$buffer = "";
		$buffer .= chr(p_CONNECT);

		fwrite($this->socket, $buffer);

		if(ord($this->read(1)) == p_CONNACK) {
			if($this->debug) echo 'Connection accepted!' . PHP_EOL;
			return true;
		} else {
			if($this->debug) echo 'Connection refused.' . PHP_EOL;
			return false;
		}
	}

	public function disconnect() {
		$buffer = "";
		$buffer .= chr(p_DISCONNECT);

		fwrite($this->socket, $buffer);
		stream_socket_shutdown($this->socket, STREAM_SHUT_WR);

		if($this->debug) echo 'Disconnected.' . PHP_EOL;
	}

	public function disconnectError($errno, $errstr, $errfile, $errline) {
		echo "$errstr in $errfile on line $errline";
		$this->disconnect();
	}

	public function subscribe($topic) {
		$buffer = "";
		$buffer .= chr(p_SUBSCRIBE);
		$buffer .= $topic;
		$buffer .= chr(p_SUBSCRIBE_ENDTOPIC);

		fwrite($this->socket, $buffer);

		if(ord($this->read(1)) == p_SUBACK) {
			if($this->debug) echo 'Subscribe successful!' . PHP_EOL;
			return true;
		} else {
			if($this->debug) echo 'Subscribe failed.' . PHP_EOL;
			return false;
		}
	}

	public function publish($topic, $msg) {
		$buffer = "";
		$buffer .= chr(p_PUBLISH);
		$buffer .= $topic;
		$buffer .= chr(p_PUBLISH_ENDTOPIC);
		$buffer .= $msg;
		$buffer .= chr(p_PUBLISH_ENDMSG);

		fwrite($this->socket, $buffer);

		if(ord($this->read(1)) == p_PUBACK) {
			if($this->debug) echo 'Publish successful!' . PHP_EOL;
			return true;
		} else {
			if($this->debug) echo 'Publish failed.' . PHP_EOL;
			return false;
		}
	}

	public function unsubscribe($topic) {
		$buffer = "";
		$buffer .= chr(p_UNSUBSCRIBE);
		$buffer .= $topic;
		$buffer .= chr(p_UNSUBSCRIBE_ENDTOPIC);

		fwrite($this->socket, $buffer);

		if(ord($this->read(1)) == p_UNSUBACK) {
			if($this->debug) echo 'Unsubscribe successful!' . PHP_EOL;
			return true;
		} else {
			if($this->debug) echo 'Unsubscribe failed.' . PHP_EOL;
			return false;
		}
	}

	public function checkForMessage() {
		$rawMessage = $this->read(8192, true);

		$message = "";
		$topic = "";
		$topicEnd = false;
		for($i = 0; $i < strlen($rawMessage); $i++) {
			if(ord($rawMessage[$i]) == p_SUBMSG_ENDTOPIC) {
				$topicEnd = true;
				continue;
			}

			if(ord($rawMessage[$i]) == p_SUBMSG_ENDMSG)
				break;

			if(ord($rawMessage[$i]) == p_SUBMSG)
				continue;

			if(!$topicEnd) {
				$topic .= $rawMessage[$i];
			} else {
				$message .= $rawMessage[$i];
			}
		}

		if($topic && $message) 
			return ['msg' => $message, 'topic' => $topic];

		return false;
	}
}

// DEMO - Uncomment to test it

$address = '192.168.1.110';
$port = 2470;

$skayot = new Skayot($address, $port, true);
$skayot->connect();
while(true) {
	$input = readline('Send: ');
	[$lightNum, $action] = explode(" ", $input);

	$topic = 'light/' . $lightNum;

	$skayot->publish($topic, $action);
}

