package;

import xing.Xing;
import xing.route.Router;

class Main {
    public static function main() {
        var x = new Xing();
		var router = new Router();
		router.add("/", (req, res) -> {
			res.setBody("Hello World");
			res.send();
		});
		router.add("/hello/<name:string>", (req, res) -> {
			var context : xing.template.Context = new xing.template.Context();
			context.addString("name", req.params.get("name"));
			try {
				var template = xing.template.Template.fromString("Hello {{
					if(name == 'world') {
						$ 'cruel ' + name $
					} else {
						$ name $
					}
				}}.", context);
				res.setBody(template);
				res.send();
			} catch(e:haxe.Exception) {
				res.setStatus(500);
				var j = {
					message: e.toString(),
				};
				res.setBody(haxe.Json.stringify(j));
				res.send();
				return;
			}
		});

		x.registerRoute("/", router);

		x.listen("0.0.0.0", [8000], function() {
			Sys.println('Listening on http://0.0.0.0:8000');
		});
    }
}