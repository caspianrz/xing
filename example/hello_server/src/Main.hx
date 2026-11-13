package;

import xing.Xing;

class Main {
    public static function main() {
        var x = new Xing();
		x.registerRoute("/", function(req, res) {
			res.setBody("Hello World");
			res.send();
		});
		x.listen("0.0.0.0", [8000]);
    }
}