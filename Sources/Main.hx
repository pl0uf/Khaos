package;

import kha.System;

class Main {
	public static function main() {
		System.init({title: "Khaos", width: 1600, height: 900}, function () {
			new Game();
		});
	}
}
